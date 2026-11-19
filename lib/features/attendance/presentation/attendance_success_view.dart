import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/name_utils.dart';
import '../data/attendance_models.dart';

const _teal = Color(0xFF066A5C);
const _mint = Color(0xFFD7F5EA);
const _panel = Color(0xFFE9F0FB);
const _blueBg = Color(0xFFE3EBFA);

const _dayNames = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const _monthNames = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

String _fullDate(DateTime d) =>
    '${_dayNames[d.weekday - 1]}, ${d.day} de ${_monthNames[d.month - 1]} de ${d.year}';

String _hour12(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// Pantalla de "¡Asistencia registrada!": el registro ya fue confirmado.
class AttendanceSuccessView extends StatelessWidget {
  const AttendanceSuccessView({
    super.key,
    required this.courseId,
    required this.sessionId,
    required this.claim,
    required this.onBack,
    required this.onDetails,
    this.courseName,
    this.courseCode,
    this.teacherName,
    this.room,
  });

  final String courseId;
  final String sessionId;
  final ClaimInfo claim;
  final VoidCallback onBack;
  final VoidCallback onDetails;
  final String? courseName;
  final String? courseCode;
  final String? teacherName;
  final String? room;

  /// Si el registro llegó con conexión, la hora del servidor es la confiable.
  DateTime get _when => (claim.timeVerified && claim.syncedAt != null)
      ? claim.syncedAt!
      : DateTime.fromMillisecondsSinceEpoch(
          claim.scannedAt + claim.clockOffsetMs,
        );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.close, color: AppColors.navy),
                    ),
                    SizedBox(
                      width: 36,
                      height: 30,
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.school,
                          color: AppColors.navy,
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Center(child: _hero()),
                const SizedBox(height: 22),
                const Text(
                  '¡Asistencia registrada!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tu presencia en clase fue verificada con el código dinámico de la sesión.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 20),
                _card(context),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Volver al curso'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.navy,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      width: 116,
      height: 116,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _mint.withValues(alpha: 0.7),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.28),
            blurRadius: 40,
            spreadRadius: 6,
          ),
        ],
      ),
      child: Container(
        width: 90,
        height: 90,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: _teal),
        child: const Icon(Icons.check, size: 54, color: Colors.white),
      ),
    );
  }

  Widget _card(BuildContext context) {
    final when = _when;
    final online = claim.timeVerified;
    final sensor = claim.method == 'qr'
        ? 'QR dinámico validado'
        : 'Código manual validado';
    final teacher = (teacherName ?? '').trim();
    final code = (courseCode ?? '').trim();
    final roomName = room;

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A0B3A5E),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 4, color: _teal),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _mint,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              online ? Icons.wifi : Icons.cloud_done_outlined,
                              size: 14,
                              color: AppColors.green,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              online
                                  ? 'En línea y validado'
                                  : 'Validado • escaneado sin conexión',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Material(
                        color: _blueBg,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: onDetails,
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(
                              Icons.laptop_mac,
                              size: 22,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    (courseName ?? '').isEmpty ? 'Clase' : courseName!,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                      height: 1.15,
                    ),
                  ),
                  if (code.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      code,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                    child: Column(
                      children: [
                        if (teacher.isNotEmpty) ...[
                          _DetailRow(
                            icon: Icons.school_outlined,
                            label: 'DOCENTE',
                            value: 'Prof. $teacher',
                          ),
                          const SizedBox(height: 14),
                        ],
                        _DetailRow(
                          icon: Icons.schedule,
                          label: online
                              ? 'FECHA Y HORA EXACTA'
                              : 'FECHA Y HORA (DEL DISPOSITIVO)',
                          value: '${_hour12(when)} • ${_fullDate(when)}',
                        ),
                        if (roomName != null && roomName.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _DetailRow(
                            icon: Icons.near_me_outlined,
                            label: 'AULA Y MÉTODO',
                            value: roomName,
                            extra: '($sensor)',
                          ),
                        ] else ...[
                          const SizedBox(height: 14),
                          _DetailRow(
                            icon: Icons.fact_check_outlined,
                            label: 'MÉTODO',
                            value: sensor,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFE6ECF7)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.fingerprint,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'SESIÓN: $sessionId',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copiar identificador',
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: sessionId),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text('Identificador copiado'),
                                ),
                              );
                          }
                        },
                        icon: const Icon(
                          Icons.copy_outlined,
                          size: 19,
                          color: AppColors.navy,
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
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.extra,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: _blueBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 19, color: AppColors.navy),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                  height: 1.3,
                ),
              ),
              if (extra != null)
                Text(
                  extra!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
