import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/name_utils.dart';
import '../../attendance/data/attendance_models.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/data/local_session_store.dart';
import '../data/course_repository.dart';
import '../data/enrollment_repository.dart';
import '../data/teacher_course_detail_data.dart';
import '../data/teacher_mock_data.dart';

const _teal = Color(0xFF066A5C);
const _mint = Color(0xFFD7F5EA);
const _mintStrong = Color(0xFF9DEBD9);
const _blueBg = Color(0xFFE3EBFA);
const _soft = Color(0xFFEFF3FC);
const _navyBtn = Color(0xFF0A2F52);
const _amberFg = Color(0xFFB45309);
const _amberBg = Color(0xFFFFE8CC);

const _shadow = [
  BoxShadow(color: Color(0x120B3A5E), blurRadius: 16, offset: Offset(0, 6)),
];

String _two(int n) => n.toString().padLeft(2, '0');

String _timeRange(TeacherCourse c) =>
    '${_two(c.startHour)}:${_two(c.startMinute)} - ${_two(c.endHour)}:${_two(c.endMinute)}';

class _CourseVm {
  const _CourseVm({
    required this.name,
    required this.code,
    required this.room,
    required this.schedule,
    required this.enrolled,
    required this.sessionNumber,
    required this.total,
    required this.isSample,
    required this.isActive,
    this.section,
  });

  final String name;
  final String code;
  final String? section;
  final String room;
  final String schedule;
  final int enrolled;
  final int sessionNumber;
  final int total;
  final bool isSample;
  final bool isActive;
}

class SessionSetupScreen extends ConsumerStatefulWidget {
  const SessionSetupScreen({super.key, required this.courseId});

  final String courseId;

  @override
  ConsumerState<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends ConsumerState<SessionSetupScreen> {
  static const _minCustom = 2;
  static const _maxCustom = 120;

  final _store = LocalSessionStore();

  int? _preset = 10; // null = personalizado
  int _custom = 12;
  bool _strict = true; // true: el código cambia cada 15 s; false: cada 60 s
  bool _starting = false;
  String _room = '';
  bool _roomEdited = false;
  int? _realSessionCount;
  LocalSession? _active;

  int get _minutes => _preset ?? _custom;

  @override
  void initState() {
    super.initState();
    _loadActive();
    final isSample =
        sampleCourseDetail(widget.courseId, DateTime.now()) != null;
    if (!isSample) _loadCount();
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

  Future<void> _loadActive() async {
    final s = await _store.load();
    if (!mounted) return;
    final alive =
        s != null &&
        s.endsAtMs > DateTime.now().millisecondsSinceEpoch + s.offsetMs;
    setState(() => _active = alive ? s : null);
  }

  Future<void> _loadCount() async {
    final n = await ref
        .read(attendanceRepositoryProvider)
        .countSessions(widget.courseId);
    if (mounted) setState(() => _realSessionCount = n);
  }

  _CourseVm? _resolve() {
    final sample = sampleCourseDetail(widget.courseId, DateTime.now());
    if (sample != null) {
      final tc = sampleTeacherCourses
          .where((c) => c.id == widget.courseId)
          .firstOrNull;
      return _CourseVm(
        name: sample.name,
        code: sample.code,
        section: sample.section,
        room: sample.room ?? '',
        schedule: tc == null ? '' : _timeRange(tc),
        enrolled: sample.students.length,
        sessionNumber: sample.heldSessions + 1,
        total: sample.totalSessions,
        isSample: true,
        isActive: true,
      );
    }

    final real = ref
        .watch(myCoursesProvider)
        .value
        ?.where((c) => c.id == widget.courseId)
        .firstOrNull;
    if (real == null) return null;

    final enrolled =
        ref.watch(enrolledStudentsProvider(widget.courseId)).value?.length ??
        real.studentCount;
    return _CourseVm(
      name: real.name,
      code: real.code,
      room: '',
      schedule: '',
      enrolled: enrolled,
      sessionNumber: (_realSessionCount ?? 0) + 1,
      total: real.totalSessions,
      isSample: false,
      isActive: !real.isDraft,
    );
  }

  Future<void> _editRoom(String current) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _RoomDialog(initial: current),
    );
    if (value != null && mounted) {
      setState(() {
        _room = value.trim();
        _roomEdited = true;
      });
    }
  }

