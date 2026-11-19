import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/services/clock_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../data/attendance_models.dart';
import '../data/attendance_repository.dart';

const _mint = Color(0xFF5EEAD4);
const _navyDark = Color(0xFF0A2540);

class ScanQrScreen extends ConsumerStatefulWidget {
  const ScanQrScreen({super.key, required this.courseId});

  final String courseId;

  @override
  ConsumerState<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends ConsumerState<ScanQrScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _scanner = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  late final AnimationController _line;
  StreamSubscription<SessionInfo?>? _sessionSub;
  StreamSubscription<ClaimInfo?>? _claimSub;
  Timer? _ticker;

  SessionInfo? _session;
  ClaimInfo? _claim;
  String? _claimSessionId;
  bool _loading = true;
  bool _processing = false;
  bool _torch = false;
  DateTime _lastWarn = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _active =>
      _session != null && _session!.endsAt.isAfter(DateTime.now());

  /// Segundos para el próximo cambio de código (se calcula localmente).
  int? get _secondsToRefresh {
    final s = _session;
    if (s == null) return null;
    final stepMs = s.stepSeconds * 1000;
    final now = ref.read(clockServiceProvider).nowMs();
    return ((stepMs - now % stepMs) / 1000).ceil();
  }

  @override
  void initState() {
    super.initState();
    _line = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // Mide la diferencia con el reloj del servidor (si hay conexión).
    unawaited(ref.read(clockServiceProvider).sync());

    _sessionSub = ref
        .read(attendanceRepositoryProvider)
        .watchOpenSession(widget.courseId)
        .listen(
          (s) {
            if (!mounted) return;
            if (s != null) _listenClaim(s.id);
            setState(() {
              _session = s;
              _loading = false;
            });
          },
          onError: (Object _) {
            if (mounted) setState(() => _loading = false);
          },
        );

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _claimSub?.cancel();
    _ticker?.cancel();
    _line.dispose();
    _scanner.dispose();
    super.dispose();
  }

  void _listenClaim(String sessionId) {
    if (_claimSessionId == sessionId) return;
    _claimSub?.cancel();
    _claimSessionId = sessionId;
    _claimSub = ref
        .read(attendanceRepositoryProvider)
        .watchMyClaim(sessionId)
        .listen((c) {
          if (mounted) setState(() => _claim = c);
        }, onError: (Object _) {});
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _warn(String text) {
    final now = DateTime.now();
    if (now.difference(_lastWarn) < const Duration(seconds: 3)) return;
    _lastWarn = now;
    _snack(text);
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/student');
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _scanner.toggleTorch();
      if (mounted) setState(() => _torch = !_torch);
    } catch (_) {
      if (mounted) _snack('Este dispositivo no tiene linterna disponible.');
    }
  }

  // ------------------------------ Registro ------------------------------

  void _onDetect(BarcodeCapture capture) {
    if (_processing || _claim != null) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (raw == null) return;

    final parsed = parseQrPayload(raw);
    if (parsed == null) {
      _warn('Este código QR no pertenece a AsistApp.');
      return;
    }
    // Si ya se conoce la sesión de este curso, el QR debe ser de ella.
    final s = _session;
    if (s != null && parsed.sessionId != s.id) {
      _warn('Este código corresponde a otra clase.');
      return;
    }
    // Sin datos de la sesión (p. ej. sin conexión) también se registra:
    // la validación se hace después.
    _submit(
      sessionId: parsed.sessionId,
      method: 'qr',
      code: parsed.code,
      qrTimestamp: parsed.timestamp,
    );
  }

