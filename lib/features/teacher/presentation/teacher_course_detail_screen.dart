import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/enrollment_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/name_utils.dart';
import '../data/course_repository.dart';
import '../data/teacher_course_detail_data.dart';

const _teal = Color(0xFF066A5C);
const _mint = Color(0xFFD7F5EA);
const _mintStrong = Color(0xFF9DEBD9);
const _blueBg = Color(0xFFE3EBFA);
const _soft = Color(0xFFEFF3FC);
const _navyBtn = Color(0xFF0A2F52);
const _red = Color(0xFFD92D20);
const _redBg = Color(0xFFFCE8E8);
const _redBorder = Color(0xFFF3C6C6);
const _amber = Color(0xFFF5A623);
const _amberFg = Color(0xFFB45309);
const _amberBg = Color(0xFFFFE8CC);

const _shadow = [
  BoxShadow(color: Color(0x120B3A5E), blurRadius: 16, offset: Offset(0, 6)),
];

enum _Sort { original, name, worst, best, faults }

String _norm(String s) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñ';
  const to = 'aaaaeeeeiiiioooouuuun';
  var out = s.toLowerCase();
  for (var i = 0; i < from.length; i++) {
    out = out.replaceAll(from[i], to[i]);
  }
  return out.trim();
}

class TeacherCourseDetailScreen extends ConsumerStatefulWidget {
  const TeacherCourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  @override
  ConsumerState<TeacherCourseDetailScreen> createState() =>
      _TeacherCourseDetailScreenState();
}

