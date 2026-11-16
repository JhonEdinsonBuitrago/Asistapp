import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/name_utils.dart';
import '../../data/student_mock_data.dart';

const _mint = Color(0xFFCFF3E8);
const _red = Color(0xFFD92D20);
const _amber = Color(0xFFF5B942);
const _teal = Color(0xFF066A5C);
const _soft = Color(0xFFEFF3FC);
const _chipBlue = Color(0xFFE3EBFA);

BoxDecoration _cardDecoration() => const BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(24)),
  boxShadow: [
    BoxShadow(color: Color(0x140B3A5E), blurRadius: 18, offset: Offset(0, 6)),
  ],
);

// ---------------------------------------------------------------------------
// Tarjeta del curso (cabecera)
// ---------------------------------------------------------------------------
class CourseHeaderCard extends StatelessWidget {
  const CourseHeaderCard({
    super.key,
    required this.detail,
    required this.onMail,
  });

  final CourseDetail detail;
  final VoidCallback onMail;

  @override
  Widget build(BuildContext context) {
    // Quita el título ("Ing.", "Dra.", "Mg.") para calcular las iniciales.
    final cleanName = detail.teacherName.replaceFirst(
      RegExp(r'^[A-Za-zñÑ]{2,4}\.\s+'),
      '',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  detail.level.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              _StatusPill(status: detail.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detail.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.navy,
                  child: Text(
                    initialsOf(cleanName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.teacherName,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail.teacherRole,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: _chipBlue,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onMail,
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.mail_outline,
                        size: 20,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _InfoLine(
                  icon: Icons.calendar_month_outlined,
                  text: detail.schedule,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoLine(
                  icon: Icons.meeting_room_outlined,
                  text: detail.room,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.green),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final CourseStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon, label) = switch (status) {
      CourseStatus.safe => (
        const Color(0xFFD7F5EA),
        AppColors.green,
        Icons.check_circle_outline,
        'Seguro',
      ),
      CourseStatus.warning => (
        const Color(0xFFFEE2E2),
        _red,
        Icons.warning_amber_rounded,
        'Riesgo',
      ),
      CourseStatus.risk => (
        const Color(0xFFFEE2E2),
        _red,
        Icons.cancel_outlined,
        'Crítico',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Balance de asistencia
// ---------------------------------------------------------------------------
class AttendanceBalanceCard extends StatelessWidget {
  const AttendanceBalanceCard({super.key, required this.detail});

  final CourseDetail detail;

  @override
  Widget build(BuildContext context) {
    final d = detail;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
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
                    const Text(
                      'Balance de Asistencia',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Período Académico ${d.period}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: const BoxDecoration(
                  color: _chipBlue,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                child: Text(
                  'Corte ${d.cutoff}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(child: AttendanceRing(detail: d)),
          const SizedBox(height: 18),
          _LimitBox(detail: d),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LegendDot(color: _teal, text: '${d.attended} Cumplidas'),
              _LegendDot(
                color: _amber,
                text: '${d.absences} Faltas acumuladas',
              ),
            ],
          ),
          const SizedBox(height: 14),
          // IntrinsicHeight: sin esto, "stretch" dentro de una lista con altura
          // infinita provoca un error de layout y la pantalla queda en blanco.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StatBox(
                    bg: _soft,
                    border: const Color(0xFFDDE6F5),
                    label: 'Programadas',
                    labelColor: AppColors.textMuted,
                    value: '${d.scheduled}',
                    valueColor: AppColors.navy,
                    caption: 'Total ciclo',
                    captionColor: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatBox(
                    bg: const Color(0xFFB7F2E0),
                    border: const Color(0xFF8FE3CA),
                    icon: Icons.check_circle_outline,
                    label: 'ASISTIDAS',
                    labelColor: _teal,
                    value: '${d.attended}',
                    valueColor: _teal,
                    caption: 'Verificadas',
                    captionColor: _teal,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatBox(
                    bg: const Color(0xFFFDECEC),
                    border: const Color(0xFFF7C9C9),
                    icon: Icons.cancel_outlined,
                    label: 'INASIST.',
                    labelColor: _red,
                    value: '${d.absences}',
                    valueColor: _red,
                    caption: '${d.unjustified} sin justif.',
                    captionColor: _red,
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

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.bg,
    required this.border,
    required this.label,
    required this.labelColor,
    required this.value,
    required this.valueColor,
    required this.caption,
    required this.captionColor,
    this.icon,
  });

  final Color bg;
  final Color border;
  final String label;
  final Color labelColor;
  final String value;
  final Color valueColor;
  final String caption;
  final Color captionColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: labelColor),
                const SizedBox(width: 3),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: labelColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
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
          Text(caption, style: TextStyle(fontSize: 11.5, color: captionColor)),
        ],
      ),
    );
  }
}

class _LimitBox extends StatelessWidget {
  const _LimitBox({required this.detail});
  final CourseDetail detail;

  @override
  Widget build(BuildContext context) {
    final r = detail.remainingAbsences;
    const strong = TextStyle(fontWeight: FontWeight.w800, color: _red);

    final List<InlineSpan> tail;
    if (r > 1) {
      tail = [
        TextSpan(
          text:
              'Aún puedes faltar a $r clases más antes de perder derecho a examen.',
        ),
      ];
    } else if (r == 1) {
      tail = const [
        TextSpan(text: 'Solo te queda 1 falta permitida', style: strong),
        TextSpan(text: ' antes de perder derecho a examen.'),
      ];
    } else if (r == 0) {
      tail = const [
        TextSpan(text: 'Ya usaste todas tus faltas permitidas.', style: strong),
        TextSpan(text: ' Una inasistencia más y perderás el derecho a examen.'),
      ];
    } else {
      tail = [
        const TextSpan(
          text: 'Superaste el límite reglamentario',
          style: strong,
        ),
        TextSpan(
          text:
              ' por ${-r} ${-r == 1 ? 'falta' : 'faltas'}. Consulta con tu docente.',
        ),
      ];
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            r > 1 ? Icons.info_outline : Icons.warning_amber_rounded,
            size: 20,
            color: r > 1 ? AppColors.green : const Color(0xFFE8A317),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Límite reglamentario: ${detail.limitPercent}%',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: Color(0xFF3D4B5C),
                    ),
                    children: [
                      TextSpan(
                        text:
                            'Máximo permitido: ${detail.maxAbsences} inasistencias. ',
                      ),
                      ...tail,
                    ],
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
// Anillo de asistencia
// ---------------------------------------------------------------------------
class AttendanceRing extends StatelessWidget {
  const AttendanceRing({super.key, required this.detail, this.size = 140});

  final CourseDetail detail;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          attended: detail.attended,
          absences: detail.absences,
          scheduled: detail.scheduled,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${detail.percentage}%',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'ASISTIDO',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.attended,
    required this.absences,
    required this.scheduled,
  });

  final int attended;
  final int absences;
  final int scheduled;

  static const _stroke = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    final radius = rect.width / 2;

    // Fondo del anillo.
    canvas.drawCircle(
      rect.center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = const Color(0xFFE6ECF7),
    );
    if (scheduled <= 0) return;

    // Asistencia perfecta: anillo completo.
    if (absences == 0 && attended >= scheduled) {
      canvas.drawCircle(
        rect.center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..color = _teal,
      );
      return;
    }

    const full = 2 * math.pi;
    final a = (absences / scheduled).clamp(0.0, 1.0).toDouble() * full;
    final t = (attended / scheduled).clamp(0.0, 1.0).toDouble() * full;

    Paint paintFor(Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = c;

    // Espacio de las tapas redondeadas más una pequeña separación visible.
    final shave = _stroke / 2 / radius + 0.05;

    void segment(double start, double sweep, Color color) {
      if (sweep <= 0) return;
      final s = sweep - 2 * shave;
      canvas.drawArc(
        rect,
        start + shave,
        s > 0.001 ? s : 0.001,
        false,
        paintFor(color),
      );
    }

    // Las faltas quedan centradas arriba; la asistencia ocupa el resto.
    segment(-math.pi / 2 - a / 2, a, _amber);
    segment(-math.pi / 2 + a / 2, t, _teal);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.attended != attended ||
      old.absences != absences ||
      old.scheduled != scheduled;
}

// ---------------------------------------------------------------------------
// Clase en progreso
// ---------------------------------------------------------------------------
class ActiveClassCard extends StatelessWidget {
  const ActiveClassCard({
    super.key,
    required this.active,
    required this.classNumber,
    required this.secondsLeft,
    required this.detectedRoom,
    required this.nextSession,
    required this.onRegister,
    required this.onToggleSimulation,
  });

  final bool active;
  final int classNumber;
  final int secondsLeft;
  final String detectedRoom;
  final String nextSession;
  final VoidCallback onRegister;
  final VoidCallback onToggleSimulation;

  String get _time {
    final m = (secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: active ? _teal : AppColors.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  active
                      ? 'Clase #$classNumber en progreso'
                      : 'Sin clase en progreso',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
              if (active)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: _red),
                    const SizedBox(width: 4),
                    Text(
                      '$_time min restantes',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _red,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (active) ...[
            const Text(
              'Valida tu asistencia mediante baliza Bluetooth del aula o escaneo de código QR dinámico.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Rango detectado: $detectedRoom • Bluetooth activo',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: _teal,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33066A5C),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    onTap: onRegister,
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
                          'Registrar Asistencia Ahora',
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
          ] else ...[
            const Icon(
              Icons.event_busy_outlined,
              size: 38,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 8),
            const Text(
              'No hay una clase en progreso. Podrás registrar tu asistencia cuando el docente inicie la sesión.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE6ECF7)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 15,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Próxima sesión: $nextSession',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onToggleSimulation,
                child: Text(
                  active ? 'Simular sin sesión' : 'Simular sesión activa',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                    decoration: TextDecoration.underline,
                  ),
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
// Opciones (Historial / Justificar)
// ---------------------------------------------------------------------------
class DetailOptionTile extends StatelessWidget {
  const DetailOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.chip,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? chip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x100B3A5E),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: _chipBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 22, color: AppColors.navy),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
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
                if (chip != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: const BoxDecoration(
                      color: _chipBlue,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    child: Text(
                      chip!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  )
                else
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Próximas sesiones
// ---------------------------------------------------------------------------
class UpcomingSessionTile extends StatelessWidget {
  const UpcomingSessionTile({super.key, required this.session});

  final UpcomingSession session;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (session.type) {
      SessionType.theory => (_chipBlue, AppColors.navy, 'Teoría'),
      SessionType.practice => (_mint, AppColors.green, 'Práctica'),
      SessionType.exam => (
        const Color(0xFFFFE8CC),
        const Color(0xFFB45309),
        'Examen',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: Color(0x100B3A5E),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  session.month,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  session.day,
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${session.time} • ${session.place}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
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
          ),
        ],
      ),
    );
  }
}
