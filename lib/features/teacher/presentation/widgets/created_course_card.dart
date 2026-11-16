import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/course_repository.dart';

const _teal = Color(0xFF066A5C);
const _blueBg = Color(0xFFE3EBFA);
const _amber = Color(0xFFF5A623);
const _amberFg = Color(0xFFB45309);
const _amberBg = Color(0xFFFFE8CC);
const _mint = Color(0xFFD7F5EA);

/// Tarjeta de un curso real creado por el docente.
class CreatedCourseCard extends StatelessWidget {
  const CreatedCourseCard({
    super.key,
    required this.course,
    required this.onActivate,
    required this.onDelete,
    required this.onSoon,
  });

  final CreatedCourse course;
  final VoidCallback onActivate;
  final VoidCallback onDelete;
  final ValueChanged<String> onSoon;

  @override
  Widget build(BuildContext context) {
    final c = course;
    final accent = c.isDraft ? _amber : _teal;

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Color(0x120B3A5E),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(19, 14, 8, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (c.code.isNotEmpty) ...[
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
                      ],
                      Text(
                        c.period,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: c.isDraft ? _amberBg : _mint,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          c.isDraft ? 'Borrador' : 'Activo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: c.isDraft ? _amberFg : _teal,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Más opciones',
                        icon: const Icon(
                          Icons.more_vert,
                          color: AppColors.navy,
                        ),
                        onSelected: (v) {
                          if (v == 'delete') {
                            onDelete();
                          } else {
                            onSoon('Detalle del curso');
                          }
                        },
                        itemBuilder: (_) => [
                          if (c.isDraft)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Eliminar borrador'),
                            )
                          else
                            const PopupMenuItem(
                              value: 'details',
                              child: Text('Detalle del curso'),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
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
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        _info(
                          Icons.event_note_outlined,
                          '${c.totalSessions} sesiones',
                        ),
                        _info(Icons.schedule, '${c.academicHours} h'),
                        _info(Icons.rule, 'Máx. ${c.maxAbsences} faltas'),
                        _info(Icons.sensors, modalityTitle(c.modality)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.school_outlined,
                          size: 18,
                          color: AppColors.navy,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${c.studentCount}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            c.studentCount == 0
                                ? 'alumnos • aún sin matricular'
                                : (c.studentCount == 1
                                      ? 'alumno inscrito'
                                      : 'alumnos inscritos'),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        if (c.isDraft)
                          FilledButton(
                            onPressed: onActivate,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0A2F52),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Activar curso'),
                          )
                        else
                          Material(
                            color: _blueBg,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => onSoon('Matrícula de estudiantes'),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                child: Text(
                                  'Matricular',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
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
              child: ColoredBox(color: accent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