  Future<void> _enterPin() async {
    if (_claim != null) {
      _snack('Ya registraste tu asistencia en esta clase.');
      return;
    }
    final s = _session;
    if (s == null || !_active) {
      _snack(
        'Para escribir el código necesito conocer la clase. Escanea el QR o conéctate una vez.',
      );
      return;
    }
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PinSheet(),
    );
    if (code != null && mounted) {
      _submit(sessionId: s.id, method: 'pin', code: code);
    }
  }

  Future<void> _submit({
    required String sessionId,
    required String method,
    required String code,
    int? qrTimestamp,
  }) async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      await ref
          .read(attendanceRepositoryProvider)
          .saveClaim(
            sessionId: sessionId,
            method: method,
            code: code,
            qrTimestamp: qrTimestamp,
          );
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      final room = _session?.room ?? '';
      final name = _session?.courseName ?? '';
      context.pushReplacement(
        Uri(
          path: '/student/course/${widget.courseId}/saved',
          queryParameters: {
            's': sessionId,
            if (room.isNotEmpty) 'room': room,
            if (name.isNotEmpty) 'name': name,
          },
        ).toString(),
      );
    } on AlreadyRegisteredException {
      if (!mounted) return;
      _snack('Ya registraste tu asistencia en esta clase.');
      _close();
    } catch (_) {
      if (mounted) _snack('No se pudo guardar el registro. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // ------------------------------ Interfaz ------------------------------

  @override
  Widget build(BuildContext context) {
    final active = _active;

    return Scaffold(
      backgroundColor: _navyDark,
      body: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          final side = math.min(math.min(w * 0.64, h * 0.32), 270.0);
          final frame = Rect.fromCenter(
            center: Offset(w / 2, h * 0.43),
            width: side,
            height: side,
          );

          return Stack(
            children: [
              Positioned.fill(child: _buildCamera()),
              Positioned.fill(
                child: CustomPaint(painter: _OverlayPainter(frame)),
              ),
              Positioned.fromRect(
                rect: frame,
                child: _FrameView(line: _line),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopBar(),
                      _buildSessionChip(active),
                      Center(child: _buildInfoPill(active)),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                top: frame.bottom + 16,
                child: _buildHint(active),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 12),
                  child: _buildBottomCard(active),
                ),
              ),
              if (_processing)
                const Positioned.fill(
                  child: AbsorbPointer(
                    child: ColoredBox(
                      color: Colors.black54,
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCamera() {
    return MobileScanner(
      controller: _scanner,
      onDetect: _onDetect,
      // El tercer parámetro es opcional para que compile en distintas versiones.
      errorBuilder:
          (
            BuildContext context,
            MobileScannerException error, [
            Widget? child,
          ]) {
            return const _CameraUnavailable();
          },
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: _close,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Expanded(
            child: Text(
              'Escanear QR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Linterna',
            onPressed: _toggleTorch,
            icon: Icon(
              _torch ? Icons.flash_on : Icons.flash_off,
              color: _torch ? _mint : Colors.white,
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.navy,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => _snack('Perfil (próximamente)'),
              icon: const Icon(Icons.person, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionChip(bool active) {
    final title = _session?.courseName ?? 'Escáner de asistencia';
    final subtitle = _loading
        ? 'Buscando la sesión…'
        : (active
              ? 'Sesión Activa • ${_session!.room}'
              : 'Sin datos de la sesión');
    final secs = _secondsToRefresh;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: active ? _mint : Colors.white38,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
              ],
            ),
          ),
          if (active && secs != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _mint.withValues(alpha: 0.7)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: _mint),
                  const SizedBox(width: 5),
                  Text(
                    '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoPill(bool active) {
    final text = active
        ? 'Código dinámico • rota cada ${_session!.stepSeconds}s'
        : 'El registro se guarda y se envía cuando haya conexión';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sensors, size: 15, color: active ? _mint : Colors.white54),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHint(bool active) {
    final String title;
    final String subtitle;
    if (_claim != null) {
      title = 'Ya registraste tu asistencia';
      subtitle = _badge(active).subtitle;
    } else if (active) {
      title = 'Apunta al código QR dinámico';
      subtitle =
          'Actualizado cada ${_session!.stepSeconds}s por el proyector del aula para verificar tu asistencia.';
    } else {
      title = 'Apunta al código QR dinámico';
      subtitle = 'Si el QR es válido, tu registro se guardará y se enviará cuando haya conexión.';
    }

    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  /// Estado que se muestra en la tarjeta inferior.
  ({String subtitle, String chip, Color bg, Color fg}) _badge(bool active) {
    const green = AppColors.green;
    const greenBg = Color(0xFFD7F5EA);
    const amber = Color(0xFFB45309);
    const amberBg = Color(0xFFFFE8CC);
    const blue = AppColors.navy;
    const blueBg = Color(0xFFE3EBFA);
    const red = Color(0xFFD92D20);
    const redBg = Color(0xFFFEE2E2);

    final c = _claim;
    if (c == null) {
      return (
        subtitle: 'Código dinámico • Token seguro',
        chip: active ? 'Listo' : 'En espera',
        bg: active ? greenBg : blueBg,
        fg: active ? green : AppColors.textMuted,
      );
    }
    if (c.hasPendingWrites || c.syncedAt == null) {
      return (
        subtitle: 'Guardado en este dispositivo • se enviará con conexión',
        chip: 'Guardado',
        bg: amberBg,
        fg: amber,
      );
    }
    return switch (c.status) {
      ClaimStatus.pending => (
        subtitle: 'Enviado • esperando la validación del docente',
        chip: 'En validación',
        bg: blueBg,
        fg: blue,
      ),
      ClaimStatus.validated => (
        subtitle: 'Asistencia confirmada',
        chip: 'Confirmada',
        bg: greenBg,
        fg: green,
      ),
      ClaimStatus.review => (
        subtitle: 'El docente revisará tu registro',
        chip: 'En revisión',
        bg: amberBg,
        fg: amber,
      ),
      ClaimStatus.rejected => (
        subtitle: 'No validada: ${reasonText(c.reason)}',
        chip: 'No validada',
        bg: redBg,
        fg: red,
      ),
    };
  }

  Widget _buildBottomCard(bool active) {
    final b = _badge(active);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFD7F5EA),
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  size: 19,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Validación de Presencia',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      b.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: b.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  b.chip,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: b.fg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: Material(
              color: const Color(0xFFE3EBFA),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _enterPin,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.dialpad, size: 19, color: AppColors.navy),
                    SizedBox(width: 10),
                    Text(
                      'Ingresar código de 6 dígitos',
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
          const SizedBox(height: 4),
          TextButton(
            onPressed: _close,
            child: const Text(
              'Cancelar y volver al horario',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Entrada manual del código
// ---------------------------------------------------------------------------
class _PinSheet extends StatefulWidget {
  const _PinSheet();

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final complete = _controller.text.length == 6;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
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
            const SizedBox(height: 16),
            const Text(
              'Ingresa el código de 6 dígitos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Es el número que muestra el proyector del aula junto al QR.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 12,
                color: AppColors.navy,
              ),
              decoration: const InputDecoration(
                hintText: '······',
                filled: true,
                fillColor: AppColors.chipBackground,
                contentPadding: EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (v) {
                if (v.length == 6) Navigator.of(context).pop(v);
              },
            ),
            const SizedBox(height: 16),
            Opacity(
              opacity: complete ? 1 : 0.5,
              child: GradientButton(
                label: 'Guardar asistencia',
                icon: Icons.check,
                onPressed: complete
                    ? () => Navigator.of(context).pop(_controller.text)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Elementos gráficos del visor
// ---------------------------------------------------------------------------
class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF12365A),
      child: Align(
        alignment: Alignment(0, -0.14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_outlined, size: 40, color: Colors.white70),
            SizedBox(height: 6),
            Text(
              'Cámara no disponible',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter(this.hole);

  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()
        ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(22))),
    );
    canvas.drawPath(path, Paint()..color = const Color(0xCC0A2540));
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) => old.hole != hole;
}

class _FrameView extends StatelessWidget {
  const _FrameView({required this.line});

  final Animation<double> line;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: _CornersPainter())),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: line,
            builder: (context, _) => Align(
              alignment: Alignment(0, line.value * 1.8 - 0.9),
              child: Container(
                height: 2.5,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0x005EEAD4), _mint, Color(0x005EEAD4)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _mint.withValues(alpha: 0.6),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CornersPainter extends CustomPainter {
  const _CornersPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _mint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const len = 30.0;
    const r = 14.0;
    final w = size.width;
    final h = size.height;

    canvas.drawPath(
      Path()
        ..moveTo(0, len)
        ..lineTo(0, r)
        ..quadraticBezierTo(0, 0, r, 0)
        ..lineTo(len, 0),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w - len, 0)
        ..lineTo(w - r, 0)
        ..quadraticBezierTo(w, 0, w, r)
        ..lineTo(w, len),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, h - len)
        ..lineTo(0, h - r)
        ..quadraticBezierTo(0, h, r, h)
        ..lineTo(len, h),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w - len, h)
        ..lineTo(w - r, h)
        ..quadraticBezierTo(w, h, w, h - r)
        ..lineTo(w, h - len),
      p,
    );

    final m = Paint()
      ..color = _mint.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    void plus(Offset c) {
      canvas.drawLine(c.translate(-4, 0), c.translate(4, 0), m);
      canvas.drawLine(c.translate(0, -4), c.translate(0, 4), m);
    }

    const inset = 22.0;
    plus(const Offset(inset, inset));
    plus(Offset(w - inset, inset));
    plus(Offset(inset, h - inset));
    plus(Offset(w - inset, h - inset));
  }

  @override
  bool shouldRepaint(covariant _CornersPainter old) => false;
}
