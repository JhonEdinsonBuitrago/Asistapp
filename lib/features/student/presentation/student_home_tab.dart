import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/name_utils.dart';
import '../data/student_courses_data.dart';
import '../data/student_profile_data.dart';
import 'widgets/student_widgets.dart';
import '../../justifications/data/justification_data.dart';

/// Si el estudiante aún no tiene cursos reales, se muestran los de ejemplo
/// (con un aviso). Ponlo en false para ver solo datos reales.
const kShowSampleWhenEmpty = true;

const _teal = Color(0xFF066A5C);
const _mint = Color(0xFFD7F5EA);
const _blueBg = Color(0xFFE3EBFA);
const _red = Color(0xFFD92D20);
const _amberFg = Color(0xFFB45309);
const _amberBg = Color(0xFFFFE8CC);

class StudentHomeTab extends ConsumerStatefulWidget {
  const StudentHomeTab({super.key});

  @override
  ConsumerState<StudentHomeTab> createState() => _StudentHomeTabState();
}

class _StudentHomeTabState extends ConsumerState<StudentHomeTab> {
  int _filter = 0; // 0 = todos, 1 = en riesgo

  void _soon(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$text (próximamente)')));
  }

  Future<void> _refresh() async {
    ref.invalidate(studentOverviewProvider);
    try {
      await ref.read(studentOverviewProvider.future);
    } catch (_) {
      // El error se muestra en pantalla.
    }
  }

  Future<void> _pickCourseToScan(StudentOverview ov) async {
    if (ov.courses.length == 1) {
      context.push('/student/course/${ov.courses.first.course.id}/scan');
      return;
    }
    final id = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _CoursePickerSheet(courses: [for (final c in ov.courses) c.course]),
    );
    if (id != null && mounted) context.push('/student/course/$id/scan');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final profile = ref.watch(studentProfileProvider).value;
    final fullName = displayNameOf(
      (profile?.name.isNotEmpty ?? false) ? profile!.name : user?.displayName,
      user?.email,
    );

    final async = ref.watch(studentOverviewProvider);
    final overview = async.value;

