import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/teacher_mock_data.dart';

const _teal = Color(0xFF066A5C);
const _soft = Color(0xFFEFF3FC);
const _blueBg = Color(0xFFE3EBFA);
const _mintStrong = Color(0xFF86EFD9);
const _navyBtn = Color(0xFF0A2F52);

const _cardShadow = [
  BoxShadow(color: Color(0x120B3A5E), blurRadius: 16, offset: Offset(0, 6)),
];

enum CourseAction { takeAttendance, roster, review, details }

// ---------------------------------------------------------------------------
// Tarjeta de estadística
// ---------------------------------------------------------------------------
class TeacherStatCard extends StatelessWidget {
  const TeacherStatCard({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(22)),
        boxShadow: _cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 23, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: valueColor,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    height: 1.2,
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

// ---------------------------------------------------------------------------
// Tarjeta de curso
// ---------------------------------------------------------------------------
({
  Color accent,
  Color pillBg,
  Color pillFg,
  IconData icon,
  String label,
  Color labelColor,
})
_toneOf(TeacherCourse c) => switch (c.tone) {
  CourseTone.excellent => (
    accent: _teal,
    pillBg: _mintStrong,
    pillFg: const Color(0xFF065F52),
    icon: Icons.verified_outlined,
    label: 'Excelente',
    labelColor: _teal,
  ),
  CourseTone.normal => (
    accent: const Color(0xFF2F6AA8),
    pillBg: _blueBg,
    pillFg: AppColors.navy,
    icon: Icons.check,
    label: 'Normal',
    labelColor: AppColors.navy,
  ),
  CourseTone.risk => (
    accent: const Color(0xFFF5A623),
    pillBg: const Color(0xFFFFE0B8),
    pillFg: const Color(0xFFB45309),
    icon: Icons.warning_amber_rounded,
    label: '${c.atRisk} en riesgo',
    labelColor: const Color(0xFF7A4A12),
  ),
  CourseTone.optimal => (
    accent: const Color(0xFF0B6B54),
    pillBg: _mintStrong,
    pillFg: const Color(0xFF065F52),
    icon: Icons.star_outline,
    label: 'Óptimo',
    labelColor: _teal,
  ),
};

class TeacherCourseCard extends StatelessWidget {
  const TeacherCourseCard({
    super.key,
    required this.course,
    required this.now,
    required this.onTap,
    required this.onAction,
  });

  final TeacherCourse course;
  final DateTime now;
  final VoidCallback onTap;
  final ValueChanged<CourseAction> onAction;

  @override
  Widget build(BuildContext context) {
    final c = course;
    final t = _toneOf(c);
    final today = c.hasClassOn(now.weekday);
    final pending = c.pendingJustifications;

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(22)),
        boxShadow: _cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(19, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(c, t),
                      const SizedBox(height: 10),
                      _schedule(c),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: c.attendance / 100,
                          minHeight: 7,
                          color: t.accent,
                          backgroundColor: const Color(0xFFE1E9F6),
                        ),
                      ),
                      if (pending > 0) ...[
                        const SizedBox(height: 12),
                        _pendingBanner(pending),
                      ],
                      const SizedBox(height: 12),
                      if (today) ...[
                        _info(c, today),
                        const SizedBox(height: 12),
                        _todayButtons(),
                      ] else
                        Row(
                          children: [
                            Expanded(child: _info(c, today)),
                            if (pending > 0)
                              _softButton(
                                'Ver lista',
                                () => onAction(CourseAction.roster),
                              )
                            else
                              IconButton(
                                tooltip: 'Tomar asistencia',
                                onPressed: () =>
                                    onAction(CourseAction.takeAttendance),
                                icon: const Icon(
                                  Icons.checklist,
                                  color: AppColors.navy,
                                ),
                              ),
                            _menu(),
                          ],
                        ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 5,
                  child: ColoredBox(color: t.accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(
    TeacherCourse c,
    ({
      Color accent,
      Color pillBg,
      Color pillFg,
      IconData icon,
      String label,
      Color labelColor,
    })
    t,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _blueBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      c.code,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sec. ${c.section}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                c.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: t.pillBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(t.icon, size: 15, color: t.pillFg),
                  const SizedBox(width: 4),
                  Text(
                    '${c.attendance}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: t.pillFg,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: t.labelColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _schedule(TeacherCourse c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.schedule, size: 17, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  c.scheduleLabel,
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('•', style: TextStyle(color: Color(0xFFB4BFD0))),
        ),
        Expanded(
          flex: 2,
          child: Row(
            children: [
              const Icon(
                Icons.apartment_outlined,
                size: 17,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  c.room,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pendingBanner(int pending) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE6F5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.health_and_safety_outlined,
            size: 20,
            color: AppColors.navy,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pending == 1
                  ? '1 justificación médica pendiente'
                  : '$pending justificaciones médicas pendientes',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onAction(CourseAction.review),
            child: const Text(
              'Revisar',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Alumnos y, a su lado, el estado de la clase o la próxima sesión.
  Widget _info(TeacherCourse c, bool today) {
    Widget dot() => const Text('•', style: TextStyle(color: Color(0xFFB4BFD0)));

    Widget? extra;
    if (today) {
      extra = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'Clase hoy ${c.startTime12}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: _teal,
            ),
          ),
        ],
      );
    } else if (c.pendingJustifications == 0) {
      extra = c.syncedPercent != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_done_outlined, size: 16, color: _teal),
                const SizedBox(width: 4),
                Text(
                  '${c.syncedPercent}% Sincronizado',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _teal,
                  ),
                ),
              ],
            )
          : Text(
              'Próxima: ${c.nextClassLabel(now)}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.school_outlined, size: 18, color: AppColors.navy),
            const SizedBox(width: 6),
            Text(
              '${c.students}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'alumnos',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
        if (extra != null) ...[dot(), extra],
      ],
    );
  }

  Widget _todayButtons() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => onAction(CourseAction.takeAttendance),
            icon: const Icon(Icons.how_to_reg_outlined, size: 20),
            label: const Text('Tomar asistencia'),
            style: FilledButton.styleFrom(
              backgroundColor: _navyBtn,
              minimumSize: const Size.fromHeight(50),
              textStyle: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: _blueBg,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onAction(CourseAction.roster),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 19,
                    color: AppColors.navy,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Roster',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _softButton(String label, VoidCallback onTap) {
    return Material(
      color: _blueBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
        ),
      ),
    );
  }

  Widget _menu() {
    return PopupMenuButton<CourseAction>(
      tooltip: 'Más opciones',
      icon: const Icon(Icons.more_vert, color: AppColors.navy),
      onSelected: onAction,
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: CourseAction.takeAttendance,
          child: Text('Iniciar sesión de clase (QR)'),
        ),
        PopupMenuItem(
          value: CourseAction.roster,
          child: Text('Ver lista de estudiantes'),
        ),
        PopupMenuItem(
          value: CourseAction.details,
          child: Text('Detalle del curso'),
        ),
      ],
    );
  }
}