  Future<void> _start(_CourseVm vm) async {
    if (_starting) return;
    setState(() => _starting = true);

    try {
      final room = (_roomEdited ? _room : vm.room).trim();
      final s = await ref
          .read(attendanceRepositoryProvider)
          .createSession(
            courseId: widget.courseId,
            courseName: vm.name,
            room: room,
            minutes: _minutes,
            stepSeconds: _strict ? 15 : 60,
            courseCode: vm.code,
            section: vm.section,
            sessionNumber: vm.sessionNumber,
          );
      await _store.save(s);
      if (!mounted) return;
      // La pantalla de sesión retoma la sesión guardada en este dispositivo.
      context.pushReplacement('/teacher/session');
    } on OfflineException {
      if (mounted) {
        _snack(
          'Necesitas conexión para iniciar la sesión. Después el QR funciona sin internet.',
        );
      }
    } on TimeoutException {
      if (mounted) _snack('La conexión es muy lenta. Intenta de nuevo.');
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _snack(
        e.code == 'permission-denied'
            ? 'Sin permiso: usa una cuenta de docente y publica las reglas de Firestore.'
            : 'No se pudo iniciar la sesión (${e.code}).',
      );
    } catch (_) {
      if (mounted) _snack('No se pudo iniciar la sesión.');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _cancel() {
    _snack(
      'No se inició la sesión. Puedes iniciarla cuando quieras desde el curso.',
    );
    _back();
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
    final room = (_roomEdited ? _room : vm.room).trim();
    final active = _active;
    final canStart = vm.isActive && active == null && !_starting;

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
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    children: [
                      if (active != null)
                        _ActiveBanner(
                          session: active,
                          onOpen: () =>
                              context.pushReplacement('/teacher/session'),
                        ),
                      if (!vm.isActive)
                        const _InfoBanner(
                          icon: Icons.edit_note,
                          text: 'Este curso es un borrador. Actívalo desde el home para poder iniciar sesiones.',
                        ),
                      _HeaderCard(
                        vm: vm,
                        room: room,
                        onEditRoom: () => _editRoom(room),
                      ),
                      const SizedBox(height: 14),
                      _durationCard(),
                      const SizedBox(height: 14),
                      _securityCard(),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: canStart ? () => _start(vm) : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: _navyBtn,
                          minimumSize: const Size.fromHeight(58),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _starting
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
                                  Icon(Icons.sensors, size: 22),
                                  SizedBox(width: 10),
                                  Text(
                                    'Iniciar sesión de asistencia',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: _starting ? null : _cancel,
                        style: FilledButton.styleFrom(
                          backgroundColor: _blueBg,
                          foregroundColor: AppColors.navy,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy_outlined, size: 21),
                            SizedBox(width: 10),
                            Text(
                              'Cancelar o posponer',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(
                          color: _blueBg,
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.desktop_windows_outlined,
                                  size: 18,
                                  color: AppColors.navy,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Al iniciar, la sesión se abrirá en modo de proyección para que los alumnos escaneen desde sus asientos.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.4,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.wifi,
                                  size: 18,
                                  color: AppColors.textMuted,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Iniciar requiere conexión una sola vez. Después el código se genera en este dispositivo, aunque no haya internet.',
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------ Duración ------------------------------

  Widget _durationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: _mint,
                  borderRadius: BorderRadius.all(Radius.circular(11)),
                ),
                child: const Icon(Icons.timer_outlined, size: 21, color: _teal),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    'Duración de la ventana de asistencia',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Los estudiantes podrán registrar su asistencia escaneando el código QR durante este lapso.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          _DurationOption(
            selected: _preset == 5,
            title: '5 minutos',
            subtitle: 'Rápida / Clases pequeñas',
            trailing: const Icon(
              Icons.bolt,
              size: 22,
              color: Color(0xFFB4BFD0),
            ),
            onTap: () => setState(() => _preset = 5),
          ),
          const SizedBox(height: 10),
          _DurationOption(
            selected: _preset == 10,
            title: '10 minutos',
            badge: 'Recomendado',
            subtitle: 'Estándar recomendado',
            trailing: const Icon(Icons.star, size: 22, color: AppColors.navy),
            onTap: () => setState(() => _preset = 10),
          ),
          const SizedBox(height: 10),
          _DurationOption(
            selected: _preset == 15,
            title: '15 minutos',
            subtitle: 'Tolerancia extendida / Evaluaciones',
            trailing: const Icon(
              Icons.hourglass_bottom,
              size: 22,
              color: Color(0xFFB4BFD0),
            ),
            onTap: () => setState(() => _preset = 15),
          ),
          const SizedBox(height: 10),
          _DurationOption(
            selected: _preset == null,
            title: 'Personalizado',
            subtitle: 'Ajuste manual del docente',
            trailing: _CustomStepper(
              value: _custom,
              onMinus: () => setState(() {
                _preset = null;
                _custom = (_custom - 1).clamp(_minCustom, _maxCustom).toInt();
              }),
              onPlus: () => setState(() {
                _preset = null;
                _custom = (_custom + 1).clamp(_minCustom, _maxCustom).toInt();
              }),
            ),
            onTap: () => setState(() => _preset = null),
          ),
        ],
      ),
    );
  }

  // ------------------------------ Seguridad ------------------------------

  Widget _securityCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: _mint,
                  borderRadius: BorderRadius.all(Radius.circular(11)),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 21,
                  color: _teal,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    'Seguridad y validación',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 50),
            child: Text(
              'Parámetros anti-fraude para proteger la presencialidad.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: _blueBg,
                  borderRadius: BorderRadius.all(Radius.circular(13)),
                ),
                child: const Icon(
                  Icons.qr_code_scanner,
                  size: 24,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Código QR dinámico anti-captura',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _strict
                          ? 'Refresco criptográfico de token cada 15 segundos.'
                          : 'Refresco cada 60 segundos: tolera proyectores lentos, pero una captura sirve durante más tiempo.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: _strict,
                onChanged: (v) => setState(() => _strict = v),
                thumbColor: const WidgetStatePropertyAll(Colors.white),
                trackColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? _teal
                      : const Color(0xFFB4BFD0),
                ),
                trackOutlineColor: const WidgetStatePropertyAll(
                  Colors.transparent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.fromLTRB(4, 6, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: AppColors.navy),
          ),
          const Expanded(
            child: Text(
              'Detalle de Sesión',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
          ),
          CircleAvatar(
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
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.vm,
    required this.room,
    required this.onEditRoom,
  });

  final _CourseVm vm;
  final String room;
  final VoidCallback onEditRoom;

  @override
  Widget build(BuildContext context) {
    final codeChip = vm.code.isEmpty
        ? null
        : (vm.section == null ? vm.code : '${vm.code} • Sec. ${vm.section}');
    final roomShown = room.isEmpty
        ? 'Por definir'
        : room.replaceFirst(RegExp(r'^Aula\s+', caseSensitive: false), '');
    final students =
        '${vm.enrolled} ${vm.enrolled == 1 ? 'alumno' : 'alumnos'}';

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(24)),
        boxShadow: _shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
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
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                if (codeChip != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: _blueBg,
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      codeChip,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: _mintStrong,
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(10),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_outline,
                                        size: 14,
                                        color: Color(0xFF065F52),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Sesión ${vm.sessionNumber} de ${vm.total}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF065F52),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              vm.name,
                              style: const TextStyle(
                                fontSize: 24,
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
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _blueBg,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.school_outlined,
                          size: 23,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                      color: _soft,
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: onEditRoom,
                              child: _InfoCell(
                                icon: Icons.apartment_outlined,
                                label: 'Aula',
                                value: roomShown,
                                editable: true,
                              ),
                            ),
                          ),
                          const VerticalDivider(
                            width: 1,
                            color: Color(0xFFD3DDF0),
                          ),
                          Expanded(
                            child: _InfoCell(
                              icon: Icons.schedule,
                              label: 'Horario',
                              value: vm.schedule.isEmpty
                                  ? 'Por definir'
                                  : vm.schedule,
                            ),
                          ),
                          const VerticalDivider(
                            width: 1,
                            color: Color(0xFFD3DDF0),
                          ),
                          Expanded(
                            child: _InfoCell(
                              icon: Icons.groups_outlined,
                              label: 'Matrícula',
                              value: students,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: const ColoredBox(color: AppColors.navy),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({
    required this.icon,
    required this.label,
    required this.value,
    this.editable = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: AppColors.navy),
              if (editable) ...[
                const SizedBox(width: 3),
                const Icon(
                  Icons.edit_outlined,
                  size: 11,
                  color: AppColors.textMuted,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationOption extends StatelessWidget {
  const _DurationOption({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.badge,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final String? badge;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFD9E6F8) : _soft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: selected ? AppColors.navy : const Color(0xFFB4BFD0),
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: const BoxDecoration(
                          color: AppColors.navy,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _teal,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.3,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _CustomStepper extends StatelessWidget {
  const _CustomStepper({
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  Widget _btn(IconData icon, VoidCallback onTap) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(11),
    elevation: 1,
    shadowColor: const Color(0x1A0B3A5E),
    child: InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Icon(icon, size: 19, color: AppColors.navy),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(Icons.remove, onMinus),
        SizedBox(
          width: 40,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                  height: 1.1,
                ),
              ),
              const Text(
                'min',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        _btn(Icons.add, onPlus),
      ],
    );
  }
}

class _ActiveBanner extends StatelessWidget {
  const _ActiveBanner({required this.session, required this.onOpen});

  final LocalSession session;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _mint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _mintStrong),
      ),
      child: Row(
        children: [
          const Icon(Icons.sensors, size: 22, color: _teal),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ya tienes una sesión en curso',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF065F52),
                  ),
                ),
                Text(
                  '${session.courseName}. Finalízala antes de iniciar otra.',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Color(0xFF0B5C47),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              backgroundColor: _teal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Volver a la sesión'),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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

class _RoomDialog extends StatefulWidget {
  const _RoomDialog({required this.initial});

  final String initial;

  @override
  State<_RoomDialog> createState() => _RoomDialogState();
}

class _RoomDialogState extends State<_RoomDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        'Aula de la sesión',
        style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Ej. Aula Magna B'),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}
