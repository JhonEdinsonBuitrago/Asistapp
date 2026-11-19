import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/name_utils.dart';
import '../../justifications/data/justification_data.dart';
import '../data/course_repository.dart';
import '../data/teacher_overview_data.dart';
import 'widgets/created_course_card.dart';
import 'widgets/teacher_widgets.dart';

const _teal = Color(0xFF066A5C);
const _blueBg = Color(0xFFE3EBFA);

enum _Period { today, week }

class TeacherHomeTab extends ConsumerStatefulWidget {
  const TeacherHomeTab({super.key});

  @override
  ConsumerState<TeacherHomeTab> createState() => _TeacherHomeTabState();
}

class _TeacherHomeTabState extends ConsumerState<TeacherHomeTab> {
  int _filter = 0; // 0 todos, 1 activos, 2 borradores
  _Period _period = _Period.today;

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String _greeting(DateTime now) {
    if (now.hour < 12) return 'Buenos días';
    if (now.hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  Future<void> _refresh() async {
    refreshTeacherData(ref);
    try {
      await ref.read(teacherOverviewProvider.future);
    } catch (_) {
      // El error no bloquea la pantalla.
    }
  }

  Future<void> _activate(CreatedCourse c) async {
    try {
      await ref
          .read(courseRepositoryProvider)
          .activateCourse(c.id)
          .timeout(const Duration(seconds: 10));
      ref.invalidate(teacherOverviewProvider);
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

    final coursesAsync = ref.watch(myCoursesProvider);
    final all = coursesAsync.value ?? const <CreatedCourse>[];
    final active = all.where((c) => !c.isDraft).length;
    final students = all.fold<int>(0, (s, c) => s + c.studentCount);

    final overview = ref.watch(teacherOverviewProvider).value;
    final attendance = overview?.attendance;
    final sessions = overview == null
        ? null
        : (_period == _Period.today
              ? overview.sessionsToday
              : overview.sessionsWeek);

    final pendingJust =
        ref
            .watch(teacherJustificationsProvider)
            .value
            ?.where((j) => j.status == JustificationStatus.pending)
            .length ??
        0;

    final courses = switch (_filter) {
      1 => all.where((c) => !c.isDraft).toList(),
      2 => all.where((c) => c.isDraft).toList(),
      _ => all,
    };

    final labels = [
      'Todos (${all.length})',
      'Activos ($active)',
      'Borradores (${all.length - active})',
    ];

    final sessionsLabel = _period == _Period.today
        ? (sessions == 1 ? 'Sesión hoy' : 'Sesiones hoy')
        : 'Sesiones esta semana';

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: const BoxDecoration(
                      color: _blueBg,
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 15,
                          color: AppColors.navy,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'DOCENTE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
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
                user?.email ?? '',
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
                        value: '$active',
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
                        value: '$students',
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
                        value: attendance == null
                            ? '—'
                            : '${attendance.toStringAsFixed(1)}%',
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
                        value: sessions == null ? '—' : '$sessions',
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
                    'Mis cursos',
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
                      '${all.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
                              color: _filter == i
                                  ? Colors.white
                                  : AppColors.navy,
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
              if (coursesAsync.isLoading && all.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (all.isEmpty)
                _EmptyCourses(
                  onCreate: () => context.push('/teacher/courses/new'),
                )
              else if (courses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: Text(
                      'No hay cursos en esta categoría.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ),
              for (final c in courses)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: CreatedCourseCard(
                    course: c,
                    onActivate: () => _activate(c),
                    onDelete: () => _delete(c),
                    onSoon: (text) {
                      if (text == 'Detalle del curso') {
                        context.push('/teacher/course/${c.id}');
                      } else if (text == 'Matrícula de estudiantes') {
                        context.push('/teacher/course/${c.id}/students');
                      } else {
                        _snack('$text (próximamente)');
                      }
                    },
                  ),
                ),
            ],
          ),
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

class _EmptyCourses extends StatelessWidget {
  const _EmptyCourses({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x120B3A5E),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.menu_book_outlined,
            size: 46,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          const Text(
            'Aún no has creado cursos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Crea tu primer curso, matricula a tus estudiantes y empieza a tomar asistencia.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Crear mi primer curso'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0A2F52),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
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