    final List<Widget> children;
    if (overview == null) {
      children = async.hasError ? _errorChildren() : _loadingChildren();
    } else if (overview.courses.isNotEmpty) {
      children = _realChildren(overview, fullName, profile);
    } else {
      children = _emptyChildren(fullName);
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: children,
      ),
    );
  }

  // ------------------------------ Estados ------------------------------

  List<Widget> _loadingChildren() => const [
    Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Center(child: CircularProgressIndicator()),
    ),
  ];

  List<Widget> _errorChildren() => [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 12),
      child: Column(
        children: [
          const Text(
            'No se pudieron cargar tus cursos. Revisa tu conexión.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _red, height: 1.4),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  ];

  List<Widget> _emptyChildren(String fullName) => [
    _Greeting(
      name: firstNameOf(fullName),
      initials: initialsOf(fullName),
      program: 'Aún no estás matriculado en ningún curso',
      onCalendar: () => _soon('Calendario académico'),
    ),
    const SizedBox(height: 40),
    const Icon(Icons.menu_book_outlined, size: 56, color: AppColors.textMuted),
    const SizedBox(height: 14),
    const Text(
      'Todavía no tienes cursos',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AppColors.navy,
      ),
    ),
    const SizedBox(height: 8),
    const Text(
      'Cuando un docente te matricule en un curso, aparecerá aquí.',
      textAlign: TextAlign.center,
      style: TextStyle(color: AppColors.textMuted, height: 1.4),
    ),
  ];

  // ------------------------------ Cursos reales ------------------------------

  List<Widget> _realChildren(
    StudentOverview ov,
    String fullName,
    StudentProfileData? profile,
  ) {
    final courses = _filter == 0
        ? ov.courses
        : ov.courses.where((c) => c.status != CourseStatus.safe).toList();

    final code = profile?.studentCode;
    final subtitle = (code != null && code.isNotEmpty)
        ? 'Código estudiantil: $code'
        : (profile?.email ?? '');

    final justifiable = justifiableSummary(
      ov,
      ref.watch(myJustificationsProvider).value ?? const <JustificationInfo>[],
      DateTime.now(),
    );
    return [
      _Greeting(
        name: firstNameOf(fullName),
        initials: initialsOf(fullName),
        program: subtitle,
        onCalendar: () => _soon('Calendario académico'),
      ),
      const SizedBox(height: 18),
      _RealSummaryCard(overview: ov, onScan: () => _pickCourseToScan(ov)),
      if (justifiable.count > 0) ...[
        const SizedBox(height: 14),
        JustificationBanner(
          hoursLeft: justifiable.minHoursLeft,
          onJustify: () => context.push('/student/justifications'),
        ),
      ],
      const SizedBox(height: 22),
      _CoursesHeader(count: ov.courses.length),
      const SizedBox(height: 12),
      CourseFilterTabs(
        index: _filter,
        total: ov.courses.length,
        riskCount: ov.riskCount,
        onChanged: (i) => setState(() => _filter = i),
      ),
      const SizedBox(height: 14),
      if (courses.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              'No tienes cursos en riesgo.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ),
      for (final c in courses)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _RealCourseCard(
            item: c,
            onTap: () async {
              await context.push('/student/course/${c.course.id}');
              ref.invalidate(studentOverviewProvider);
            },
          ),
        ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Piezas
// ---------------------------------------------------------------------------
class _CoursesHeader extends StatelessWidget {
  const _CoursesHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        const Text(
          'Mis Cursos',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
        const Spacer(),
        Text(
          '$count ${count == 1 ? 'asignatura activa' : 'asignaturas activas'}',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.name,
    required this.initials,
    required this.program,
    required this.onCalendar,
  });

  final String name;
  final String initials;
  final String program;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.navy,
                shape: BoxShape.circle,
              ),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¡Hola, $name!',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                program,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: AppColors.chipBackground,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onCalendar,
            child: const Padding(
              padding: EdgeInsets.all(11),
              child: Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: AppColors.navy,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RealSummaryCard extends StatelessWidget {
  const _RealSummaryCard({required this.overview, required this.onScan});

  final StudentOverview overview;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final att = overview.attendance;
    final risk = overview.riskCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE4F6F0), Colors.white],
        ),
        borderRadius: BorderRadius.all(Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x140B3A5E),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: risk == 0 ? _mint : _amberBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  risk == 0 ? Icons.check_circle : Icons.warning_amber_rounded,
                  size: 14,
                  color: risk == 0 ? _teal : _amberFg,
                ),
                const SizedBox(width: 6),
                Text(
                  risk == 0
                      ? 'Al día en todos tus cursos'
                      : '$risk ${risk == 1 ? 'curso' : 'cursos'} con alerta',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: risk == 0 ? AppColors.navy : _amberFg,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                att == null ? '—' : '${att.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'asistencia global',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            overview.held == 0
                ? 'Aún no hay clases dictadas en tus cursos'
                : '${overview.present} de ${overview.held} clases asistidas',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: AppColors.gradient,
                borderRadius: BorderRadius.all(Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x330B3A5E),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  onTap: onScan,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Escanear QR de asistencia',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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

({
  Color accent,
  Color pillBg,
  Color pillFg,
  Color value,
  IconData icon,
  String label,
})
_styleOf(CourseAttendance a) {
  if (a.held == 0) {
    return (
      accent: const Color(0xFF2F6AA8),
      pillBg: _blueBg,
      pillFg: AppColors.navy,
      value: AppColors.textMuted,
      icon: Icons.hourglass_empty,
      label: 'SIN CLASES AÚN',
    );
  }
  switch (a.status) {
    case CourseStatus.safe:
      return (
        accent: AppColors.green,
        pillBg: const Color(0xFFD7F5EA),
        pillFg: AppColors.green,
        value: AppColors.green,
        icon: Icons.check_circle,
        label: 'SEGURO',
      );
    case CourseStatus.warning:
      return (
        accent: const Color(0xFFF5A623),
        pillBg: const Color(0xFFFEF3C7),
        pillFg: _amberFg,
        value: _amberFg,
        icon: Icons.warning_amber_rounded,
        label: 'ALERTA DE RIESGO',
      );
    case CourseStatus.risk:
      return (
        accent: _red,
        pillBg: const Color(0xFFFEE2E2),
        pillFg: _red,
        value: _red,
        icon: Icons.cancel,
        label: 'EN RIESGO DE REPROBAR',
      );
  }
}

class _RealCourseCard extends StatelessWidget {
  const _RealCourseCard({required this.item, required this.onTap});

  final CourseAttendance item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = item;
    final s = _styleOf(a);
    final pct = a.percent;

    final details = <String>[
      if (a.course.code.isNotEmpty) a.course.code,
      if (a.held > 0)
        '${a.absent} ${a.absent == 1 ? 'falta' : 'faltas'}${a.course.limited ? '' : ' (máx. ${a.course.maxAbsences})'}',
      if (a.inProcess > 0) '${a.inProcess} en proceso',
    ];

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Color(0x100B3A5E),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 5, color: s.accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: s.pillBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(s.icon, size: 13, color: s.pillFg),
                                      const SizedBox(width: 4),
                                      Text(
                                        s.label,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.4,
                                          color: s.pillFg,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  a.course.name,
                                  style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.navy,
                                    height: 1.25,
                                  ),
                                ),
                                if (details.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    details.join(' • '),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            pct == null ? '—' : '${pct.round()}%',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: s.value,
                            ),
                          ),
                        ],
                      ),
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
}

class _CoursePickerSheet extends StatelessWidget {
  const _CoursePickerSheet({required this.courses});

  final List<EnrolledCourse> courses;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6E0F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '¿En qué curso registras tu asistencia?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in courses)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: _blueBg,
                        child: Icon(
                          Icons.qr_code_scanner,
                          color: AppColors.navy,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        c.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                      subtitle: c.code.isEmpty ? null : Text(c.code),
                      onTap: () => Navigator.of(context).pop(c.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
