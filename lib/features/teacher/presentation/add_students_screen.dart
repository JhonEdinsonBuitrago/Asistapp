import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/name_utils.dart';
import '../data/course_repository.dart';
import '../data/enrollment_repository.dart';
import '../data/teacher_course_detail_data.dart';

const _teal = Color(0xFF066A5C);
const _mint = Color(0xFFD7F5EA);
const _mintStrong = Color(0xFF9DEBD9);
const _blueBg = Color(0xFFE3EBFA);
const _soft = Color(0xFFEFF3FC);
const _navyBtn = Color(0xFF0A2F52);
const _greenBtn = Color(0xFF0B6B54);
const _red = Color(0xFFD92D20);
const _amberFg = Color(0xFFB45309);
const _amberBg = Color(0xFFFFE8CC);

const _shadow = [
  BoxShadow(color: Color(0x120B3A5E), blurRadius: 16, offset: Offset(0, 6)),
];

enum _Filter { all, available, enrolled }

enum _CardState { available, selected, enrolled }

class _CourseInfo {
  const _CourseInfo({
    required this.name,
    required this.code,
    required this.isSample,
    required this.isActive,
    required this.sampleCount,
    this.section,
  });

  final String name;
  final String code;
  final String? section;
  final bool isSample;
  final bool isActive;
  final int sampleCount;
}

class _BulkResult {
  const _BulkResult(this.found, this.notFound, this.alreadyIn);

  final List<DirectoryStudent> found;
  final List<String> notFound;
  final int alreadyIn;
}

class AddStudentsScreen extends ConsumerStatefulWidget {
  const AddStudentsScreen({super.key, required this.courseId});

  final String courseId;

  @override
  ConsumerState<AddStudentsScreen> createState() => _AddStudentsScreenState();
}

class _AddStudentsScreenState extends ConsumerState<AddStudentsScreen> {
  static const _maxShown = 30;

  final _search = TextEditingController();
  final _bulk = TextEditingController();
  String _q = '';
  int _tab = 0; // 0 manual, 1 Excel / CSV
  _Filter _filter = _Filter.all;

  List<DirectoryStudent>? _directory;
  bool _loadingDir = true;
  String? _dirError;

  final Map<String, DirectoryStudent> _selected = {};
  bool _saving = false;
  _BulkResult? _bulkResult;

  @override
  void initState() {
    super.initState();
    _fetchDirectory();
  }