class _TeacherCourseDetailScreenState
    extends ConsumerState<TeacherCourseDetailScreen> {
  final _search = TextEditingController();
  String _q = '';
  int _filter = 0; // 0 todos, 1 al día, 2 regular, 3 en riesgo
  _Sort _sort = _Sort.original;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _soon(String text) => _snack('$text (próximamente)');

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/teacher');
    }
  }

  /// Busca el curso entre los de ejemplo y los reales.
  CourseDetailVm? _resolve() {
    final real = ref
        .watch(myCoursesProvider)
        .value
        ?.where((c) => c.id == widget.courseId)
        .firstOrNull;
    if (real == null) return null;
    final enrolled =
        ref.watch(enrolledStudentsProvider(widget.courseId)).value ??
        const <EnrolledStudent>[];
    return courseDetailFromCreated(real, enrolled: enrolled);
  }

  List<RosterStudent> _visible(CourseDetailVm vm) {
    final max = vm.maxAbsences;
    final list = vm.students.where((s) {
      final g = s.group(max);
      final matches = switch (_filter) {
        1 => g == RosterGroup.ok,
        2 => g == RosterGroup.regular,
        3 => g == RosterGroup.risk,
        _ => true,
      };
      if (!matches) return false;
      if (_q.isEmpty) return true;
      return _norm(s.name).contains(_q) || _norm(s.code).contains(_q);
    }).toList();

    switch (_sort) {
      case _Sort.name:
        list.sort((a, b) => _norm(a.name).compareTo(_norm(b.name)));
      case _Sort.worst:
        list.sort((a, b) => a.attendance.compareTo(b.attendance));
      case _Sort.best:
        list.sort((a, b) => b.attendance.compareTo(a.attendance));
      case _Sort.faults:
        list.sort((a, b) => b.absences.compareTo(a.absences));
      case _Sort.original:
        break;
    }
    return list;
  }

  void _emitAlert(RosterStudent s, CourseDetailVm vm) {
    final message =
        'Hola ${s.firstName}, en ${vm.name} llevas ${s.absences} inasistencias y el máximo permitido es ${vm.maxAbsences}. '
        'Esto puede afectar tu derecho a presentar el examen final. '
        'Habla con tu docente y, si tienes soportes, radícalos cuanto antes.';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Alerta para ${s.firstName}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: _soft,
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
                child: Text(message, style: const TextStyle(height: 1.4)),
              ),
              const SizedBox(height: 12),
              const Text(
                'El envío automático llegará con las notificaciones. Mientras tanto, copia el mensaje y envíalo por tu medio habitual.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: message));
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) _snack('Mensaje copiado');
            },
            child: const Text('Copiar mensaje'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = _resolve();
    if (vm == null) {
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

    final user = FirebaseAuth.instance.currentUser;
    final initials = initialsOf(displayNameOf(user?.displayName, user?.email));
    final visible = _visible(vm);
    final okCount = vm.countOf(RosterGroup.ok);
    final regularCount = vm.countOf(RosterGroup.regular);
    final riskCount = vm.countOf(RosterGroup.risk);

    final emptyText = vm.students.isEmpty
        ? 'Este curso aún no tiene estudiantes inscritos. Cuando los matricules, aparecerán aquí.'
        : 'Ningún estudiante coincide con tu búsqueda.';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                _TopBar(onBack: _back, initials: initials),
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    children: [
                      _SubBar(
                        vm: vm,
                        onBack: _back,
                        onMenu: (a) {
                          switch (a) {
                            case 'qr':
                              context.push('/teacher/course/${vm.id}/session');
                            case 'add':
                              context.push('/teacher/course/${vm.id}/students');
                            case 'justify':
                              context.push(
                                '/teacher/justifications?course=${vm.id}',
                              );
                            default:
                              context.push('/teacher/course/${vm.id}/stats');
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      _HeaderCard(vm: vm),
                      const SizedBox(height: 14),
                      _AttendanceCard(vm: vm),
                      const SizedBox(height: 12),
                      _StatTiles(vm: vm, risk: riskCount),
                      const SizedBox(height: 14),
                      _TakeAttendanceButton(
                        today: vm.hasClassToday,
                        onTap: () =>
                            context.push('/teacher/course/${vm.id}/session'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.person_add_alt,
                              label: 'Añadir Alumno',
                              onTap: () => context.push(
                                '/teacher/course/${vm.id}/students',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.bar_chart,
                              label: 'Estadísticas',
                              onTap: () => context.push(
                                '/teacher/course/${vm.id}/stats',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _rosterHeader(vm),
                      const SizedBox(height: 12),
                      _searchField(),
                      const SizedBox(height: 12),
                      _filters(
                        vm.students.length,
                        okCount,
                        regularCount,
                        riskCount,
                      ),
                      const SizedBox(height: 12),
                      if (visible.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 32,
                            horizontal: 12,
                          ),
                          child: Center(
                            child: Text(
                              emptyText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      for (final s in visible)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _StudentCard(
                            student: s,
                            maxAbsences: vm.maxAbsences,
                            onTap: () => context.push(
                              '/teacher/course/${vm.id}/student/${s.id}',
                            ),
                            onAlert: () => _emitAlert(s, vm),
                          ),
                        ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: () => _soon('Exportación del reporte'),
                        icon: const Icon(Icons.download_outlined, size: 20),
                        label: const Text(
                          'Exportar Reporte Oficial (Excel / PDF)',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _blueBg,
                          foregroundColor: AppColors.navy,
                          minimumSize: const Size.fromHeight(54),
                          textStyle: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.cloud_done_outlined,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              vm.isSample
                                  ? 'Datos de ejemplo • la lista real se conectará con la matrícula'
                                  : 'Curso guardado en tu cuenta',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
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
    );
  }

  Widget _rosterHeader(CourseDetailVm vm) {
    return Row(
      children: [
        const Text(
          'Roster de Estudiantes',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: const BoxDecoration(
            color: _blueBg,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          child: Text(
            '${vm.students.length}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
        ),
        const Spacer(),
        PopupMenuButton<_Sort>(
          tooltip: 'Ordenar',
          initialValue: _sort,
          onSelected: (s) => setState(() => _sort = s),
          itemBuilder: (_) => const [
            PopupMenuItem(value: _Sort.original, child: Text('Lista original')),
            PopupMenuItem(value: _Sort.name, child: Text('Nombre (A-Z)')),
            PopupMenuItem(
              value: _Sort.worst,
              child: Text('Asistencia (menor a mayor)'),
            ),
            PopupMenuItem(
              value: _Sort.best,
              child: Text('Asistencia (mayor a menor)'),
            ),
            PopupMenuItem(
              value: _Sort.faults,
              child: Text('Más faltas primero'),
            ),
          ],
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swap_vert, size: 18, color: AppColors.navy),
                SizedBox(width: 4),
                Text(
                  'Ordenar',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _search,
      onChanged: (v) => setState(() => _q = _norm(v)),
      decoration: InputDecoration(
        hintText: 'Buscar por nombre o matrícula...',
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
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE1E8F4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE1E8F4)),
        ),
      ),
    );
  }

  Widget _filters(int all, int ok, int regular, int risk) {
    final items = <(String, Color?)>[
      ('Todos ($all)', null),
      ('Al día ($ok)', _teal),
      ('Regular ($regular)', _amber),
      ('En riesgo ($risk)', _red),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            GestureDetector(
              onTap: () => setState(() => _filter = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: _filter == i ? _navyBtn : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _filter == i ? _navyBtn : const Color(0xFFE1E8F4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (items[i].$2 != null) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: items[i].$2,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                    ],
                    Text(
                      items[i].$1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _filter == i ? Colors.white : AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Barras superiores
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
              'Detalle del Curso',
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

class _SubBar extends StatelessWidget {
  const _SubBar({required this.vm, required this.onBack, required this.onMenu});

  final CourseDetailVm vm;
  final VoidCallback onBack;
  final ValueChanged<String> onMenu;

  @override
  Widget build(BuildContext context) {
    final chip = vm.code.isEmpty
        ? null
        : (vm.section == null ? vm.code : '${vm.code} • Sec. ${vm.section}');

    return Row(
      children: [
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, size: 17, color: AppColors.navy),
          label: const Text(
            'Mis Cursos',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const Spacer(),
        if (chip != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: _blueBg,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: Text(
              chip,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
          ),
        PopupMenuButton<String>(
          tooltip: 'Más opciones',
          icon: const Icon(Icons.more_vert, color: AppColors.navy),
          onSelected: onMenu,
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'qr',
              child: Text('Iniciar sesión de clase (QR)'),
            ),
            PopupMenuItem(value: 'add', child: Text('Añadir alumno')),
            PopupMenuItem(value: 'justify', child: Text('Justificaciones')),
            PopupMenuItem(value: 'stats', child: Text('Estadísticas')),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjetas del curso
// ---------------------------------------------------------------------------
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.vm});

  final CourseDetailVm vm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(24)),
        boxShadow: _shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: const BoxDecoration(
                        color: _blueBg,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      child: Text(
                        'CICLO ${vm.cycle.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      vm.name,
                      style: const TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: _navyBtn,
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
                child: const Icon(
                  Icons.account_tree_outlined,
                  size: 25,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (vm.scheduleLabel != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 17,
                        color: AppColors.navy,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          vm.scheduleLabel!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (vm.room != null) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '•',
                      style: TextStyle(color: Color(0xFFB4BFD0)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.apartment_outlined,
                          size: 17,
                          color: AppColors.navy,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            vm.room!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDDE6F5)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Progreso del Semestre',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    Text(
                      '${vm.heldSessions} / ${vm.totalSessions} sesiones (${vm.progressPercent}%)',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: vm.progress,
                    minHeight: 8,
                    color: const Color(0xFF0E4A78),
                    backgroundColor: const Color(0xFFD5E0F2),
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

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.vm});

  final CourseDetailVm vm;

  @override
  Widget build(BuildContext context) {
    final avg = vm.attendance;
    final delta = vm.facultyDelta;

    final (String, IconData, Color, Color)? chip = switch (vm.tone) {
      CourseTone.excellent => (
        'Excelente',
        Icons.verified_outlined,
        _mintStrong,
        const Color(0xFF065F52),
      ),
      CourseTone.optimal => (
        'Óptimo',
        Icons.star_outline,
        _mintStrong,
        const Color(0xFF065F52),
      ),
      CourseTone.normal => ('Normal', Icons.check, _blueBg, AppColors.navy),
      CourseTone.risk => (
        'En riesgo',
        Icons.warning_amber_rounded,
        _amberBg,
        _amberFg,
      ),
      null => null,
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(24)),
        boxShadow: _shadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ASISTENCIA PROMEDIO',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    Text(
                      avg == null ? '—' : '${avg.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        height: 1.1,
                      ),
                    ),
                    if (chip != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: chip.$3,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(chip.$2, size: 15, color: chip.$4),
                            const SizedBox(width: 4),
                            Text(
                              chip.$1,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: chip.$4,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  delta == null
                      ? 'Aún sin sesiones registradas'
                      : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}% vs. promedio de facultad',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 68,
            height: 68,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 68,
                  height: 68,
                  child: CircularProgressIndicator(
                    value: avg == null ? 0 : avg / 100,
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                    color: _teal,
                    backgroundColor: const Color(0xFFD5E0F2),
                  ),
                ),
                const Icon(Icons.trending_up, size: 24, color: _teal),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTiles extends StatelessWidget {
  const _StatTiles({required this.vm, required this.risk});

  final CourseDetailVm vm;
  final int risk;

  @override
  Widget build(BuildContext context) {
    final hasRisk = risk > 0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Tile(
              icon: Icons.groups_outlined,
              iconColor: AppColors.navy,
              chip: 'Roster',
              chipBg: _blueBg,
              chipFg: AppColors.navy,
              value: '${vm.students.length}',
              valueColor: AppColors.navy,
              label: 'Alumnos inscritos',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Tile(
              icon: Icons.warning_amber_rounded,
              iconColor: hasRisk ? _red : AppColors.navy,
              chip: 'Alerta',
              chipBg: hasRisk ? _redBg : _blueBg,
              chipFg: hasRisk ? _red : AppColors.navy,
              value: '$risk',
              valueColor: hasRisk ? _red : AppColors.navy,
              label: 'En riesgo crítico (<80%)',
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.iconColor,
    required this.chip,
    required this.chipBg,
    required this.chipFg,
    required this.value,
    required this.valueColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String chip;
  final Color chipBg;
  final Color chipFg;
  final String value;
  final Color valueColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(22)),
        boxShadow: _shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  chip,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: chipFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: valueColor,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textMuted,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _TakeAttendanceButton extends StatelessWidget {
  const _TakeAttendanceButton({required this.today, required this.onTap});

  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _navyBtn,
      borderRadius: BorderRadius.circular(22),
      elevation: 4,
      shadowColor: const Color(0x440A2F52),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.sensors,
                      size: 25,
                      color: Colors.white,
                    ),
                  ),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: const BoxDecoration(
                        color: _mintStrong,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'Activar Toma de Asistencia',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        if (today)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _teal,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'HOY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Código Dinámico QR',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _mintStrong,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 1.5,
      shadowColor: const Color(0x1A0B3A5E),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: AppColors.navy),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta de estudiante
// ---------------------------------------------------------------------------
({
  Color accent,
  Color avatarBg,
  Color avatarFg,
  Color pct,
  Color faults,
  Color pillBg,
  Color pillFg,
  String pill,
})
_styleOf(RosterStatus s) {
  const green = Color(0xFF065F52);
  const dark = Color(0xFF3D4B5C);

  switch (s) {
    case RosterStatus.perfect:
      return (
        accent: _teal,
        avatarBg: _mintStrong,
        avatarFg: green,
        pct: AppColors.navy,
        faults: _teal,
        pillBg: _mintStrong,
        pillFg: green,
        pill: 'Perfecta',
      );
    case RosterStatus.excellent:
      return (
        accent: _teal,
        avatarBg: _mintStrong,
        avatarFg: green,
        pct: AppColors.navy,
        faults: _teal,
        pillBg: _mintStrong,
        pillFg: green,
        pill: 'Excelente',
      );
    case RosterStatus.ok:
      return (
        accent: _teal,
        avatarBg: _mintStrong,
        avatarFg: green,
        pct: AppColors.navy,
        faults: _teal,
        pillBg: _mintStrong,
        pillFg: green,
        pill: 'Al día',
      );
    case RosterStatus.regular:
      return (
        accent: _amber,
        avatarBg: _amberBg,
        avatarFg: _amberFg,
        pct: AppColors.navy,
        faults: dark,
        pillBg: _amberBg,
        pillFg: _amberFg,
        pill: 'Regular',
      );
    case RosterStatus.attention:
      return (
        accent: _amber,
        avatarBg: _amberBg,
        avatarFg: _amberFg,
        pct: AppColors.navy,
        faults: dark,
        pillBg: _amberBg,
        pillFg: _amberFg,
        pill: 'Atención',
      );
    case RosterStatus.risk:
      return (
        accent: _red,
        avatarBg: _redBg,
        avatarFg: _red,
        pct: _red,
        faults: _red,
        pillBg: _redBg,
        pillFg: _red,
        pill: 'En Riesgo',
      );
    case RosterStatus.lost:
      return (
        accent: _red,
        avatarBg: _redBg,
        avatarFg: _red,
        pct: _red,
        faults: _red,
        pillBg: _redBg,
        pillFg: _red,
        pill: 'Riesgo Pérdida',
      );
    case RosterStatus.none:
      return (
        accent: const Color(0xFF2F6AA8),
        avatarBg: _blueBg,
        avatarFg: AppColors.navy,
        pct: AppColors.textMuted,
        faults: AppColors.textMuted,
        pillBg: _blueBg,
        pillFg: AppColors.navy,
        pill: 'Nuevo',
      );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.student,
    required this.maxAbsences,
    required this.onTap,
    required this.onAlert,
  });

  final RosterStudent student;
  final int maxAbsences;
  final VoidCallback onTap;
  final VoidCallback onAlert;

  @override
  Widget build(BuildContext context) {
    final s = student;
    final status = s.status(maxAbsences);
    final st = _styleOf(status);
    final lost = status == RosterStatus.lost;
    final left = (maxAbsences - s.absences).clamp(0, 99).toInt();

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: _shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: lost ? _redBg : Colors.white,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: st.avatarBg,
                            child: Text(
                              s.initials,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: st.avatarFg,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        s.name,
                                        style: const TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.navy,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                    if (s.starred) ...[
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.star,
                                        size: 15,
                                        color: _teal,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: s.code,
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: '  •  ',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                      TextSpan(
                                        text: s.faultsText(maxAbsences),
                                        style: TextStyle(
                                          color: st.faults,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                s.noData ? '—' : '${s.attendance}%',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: st.pct,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: st.pillBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: lost
                                      ? Border.all(color: _redBorder)
                                      : null,
                                ),
                                child: Text(
                                  st.pill,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: st.pillFg,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!lost)
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFFB4BFD0),
                            ),
                        ],
                      ),
                      if (lost) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9D6D6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.notifications_none,
                                size: 20,
                                color: _red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'A $left ${left == 1 ? 'sesión' : 'sesiones'} de inhabilitación',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _red,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: onAlert,
                                icon: const Icon(Icons.send, size: 15),
                                label: const Text('Emitir Alerta'),
                                iconAlignment: IconAlignment.end,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFB3261E),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  textStyle: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 5,
                  child: ColoredBox(color: st.accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
