import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/name_utils.dart';
import '../data/course_repository.dart';
import '../data/teacher_mock_data.dart';
import 'widgets/created_course_card.dart';
import 'widgets/teacher_widgets.dart';
import '../../justifications/data/justification_data.dart';

const _teal = Color(0xFF066A5C);
const _blueBg = Color(0xFFE3EBFA);

enum _Period { today, week }

class TeacherHomeTab extends ConsumerStatefulWidget {
  const TeacherHomeTab({super.key});

  @override
  ConsumerState<TeacherHomeTab> createState() => _TeacherHomeTabState();
}

class _TeacherHomeTabState extends ConsumerState<TeacherHomeTab> {
  int _filter =
      0; // 0 todos, 1 clase hoy, 2 mayor asistencia, 3 casos en riesgo
  _Period _period = _Period.today;

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _soon(String text) => _snack('$text (próximamente)');

  String _greeting(DateTime now) {
    if (now.hour < 12) return 'Buenos días';
    if (now.hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  List<TeacherCourse> _visible(List<TeacherCourse> all, DateTime now) {
    switch (_filter) {
      case 1:
        return all.where((c) => c.hasClassOn(now.weekday)).toList();
      case 2:
        return [...all]..sort((a, b) => b.attendance.compareTo(a.attendance));
      case 3:
        return all.where((c) => c.atRisk > 0).toList();
      default:
        return all;
    }
  }

  void _onAction(TeacherCourse c, CourseAction a) {
    switch (a) {
      case CourseAction.takeAttendance:
        context.push('/teacher/course/${c.id}/session');
      case CourseAction.roster:
        _soon('Lista de estudiantes');
      case CourseAction.review:
        context.push('/teacher/justifications');
      case CourseAction.details:
        context.push('/teacher/course/${c.id}');
    }
  }

  Future<void> _activate(CreatedCourse c) async {
    try {
      await ref
          .read(courseRepositoryProvider)
          .activateCourse(c.id)
          .timeout(const Duration(seconds: 10));
      if (mounted) _snack('Curso activado');
    } catch (_) {
      if (mounted) _snack('No se pudo activar el curso. Revisa tu conexión.');
    }
  }

  Future<void> _delete(CreatedCourse c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          '¿Eliminar borrador?',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy),
        ),
        content: Text(
          'Se eliminará "${c.name}". Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Color(0xFFD92D20)),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref
          .read(courseRepositoryProvider)
          .deleteDraft(c.id)
          .timeout(const Duration(seconds: 10));
      if (mounted) _snack('Borrador eliminado');
    } catch (_) {
      if (mounted) _snack('No se pudo eliminar el borrador.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final fullName = displayNameOf(user?.displayName, user?.email);
    final now = DateTime.now();

    // Cursos reales creados por el docente (Firestore).
    final real = ref.watch(myCoursesProvider).value ?? const <CreatedCourse>[];
    final pendingJust =
        ref
            .watch(teacherJustificationsProvider)
            .value
            ?.where((j) => j.status == JustificationStatus.pending)
            .length ??
        0;
    final realActive = real.where((c) => !c.isDraft).length;

    // DATOS DE EJEMPLO: salen de teacher_mock_data.dart.
    final all = sampleTeacherCourses;
    final todayCourses = all.where((c) => c.hasClassOn(now.weekday)).toList();
    final totalStudents =
        all.fold<int>(0, (s, c) => s + c.students) +
        real.fold<int>(0, (s, c) => s + c.studentCount);
    final weekSessions = all.fold<int>(0, (s, c) => s + c.weekdays.length);
    final courses = _visible(all, now);

    final totalCourses = all.length + real.length;
    final sessions = _period == _Period.today
        ? todayCourses.length
        : weekSessions;
    final sessionsLabel = _period == _Period.today
        ? (sessions == 1 ? 'Sesión para hoy' : 'Sesiones para hoy')
        : 'Sesiones esta semana';

    final labels = [
      'Todos ($totalCourses)',
      'Clase hoy (${todayCourses.length})',
      'Mayor asistencia',
      'Casos en riesgo',
    ];

    final showReal = _filter == 0;
    final nothing = courses.isEmpty && (!showReal || real.isEmpty);

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
          children: [
            Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: const BoxDecoration(
                      color: _blueBg,
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 15,
                          color: AppColors.navy,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            sampleTeacher.department.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                _PeriodButton(
                  period: _period,
                  onChanged: (p) => setState(() => _period = p),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '¡${_greeting(now)}, Prof. ${firstNameOf(fullName)}!',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${sampleTeacher.faculty} • Ciclo Académico ${sampleTeacher.cycle}',
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.35,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 18),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: TeacherStatCard(
                      icon: Icons.menu_book_outlined,
                      iconBg: _blueBg,
                      iconColor: AppColors.navy,
                      value: '${all.length + realActive}',
                      label: 'Cursos activos',
                      valueColor: AppColors.navy,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TeacherStatCard(
                      icon: Icons.groups_outlined,
                      iconBg: _blueBg,
                      iconColor: AppColors.navy,
                      value: '$totalStudents',
                      label: 'Matriculados',
                      valueColor: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: TeacherStatCard(
                      icon: Icons.bar_chart,
                      iconBg: const Color(0xFF9DEBD9),
                      iconColor: AppColors.navy,
                      value: '${sampleTeacher.globalAttendance}%',
                      label: 'Asistencia global',
                      valueColor: _teal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TeacherStatCard(
                      icon: Icons.co_present_outlined,
                      iconBg: const Color(0xFF0E4A78),
                      iconColor: Colors.white,
                      value: '$sessions',
                      label: sessionsLabel,
                      valueColor: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
            if (pendingJust > 0) ...[
              const SizedBox(height: 16),
              _JustifyBanner(
                count: pendingJust,
                onTap: () => context.push('/teacher/justifications'),
              ),
            ],
            const SizedBox(height: 26),
            Row(
              children: [
                const Text(
                  'Mis cursos creados',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: const BoxDecoration(
                    color: _blueBg,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Text(
                    '$totalCourses',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _soon('Filtros avanzados'),
                  icon: const Icon(Icons.tune, size: 18, color: AppColors.navy),
                  label: const Text(
                    'Filtrar',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < labels.length; i++) ...[
                    GestureDetector(
                      onTap: () => setState(() => _filter = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: _filter == i
                              ? const Color(0xFF0A2F52)
                              : _blueBg,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _filter == i ? Colors.white : AppColors.navy,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (nothing)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: Text(
                    'No hay cursos en esta categoría.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ),
            if (showReal)
              for (final r in real)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: CreatedCourseCard(
                    course: r,
                    onActivate: () => _activate(r),
                    onDelete: () => _delete(r),
                    onSoon: (text) {
                      if (text == 'Detalle del curso') {
                        context.push('/teacher/course/${r.id}');
                      } else if (text == 'Matrícula de estudiantes') {
                        context.push('/teacher/course/${r.id}/students');
                      } else {
                        _soon(text);
                      }
                    },
                  ),
                ),
            for (final c in courses)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TeacherCourseCard(
                  course: c,
                  now: now,
                  onTap: () => context.push('/teacher/course/${c.id}'),
                  onAction: (a) => _onAction(c, a),
                ),
              ),
          ],
        ),
        Positioned(
          right: 20,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: null,
            onPressed: () => context.push('/teacher/courses/new'),
            backgroundColor: const Color(0xFF0E4A78),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text(
              'Crear curso',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({required this.period, required this.onChanged});

  final _Period period;
  final ValueChanged<_Period> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_Period>(
      onSelected: onChanged,
      itemBuilder: (_) => const [
        PopupMenuItem(value: _Period.today, child: Text('Hoy')),
        PopupMenuItem(value: _Period.week, child: Text('Esta semana')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120B3A5E),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 17,
              color: AppColors.navy,
            ),
            const SizedBox(width: 8),
            Text(
              period == _Period.today ? 'Hoy' : 'Esta semana',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: AppColors.navy,
            ),
          ],
        ),
      ),
    );
  }
}

class _JustifyBanner extends StatelessWidget {
  const _JustifyBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFE8CC),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(
                Icons.pending_actions,
                size: 24,
                color: Color(0xFFB45309),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  count == 1
                      ? 'Tienes 1 justificación por revisar'
                      : 'Tienes $count justificaciones por revisar',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7A4A12),
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF7A4A12)),
            ],
          ),
        ),
      ),
    );
  }
}