  @override
  void dispose() {
    _search.dispose();
    _bulk.dispose();
    super.dispose();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/teacher/course/${widget.courseId}');
    }
  }

  // ------------------------------ Datos ------------------------------

  Future<void> _fetchDirectory() async {
    try {
      final list = await ref.read(enrollmentRepositoryProvider).loadDirectory();
      if (!mounted) return;
      setState(() {
        _directory = list;
        _loadingDir = false;
        _dirError = null;
      });
    } on TimeoutException {
      _directoryFailed('Sin conexión. Revisa tu internet e intenta de nuevo.');
    } on FirebaseException catch (e) {
      _directoryFailed(
        e.code == 'permission-denied'
            ? 'Sin permiso para ver los estudiantes. Usa una cuenta de docente y publica las reglas de Firestore.'
            : 'No se pudo cargar el directorio (${e.code}).',
      );
    } catch (_) {
      _directoryFailed('No se pudo cargar el directorio.');
    }
  }

  void _directoryFailed(String message) {
    if (!mounted) return;
    setState(() {
      _loadingDir = false;
      _dirError = message;
    });
  }

  _CourseInfo? _resolveCourse() {
    final sample = sampleCourseDetail(widget.courseId, DateTime.now());
    if (sample != null) {
      return _CourseInfo(
        name: sample.name,
        code: sample.code,
        section: sample.section,
        isSample: true,
        isActive: true,
        sampleCount: sample.students.length,
      );
    }
    final real = ref
        .watch(myCoursesProvider)
        .value
        ?.where((c) => c.id == widget.courseId)
        .firstOrNull;
    if (real == null) return null;
    return _CourseInfo(
      name: real.name,
      code: real.code,
      isSample: false,
      isActive: !real.isDraft,
      sampleCount: 0,
    );
  }

  List<DirectoryStudent> _results(Set<String> enrolledIds) {
    Iterable<DirectoryStudent> it = _directory ?? const <DirectoryStudent>[];

    if (_filter == _Filter.available) {
      it = it.where((s) => !enrolledIds.contains(s.id));
    } else if (_filter == _Filter.enrolled) {
      it = it.where((s) => enrolledIds.contains(s.id));
    }
    if (_q.isNotEmpty) {
      final terms = _q.split(' ').where((t) => t.isNotEmpty).toList();
      it = it.where((s) => terms.every(s.searchKey.contains));
    }
    return it.toList();
  }

  // ------------------------------ Selección ------------------------------

  void _toggle(DirectoryStudent s) {
    setState(() {
      if (_selected.containsKey(s.id)) {
        _selected.remove(s.id);
      } else {
        _selected[s.id] = s;
      }
    });
  }

  void _runBulk(Set<String> enrolledIds) {
    final dir = _directory;
    if (dir == null) {
      _snack('El directorio todavía no se ha cargado.');
      return;
    }

    final byCode = {
      for (final s in dir)
        if (s.code.isNotEmpty) normalizeText(s.code): s,
    };
    final byEmail = {
      for (final s in dir)
        if (s.email.isNotEmpty) s.email.trim().toLowerCase(): s,
    };

    const headers = {
      'codigo',
      'correo',
      'email',
      'matricula',
      'nombre',
      'estudiante',
      'codigo estudiantil',
    };

    final tokens = _bulk.text
        .split(RegExp(r'[\n\r,;\t]+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final found = <String, DirectoryStudent>{};
    final notFound = <String>[];
    var already = 0;

    for (final raw in tokens) {
      if (headers.contains(normalizeText(raw))) continue; // fila de encabezado
      final s = byCode[normalizeText(raw)] ?? byEmail[raw.toLowerCase()];
      if (s == null) {
        if (!notFound.contains(raw)) notFound.add(raw);
        continue;
      }
      if (enrolledIds.contains(s.id)) {
        already++;
        continue;
      }
      found[s.id] = s;
    }
    setState(
      () => _bulkResult = _BulkResult(found.values.toList(), notFound, already),
    );
  }

  void _addBulkFound() {
    final r = _bulkResult;
    if (r == null || r.found.isEmpty) return;
    setState(() {
      for (final s in r.found) {
        _selected[s.id] = s;
      }
      _bulkResult = null;
      _bulk.clear();
      _tab = 0;
    });
    _snack(
      '${r.found.length} ${r.found.length == 1 ? 'estudiante agregado' : 'estudiantes agregados'} a la selección',
    );
  }

  // ------------------------------ Guardar ------------------------------

  /// Matricula a los seleccionados. Devuelve false si hubo un error.
  Future<bool> _commit(_CourseInfo info, Set<String> enrolledIds) async {
    if (_selected.isEmpty) return true;

    if (info.isSample) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Curso de ejemplo',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          content: const Text(
            'Este curso es de ejemplo, así que la matrícula solo se simula y no se guarda. '
            'Para matricular de verdad, usa un curso que hayas creado.',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      if (mounted) setState(_selected.clear);
      return true;
    }

    final toSave = _selected.values
        .where((s) => !enrolledIds.contains(s.id))
        .toList();
    if (toSave.isEmpty) {
      setState(_selected.clear);
      return true;
    }

    setState(() => _saving = true);
    try {
      final n = await ref
          .read(enrollmentRepositoryProvider)
          .enroll(
            courseId: widget.courseId,
            courseName: info.name,
            courseCode: info.code,
            students: toSave,
          );
      if (!mounted) return true;
      setState(_selected.clear);
      _snack(
        '$n ${n == 1 ? 'estudiante matriculado' : 'estudiantes matriculados'}',
      );
      return true;
    } on TimeoutException {
      if (mounted)
        _snack('Sin conexión. Revisa tu internet e intenta de nuevo.');
      return false;
    } on FirebaseException catch (e) {
      if (mounted) {
        _snack(
          e.code == 'permission-denied'
              ? 'Sin permiso: el curso debe estar activo y las reglas de Firestore publicadas.'
              : 'No se pudo matricular (${e.code}).',
        );
      }
      return false;
    } catch (_) {
      if (mounted) _snack('No se pudo matricular a los estudiantes.');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAndExit(_CourseInfo info, Set<String> enrolledIds) async {
    final ok = await _commit(info, enrolledIds);
    if (ok && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _back();
      });
    }
  }

  Future<void> _requestBack() async {
    if (_selected.isNotEmpty) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            '¿Salir sin matricular?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          content: Text(
            'Tienes ${_selected.length} ${_selected.length == 1 ? 'estudiante seleccionado' : 'estudiantes seleccionados'} sin matricular.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Seguir aquí'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Salir', style: TextStyle(color: _red)),
            ),
          ],
        ),
      );
      if (leave != true || !mounted) return;
      setState(_selected.clear);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _back();
    });
  }

  // ------------------------------ Interfaz ------------------------------

  @override
  Widget build(BuildContext context) {
    final info = _resolveCourse();
    if (info == null) {
      final loading = ref.watch(myCoursesProvider).isLoading;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Center(
          child: loading
              ? const CircularProgressIndicator()
              : const Text('Curso no encontrado'),
        ),
      );
    }

    final enrolledList = info.isSample
        ? const <EnrolledStudent>[]
        : (ref.watch(enrolledStudentsProvider(widget.courseId)).value ??
              const <EnrolledStudent>[]);
    final enrolledIds = {for (final e in enrolledList) e.id};
    final enrolledCount = info.isSample
        ? info.sampleCount
        : enrolledList.length;

    final user = FirebaseAuth.instance.currentUser;
    final initials = initialsOf(displayNameOf(user?.displayName, user?.email));

    return PopScope(
      canPop: _selected.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  _TopBar(onBack: _requestBack, initials: initials),
                  Expanded(
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                      children: [
                        _CourseHeader(info: info, enrolled: enrolledCount),
                        if (info.isSample)
                          const _Banner(
                            icon: Icons.science_outlined,
                            text: 'Curso de ejemplo: la matrícula se simula y no se guarda. Para matricular de verdad usa un curso que hayas creado.',
                          ),
                        if (!info.isActive)
                          const _Banner(
                            icon: Icons.edit_note,
                            text: 'Este curso es un borrador. Actívalo desde el home para poder matricular estudiantes.',
                          ),
                        const SizedBox(height: 14),
                        _Tabs(
                          index: _tab,
                          onChanged: (i) => setState(() => _tab = i),
                        ),
                        const SizedBox(height: 14),
                        if (_tab == 0)
                          ..._manualTab(enrolledIds)
                        else
                          ..._bulkTab(enrolledIds),
                        const SizedBox(height: 16),
                        _SelectedPanel(
                          selected: _selected.values.toList(),
                          saving: _saving,
                          enabled: info.isActive,
                          onRemove: _toggle,
                          onConfirm: () => _commit(info, enrolledIds),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: (_saving || !info.isActive)
                              ? null
                              : () => _saveAndExit(info, enrolledIds),
                          icon: const Icon(Icons.save_outlined, size: 20),
                          label: const Text('Guardar cambios en el Roster'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _navyBtn,
                            minimumSize: const Size.fromHeight(56),
                            textStyle: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Los estudiantes matriculados quedan registrados en el roster del curso y podrán registrar asistencia con el QR dinámico y el código de la sesión.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------- Pestaña: agregar manualmente -----------------------

  List<Widget> _manualTab(Set<String> enrolledIds) {
    final widgets = <Widget>[
      TextField(
        controller: _search,
        onChanged: (v) => setState(() => _q = normalizeText(v)),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre, código o correo...',
          hintStyle: const TextStyle(color: Color(0xFF8A97A6)),
          prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
          suffixIcon: _q.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 19),
                  onPressed: () {
                    _search.clear();
                    setState(() => _q = '');
                  },
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 17),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE1E8F4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE1E8F4)),
          ),
        ),
      ),
      const SizedBox(height: 12),
    ];

    if (_loadingDir) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
      return widgets;
    }

    if (_dirError != null) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Text(
                _dirError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _red, height: 1.4),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _loadingDir = true;
                    _dirError = null;
                  });
                  _fetchDirectory();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
      return widgets;
    }

    final all = _results(enrolledIds);
    final shown = all.take(_maxShown).toList();

    final summary = _q.isEmpty
        ? '${_directory!.length} ${_directory!.length == 1 ? 'estudiante registrado' : 'estudiantes registrados'} en AsistApp'
        : '${all.length} ${all.length == 1 ? 'resultado' : 'resultados'} en el directorio';

    widgets.add(
      Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: _teal,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              summary,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ),
          PopupMenuButton<_Filter>(
            tooltip: 'Filtrar',
            initialValue: _filter,
            onSelected: (f) => setState(() => _filter = f),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Filter.all, child: Text('Todos')),
              PopupMenuItem(
                value: _Filter.available,
                child: Text('No inscritos'),
              ),
              PopupMenuItem(
                value: _Filter.enrolled,
                child: Text('Ya inscritos'),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _filter == _Filter.all ? _blueBg : _navyBtn,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune,
                    size: 16,
                    color: _filter == _Filter.all
                        ? AppColors.navy
                        : Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Filtrar',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _filter == _Filter.all
                          ? AppColors.navy
                          : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    widgets.add(const SizedBox(height: 12));

    if (_directory!.isEmpty) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 28, horizontal: 12),
          child: Text(
            'Aún no hay estudiantes registrados en la app. Pídeles que creen su cuenta con el rol Estudiante.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, height: 1.4),
          ),
        ),
      );
      return widgets;
    }

    if (shown.isEmpty) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(
            child: Text(
              'Ningún estudiante coincide con tu búsqueda.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ),
      );
      return widgets;
    }

    for (final s in shown) {
      final state = enrolledIds.contains(s.id)
          ? _CardState.enrolled
          : (_selected.containsKey(s.id)
                ? _CardState.selected
                : _CardState.available);
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ResultCard(
            student: s,
            state: state,
            onToggle: () => _toggle(s),
          ),
        ),
      );
    }

    if (all.length > _maxShown) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Center(
            child: Text(
              'Mostrando $_maxShown de ${all.length}. Escribe para afinar la búsqueda.',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  // ----------------------- Pestaña: Excel / CSV -----------------------

  List<Widget> _bulkTab(Set<String> enrolledIds) {
    final r = _bulkResult;

    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(22)),
          boxShadow: _shadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.table_chart_outlined,
                  size: 21,
                  color: AppColors.navy,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Carga masiva por lista',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Copia la columna de códigos estudiantiles o correos desde tu archivo de Excel o CSV y pégala aquí (uno por línea, o separados por comas).',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bulk,
              minLines: 6,
              maxLines: 10,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: '2021-0819\n2022-1402\nsortiz@universidad.edu.pe',
                hintStyle: const TextStyle(color: Color(0xFF8A97A6)),
                filled: true,
                fillColor: AppColors.chipBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadingDir ? null : () => _runBulk(enrolledIds),
              icon: const Icon(Icons.manage_search),
              label: const Text('Buscar en el directorio'),
              style: FilledButton.styleFrom(
                backgroundColor: _navyBtn,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            if (r != null) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CountChip('Encontrados: ${r.found.length}', _teal, _mint),
                  _CountChip(
                    'No encontrados: ${r.notFound.length}',
                    _red,
                    const Color(0xFFFEE2E2),
                  ),
                  _CountChip(
                    'Ya inscritos: ${r.alreadyIn}',
                    AppColors.navy,
                    _blueBg,
                  ),
                ],
              ),
              if (r.notFound.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'No se encontraron: ${r.notFound.take(10).join(', ')}${r.notFound.length > 10 ? '…' : ''}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: _red,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Revisa que el código o el correo coincidan con el de la cuenta del estudiante, y que ya se haya registrado en la app.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              if (r.found.isNotEmpty) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _addBulkFound,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(
                    'Agregar ${r.found.length} ${r.found.length == 1 ? 'encontrado' : 'encontrados'} a la selección',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _greenBtn,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Piezas
// ---------------------------------------------------------------------------
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.initials});

  final VoidCallback onBack;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onBack,
                icon: const Icon(
                  Icons.arrow_back,
                  size: 20,
                  color: AppColors.navy,
                ),
                label: const Text(
                  'Volver',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Añadir Estudiantes',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Align(
              alignment: Alignment.centerRight,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.navy,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseHeader extends StatelessWidget {
  const _CourseHeader({required this.info, required this.enrolled});

  final _CourseInfo info;
  final int enrolled;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (info.code.isNotEmpty) info.code,
      if (info.section != null) 'Sección ${info.section}',
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: _blueBg,
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: _navyBtn,
              borderRadius: BorderRadius.all(Radius.circular(15)),
            ),
            child: const Icon(Icons.school, size: 26, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.isActive ? 'CURSO ACTIVO' : 'BORRADOR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: info.isActive ? AppColors.navy : _amberFg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  info.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                    height: 1.15,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFD3E2F7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.groups_outlined,
                  size: 16,
                  color: AppColors.navy,
                ),
                const SizedBox(width: 5),
                Text(
                  '$enrolled ${enrolled == 1 ? 'inscrito' : 'inscritos'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _amberBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: _amberFg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Color(0xFF7A4A12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(int i, IconData icon, String label) {
      final selected = index == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(i),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x1A0B3A5E),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? AppColors.navy : AppColors.textMuted,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.navy : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: const BoxDecoration(
        color: _blueBg,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Row(
        children: [
          tab(0, Icons.person_add_alt, 'Agregar manualmente'),
          tab(1, Icons.table_chart_outlined, 'Cargar Excel / CSV'),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.student,
    required this.state,
    required this.onToggle,
  });

  final DirectoryStudent student;
  final _CardState state;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final s = student;
    final mintAvatar = s.id.codeUnits.fold<int>(0, (a, b) => a + b).isEven;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(22)),
        boxShadow: _shadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: mintAvatar ? _mintStrong : _blueBg,
                child: Text(
                  s.initials,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: mintAvatar
                        ? const Color(0xFF065F52)
                        : AppColors.navy,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.code.isEmpty
                          ? 'Sin código estudiantil'
                          : 'Cód: ${s.code}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _action(),
            ],
          ),
          if (s.email.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.mail_outline,
                    size: 17,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3D4B5C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _action() {
    switch (state) {
      case _CardState.available:
        return FilledButton.icon(
          onPressed: onToggle,
          icon: const Icon(Icons.person_add_alt_1, size: 18),
          label: const Text('Agregar'),
          style: FilledButton.styleFrom(
            backgroundColor: _navyBtn,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      case _CardState.selected:
        return FilledButton.icon(
          onPressed: onToggle,
          icon: const Icon(Icons.check_circle, size: 18),
          label: const Text('Agregada'),
          style: FilledButton.styleFrom(
            backgroundColor: _mintStrong,
            foregroundColor: const Color(0xFF065F52),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      case _CardState.enrolled:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _blueBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.how_to_reg_outlined, size: 18, color: AppColors.navy),
              SizedBox(width: 6),
              Text(
                'Inscrito',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _SelectedPanel extends StatelessWidget {
  const _SelectedPanel({
    required this.selected,
    required this.saving,
    required this.enabled,
    required this.onRemove,
    required this.onConfirm,
  });

  final List<DirectoryStudent> selected;
  final bool saving;
  final bool enabled;
  final ValueChanged<DirectoryStudent> onRemove;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final n = selected.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: _blueBg,
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.how_to_reg_outlined,
                size: 20,
                color: AppColors.navy,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Seleccionados para esta sesión',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _teal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$n ${n == 1 ? 'alumno' : 'alumnos'}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (n == 0)
            const Text(
              'Aún no has seleccionado estudiantes. Toca "Agregar" en los resultados.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in selected)
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFD3DDF0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          s.shortName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => onRemove(s),
                          child: const Padding(
                            padding: EdgeInsets.all(3),
                            child: Icon(
                              Icons.cancel_outlined,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: (n == 0 || saving || !enabled) ? null : onConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: _greenBtn,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user_outlined, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Confirmar y matricular en sección',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip(this.label, this.fg, this.bg);

  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}
