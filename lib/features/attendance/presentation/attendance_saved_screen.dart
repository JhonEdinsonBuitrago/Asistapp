import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/name_utils.dart';
import '../data/attendance_models.dart';
import '../data/attendance_repository.dart';
import 'attendance_success_view.dart';
import '../../student/data/student_courses_data.dart';

const _mint = Color(0xFFD7F5EA);
const _amber = Color(0xFFB45309);
const _amberBg = Color(0xFFFFE8CC);
const _orange = Color(0xFFD9730D);
const _orangeBg = Color(0xFFFFE6CC);
const _red = Color(0xFFD92D20);
const _redBg = Color(0xFFFEE2E2);
const _blueBg = Color(0xFFE3EBFA);
const _soft = Color(0xFFEFF3FC);

const _days = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const _months = [
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

String _longDate(DateTime d) =>
    '${_days[d.weekday - 1]}, ${d.day} de ${_months[d.month - 1]} de ${d.year}';

String _hm(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

enum _Phase { saving, queued, sent, confirmed, review, rejected, failed }

class _PhaseView {
  const _PhaseView({
    required this.icon,
    required this.color,
    required this.bg,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.note,
    this.chip = '',
    this.progress,
    this.offline = false,
  });

  final IconData icon;
  final Color color;
  final Color bg;
  final String title;
  final String subtitle;
  final String status;
  final String chip;
  final String note;
  final double? progress; // null = animación continua
  final bool offline;
}

class AttendanceSavedScreen extends ConsumerStatefulWidget {
  const AttendanceSavedScreen({
    super.key,
    required this.courseId,
    required this.sessionId,
    this.room,
    this.courseName,
  });

  final String courseId;
  final String sessionId;
  final String? room;
  final String? courseName;

  @override
  ConsumerState<AttendanceSavedScreen> createState() =>
      _AttendanceSavedScreenState();
}

class _AttendanceSavedScreenState extends ConsumerState<AttendanceSavedScreen> {
  StreamSubscription<ClaimInfo?>? _sub;
  Timer? _grace;
  ClaimInfo? _claim;
  bool _hadClaim = false;
  bool _graceOver = false;
  bool _retrying = false;

  EnrolledCourse? get _enrolled => ref
      .watch(myEnrolledCoursesProvider)
      .value
      ?.where((c) => c.id == widget.courseId)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    if (widget.sessionId.isEmpty) return;

    _sub = ref
        .read(attendanceRepositoryProvider)
        .watchMyClaim(widget.sessionId)
        .listen((c) {
          if (!mounted) return;
          setState(() {
            _claim = c;
            if (c != null) _hadClaim = true;
          });
        }, onError: (Object _) {});

    // Durante los primeros segundos se muestra "Guardando…" para no asustar a
    // quien sí tiene conexión.
    _grace = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _graceOver = true);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _grace?.cancel();
    super.dispose();
  }

  _Phase get _phase {
    final c = _claim;
    if (c == null) return _hadClaim ? _Phase.failed : _Phase.saving;
    if (c.hasPendingWrites || c.syncedAt == null) {
      return _graceOver ? _Phase.queued : _Phase.saving;
    }
    return switch (c.status) {
      ClaimStatus.pending => _Phase.sent,
      ClaimStatus.validated => _Phase.confirmed,
      ClaimStatus.review => _Phase.review,
      ClaimStatus.rejected => _Phase.rejected,
    };
  }

  _PhaseView _viewFor(_Phase p) {
    final reason = reasonText(_claim?.reason);

    switch (p) {
      case _Phase.saving:
        return const _PhaseView(
          icon: Icons.cloud_upload_outlined,
          color: AppColors.navy,
          bg: _blueBg,
          title: 'Guardando tu asistencia…',
          subtitle: 'Un momento, estamos registrando tu asistencia.',
          status: 'Guardando',
          note: 'Si no hay conexión, se guardará en tu teléfono y se enviará después.',
        );
      case _Phase.queued:
        return const _PhaseView(
          icon: Icons.cloud_sync_outlined,
          color: _orange,
          bg: _orangeBg,
          title: 'Asistencia guardada, se sincronizará cuando tengas conexión',
          subtitle: 'No te preocupes: el registro quedó guardado con el código dinámico del QR y la hora de tu dispositivo. No necesitas volver a escanear.',
          status: 'Pendiente de sincronizar',
          chip: '1 registro en cola',
          note: 'Se enviará automáticamente cuando el teléfono recupere Wi-Fi o datos móviles.',
          offline: true,
        );
      case _Phase.sent:
        return const _PhaseView(
          icon: Icons.cloud_done_outlined,
          color: AppColors.navy,
          bg: _blueBg,
          title: 'Asistencia enviada',
          subtitle: 'Tu registro llegó al servidor. El docente lo validará cuando abra la sesión de clase.',
          status: 'Esperando validación',
          chip: 'Enviado',
          note: 'El estado se actualiza aquí mientras esta pantalla esté abierta.',
          progress: 1,
        );
      case _Phase.confirmed:
        return const _PhaseView(
          icon: Icons.check_circle_outline,
          color: AppColors.green,
          bg: _mint,
          title: 'Asistencia confirmada',
          subtitle: 'El docente validó tu registro. ¡Todo listo!',
          status: 'Confirmada',
          chip: 'Confirmada',
          note: 'Ya puedes volver al curso.',
          progress: 1,
        );
      case _Phase.review:
        return _PhaseView(
          icon: Icons.rate_review_outlined,
          color: _amber,
          bg: _amberBg,
          title: 'Tu registro está en revisión',
          subtitle: reason.isEmpty
              ? 'El docente revisará tu registro.'
              : '$reason. El docente decidirá si lo confirma.',
          status: 'En revisión',
          chip: 'En revisión',
          note: 'No necesitas hacer nada más. Si es necesario, habla con tu docente.',
          progress: 1,
        );
      case _Phase.rejected:
        return _PhaseView(
          icon: Icons.error_outline,
          color: _red,
          bg: _redBg,
          title: 'Registro no validado',
          subtitle: reason.isEmpty
              ? 'El registro no pasó la validación.'
              : '$reason. Si crees que es un error, habla con tu docente.',
          status: 'No validada',
          chip: 'No validada',
          note: 'Tu docente puede revisar el caso manualmente.',
          progress: 1,
        );
      case _Phase.failed:
        return const _PhaseView(
          icon: Icons.error_outline,
          color: _red,
          bg: _redBg,
          title: 'No se pudo registrar',
          subtitle: 'El servidor no aceptó el registro (la sesión no existe o ya pasó el plazo). Habla con tu docente.',
          status: 'No sincronizado',
          chip: 'Error',
          note: 'Puedes volver al curso e intentar de nuevo.',
          progress: 1,
        );
    }
  }

  String get _reference => widget.sessionId;

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/student/course/${widget.courseId}');
    }
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await ref
          .read(attendanceRepositoryProvider)
          .retrySync()
          .timeout(const Duration(seconds: 8));
      if (mounted) _snack('Intentando enviar tu registro…');
    } catch (_) {
      if (mounted) {
        _snack(
          'No se pudo reiniciar la conexión. Se intentará de nuevo automáticamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  void _showDetails() {
    final c = _claim;
    if (c == null) return;
    final scanned = DateTime.fromMillisecondsSinceEpoch(c.scannedAt);

    final rows = <(String, String)>[
      ('Método', c.method == 'qr' ? 'Escaneo de QR' : 'Código manual'),
      ('Hora del dispositivo', '${_hm(scanned)} • ${_longDate(scanned)}'),
      (
        'Diferencia con el reloj del servidor',
        c.offsetKnown
            ? '${(c.clockOffsetMs / 1000).toStringAsFixed(1)} s'
            : 'No medida (sin conexión previa)',
      ),
      (
        'Estado de envío',
        (c.hasPendingWrites || c.syncedAt == null)
            ? 'Pendiente en este dispositivo'
            : 'Recibido por el servidor',
      ),
      ('Sesión', widget.sessionId),
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Detalle del registro',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.$1,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        r.$2,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
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
        ],
      ),
    );
  }

  // ------------------------------ Interfaz ------------------------------

  @override
  Widget build(BuildContext context) {
    if (widget.sessionId.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Registro no encontrado')),
      );
    }

    final phase = _phase;

    // Registro confirmado: se muestra la pantalla de éxito.
    if (phase == _Phase.confirmed && _claim != null) {
      return AttendanceSuccessView(
        courseId: widget.courseId,
        courseName: widget.courseName,

        sessionId: widget.sessionId,
        room: widget.room,
        claim: _claim!,
        onBack: _back,
        onDetails: _showDetails,
        courseCode: _enrolled?.code,
        teacherName: _enrolled?.teacherName,
      );
    }

    final v = _viewFor(phase);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _buildTopBar(),
                const SizedBox(height: 14),
                Center(child: _buildHero(v)),
                const SizedBox(height: 20),
                Text(
                  v.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  v.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 18),
                _buildCard(v),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _back,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Volver al curso'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    minimumSize: const Size.fromHeight(54),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                if (phase == _Phase.queued) ...[
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _retrying ? null : _retry,
                    icon: _retrying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Reintentar sincronización ahora'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _blueBg,
                      foregroundColor: AppColors.navy,
                      minimumSize: const Size.fromHeight(54),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          onPressed: _back,
          icon: const Icon(Icons.close, color: AppColors.textMuted),
        ),
        SizedBox(
          width: 36,
          height: 30,
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.school, color: AppColors.navy, size: 26),
          ),
        ),
        const Spacer(),
        Material(
          color: AppColors.chipBackground,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _snack('Perfil (próximamente)'),
            child: const Padding(
              padding: EdgeInsets.all(9),
              child: Icon(
                Icons.person_outline,
                size: 22,
                color: AppColors.navy,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHero(_PhaseView v) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: v.bg,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 6),
            boxShadow: [
              BoxShadow(
                color: v.color.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(v.icon, size: 46, color: v.color),
        ),
        if (v.offline)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE6ECF7)),
              ),
              child: const Icon(
                Icons.wifi_off,
                size: 16,
                color: AppColors.navy,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCard(_PhaseView v) {
    final c = _claim;
    final course = _enrolled;
    final name = course?.name ?? widget.courseName ?? 'Clase';
    final code = course?.code ?? '';
    final teacher = (course?.teacherName ?? '').trim();
    final scanned = c == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(c.scannedAt);
    final room = widget.room;

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x140B3A5E),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: _soft,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 20, color: AppColors.navy),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      v.status,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  if (v.chip.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: v.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        v.chip,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: v.color,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: v.progress,
              minHeight: 4,
              color: v.color,
              backgroundColor: const Color(0xFFE6ECF7),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
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
                              'VALIDACIÓN PRESENCIAL',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: AppColors.green,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                                height: 1.2,
                              ),
                            ),
                            if (code.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Código: $code',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Material(
                        color: _blueBg,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _showDetails,
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(
                              Icons.terminal,
                              size: 22,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (teacher.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: _soft,
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: _blueBg,
                            child: Text(
                              initialsOf(teacher),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Docente a cargo',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                Text(
                                  'Prof. $teacher',
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (scanned != null) ...[
                    const SizedBox(height: 14),
                    _InfoRow(
                      icon: Icons.access_time,
                      label: 'Hora del registro local',
                      value: '${_hm(scanned)} • ${_longDate(scanned)}',
                    ),
                  ],
                  if (room != null && room.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _InfoRow(
                      icon: Icons.meeting_room_outlined,
                      label: 'Aula de la clase',
                      value: room,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: _mint,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: AppColors.green,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            v.note,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: Color(0xFF0B5C47),
                            ),
                          ),
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
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 14, color: AppColors.textMuted),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'Guardado en el almacenamiento local de este dispositivo',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'ID de la sesión: $_reference',
          style: const TextStyle(fontSize: 11, color: Color(0xFF8A97A6)),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(color: _soft, shape: BoxShape.circle),
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
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
