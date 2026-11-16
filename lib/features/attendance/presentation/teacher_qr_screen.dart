import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../teacher/data/course_repository.dart';
import '../../teacher/data/enrollment_repository.dart';
import '../../teacher/data/teacher_course_detail_data.dart';
import '../data/attendance_models.dart';
import '../data/attendance_repository.dart';
import '../data/claim_validator.dart';
import '../data/local_session_store.dart';
import '../data/totp.dart';

const _navyDark = Color(0xFF0A2540);
const _navyBtn = Color(0xFF0A2F52);
const _teal = Color(0xFF066A5C);
const _mint = Color(0xFF5EEAD4);
const _mintSoft = Color(0xFFD7F5EA);
const _mintStrong = Color(0xFF9DEBD9);
const _blueBg = Color(0xFFE3EBFA);
const _soft = Color(0xFFEFF3FC);
const _red = Color(0xFFD92D20);
const _amberFg = Color(0xFFB45309);
const _amberBg = Color(0xFFFFE8CC);

/// Nivel de corrección de errores "H" del QR (QrErrorCorrectLevel.H): permite
/// poner el escudo en el centro sin que deje de escanearse.
const _qrLevelH = 2;

const _extendMs = 3 * 60 * 1000;
const _maxSessionMs = 3 * 60 * 60 * 1000;

const _shadow = [
  BoxShadow(color: Color(0x120B3A5E), blurRadius: 16, offset: Offset(0, 6)),
];

String _two(int n) => n.toString().padLeft(2, '0');

String _dateTime(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)} ${_two(d.hour)}:${_two(d.minute)}';

String _shortName(String full) {
  final w = full
      .trim()
      .split(RegExp(r'\s+'))
      .where((x) => x.isNotEmpty)
      .toList();
  if (w.isEmpty) return 'Estudiante';
  if (w.length <= 2) return w.join(' ');
  return '${w.first} ${w[w.length - 2]} ${w.last[0].toUpperCase()}.';
}

String _initials(String full) {
  final w = full
      .trim()
      .split(RegExp(r'\s+'))
      .where((x) => x.isNotEmpty)
      .toList();
  if (w.isEmpty) return '?';
  if (w.length == 1) return w.first[0].toUpperCase();
  return (w.first[0] + w.last[0]).toUpperCase();
}

class TeacherQrScreen extends ConsumerStatefulWidget {
  const TeacherQrScreen({super.key});

  @override
  ConsumerState<TeacherQrScreen> createState() => _TeacherQrScreenState();
}

class _TeacherQrScreenState extends ConsumerState<TeacherQrScreen> {
  final _store = LocalSessionStore();
  late final Stream<List<SessionInfo>> _mySessions;

  bool _loading = true;
  bool _showClaims = false;
  bool _expanded = false;
  bool _hideNames = false;
  LocalSession? _local; // sesión en curso (el código se calcula sin conexión)
  List<ClaimInfo> _claims = const [];
  SessionInfo? _viewInfo; // sesión anterior que se está revisando
  String? _viewSecret;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _mySessions = ref.read(attendanceRepositoryProvider).watchMySessions();
    _restore();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _setSystemUi(false);
    super.dispose();
  }

  int _nowMs() =>
      DateTime.now().millisecondsSinceEpoch + (_local?.offsetMs ?? 0);

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _setSystemUi(bool immersive) {
    try {
      unawaited(
        SystemChrome.setEnabledSystemUIMode(
          immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
        ).catchError((Object _) {}),
      );
    } catch (_) {
      // En web no aplica.
    }
  }

  void _setExpanded(bool value) {
    setState(() => _expanded = value);
    _setSystemUi(value);
  }

  void _setClaims(List<ClaimInfo> claims) {
    if (mounted) setState(() => _claims = claims);
  }

  /// Si hay una sesión en curso en este dispositivo, la retoma (sin red).
  Future<void> _restore() async {
    final saved = await _store.load();
    if (!mounted) return;
    if (saved != null &&
        saved.endsAtMs >
            DateTime.now().millisecondsSinceEpoch + saved.offsetMs) {
      _enterRunning(saved);
    }
    setState(() => _loading = false);
  }

  void _enterRunning(LocalSession s) {
    _local = s;
    _showClaims = false;
    _expanded = false;
    _claims = const [];
    _viewInfo = null;
    _viewSecret = null;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _onTick() {
    final s = _local;
    if (!mounted || s == null) return;
    if (_nowMs() >= s.endsAtMs) {
      _endLocal();
      return;
    }
    setState(() {}); // refresca el QR y los contadores
  }

  /// Termina la parte local (QR) y pasa a revisar los registros de esa sesión.
  Future<void> _endLocal() async {
    final s = _local;
    _timer?.cancel();
    _setSystemUi(false);
    await _store.clear();
    if (!mounted) return;
    setState(() {
      if (s != null) {
        _viewInfo = s.toInfo();
        _viewSecret = s.secret;
      }
      _local = null;
      _claims = const [];
      _showClaims = false;
      _expanded = false;
    });
  }

  Future<void> _finish() async {
    final s = _local;
    if (s != null) {
      unawaited(
        ref
            .read(attendanceRepositoryProvider)
            .closeSession(s.id, _nowMs())
            .catchError((Object _) {}),
      );
    }
    await _endLocal();
  }

  Future<void> _confirmFinish() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          '¿Finalizar la sesión?',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy),
        ),
        content: const Text(
          'El código dejará de funcionar. Los registros ya hechos se conservan y podrás revisarlos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Seguir'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Finalizar', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (ok == true) await _finish();
  }

  /// Alarga la sesión 3 minutos.
  Future<void> _extend() async {
    final s = _local;
    if (s == null) return;

    final newEnd = s.endsAtMs + _extendMs;
    if (newEnd - s.startsAtMs > _maxSessionMs) {
      _snack('Una sesión no puede durar más de 3 horas.');
      return;
    }

    final updated = s.withEnd(newEnd);
    await _store.save(updated);
    if (!mounted) return;
    setState(() => _local = updated);
    // Sin conexión, la actualización queda en cola y se envía al volver la señal.
    unawaited(
      ref
          .read(attendanceRepositoryProvider)
          .extendSession(s.id, newEnd)
          .catchError((Object _) {}),
    );
    _snack('Sesión extendida 3 minutos');
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/teacher');
    }
  }

  Future<void> _openPast(SessionInfo info) async {
    try {
      var secret = _local?.id == info.id ? _local!.secret : null;
      secret ??= await ref
          .read(attendanceRepositoryProvider)
          .fetchSecret(info.id)
          .timeout(const Duration(seconds: 10));
      if (secret == null) {
        if (mounted) _snack('No se encontró la clave de esa sesión.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _viewInfo = info;
        _viewSecret = secret;
      });
    } catch (_) {
      if (mounted) _snack('No se pudo abrir la sesión. Revisa tu conexión.');
    }
  }

  void _showTips() {
    Widget tip(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.navy),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Consejos de proyección',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tip(
                Icons.brightness_high_outlined,
                'Sube el brillo de la pantalla al máximo para que el QR se lea desde lejos.',
              ),
              tip(
                Icons.fullscreen,
                'Usa el botón de pantalla completa para proyectar solo el QR y el código, sin nombres de estudiantes.',
              ),
              tip(
                Icons.visibility_off_outlined,
                'Esta pantalla muestra el nombre del último estudiante. Ocúltalo con el ícono del ojo antes de proyectarla.',
              ),
              tip(
                Icons.screen_lock_portrait_outlined,
                'Evita que la pantalla se apague: ajusta el tiempo de apagado en tu dispositivo durante la clase.',
              ),
              tip(
                Icons.dialpad,
                'Quien no pueda escanear puede escribir el código de 6 dígitos que aparece bajo el QR.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // ------------------------------ Interfaz ------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _light(
        title: 'Sesión de clase',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_local != null && _expanded) return _buildExpanded();
    if (_local != null && !_showClaims) return _buildPanel();
    if (_local != null) return _buildRunningClaims();
    if (_viewInfo != null) return _buildViewing();
    return _buildHistory();
  }

  /// Pantalla clara con barra superior. Si se da [onBack], la flecha atrás
  /// ejecuta esa acción en lugar de salir de la pantalla.
  Widget _light({
    required String title,
    required Widget child,
    VoidCallback? onBack,
  }) {
    return PopScope(
      canPop: onBack == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack?.call();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: onBack == null ? null : BackButton(onPressed: onBack),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------- Datos de la sesión ---------------------------

  int _enrolledFor(LocalSession s) {
    final sample = sampleCourseDetail(s.courseId, DateTime.now());
    if (sample != null) return sample.students.length;
    return ref.watch(enrolledStudentsProvider(s.courseId)).value?.length ?? 0;
  }

  String _modalityLabel(LocalSession s) {
    final real = ref
        .watch(myCoursesProvider)
        .value
        ?.where((c) => c.id == s.courseId)
        .firstOrNull;
    if (real != null) return modalityTitle(real.modality).toUpperCase();
    return 'PRESENCIAL TEÓRICO-PRÁCTICA'; // cursos de ejemplo
  }

  String _ago(ClaimInfo c, int nowMs) {
    final t =
        c.syncedAt?.millisecondsSinceEpoch ?? (c.scannedAt + c.clockOffsetMs);
    final s = math.max(0, ((nowMs - t) / 1000).round());
    if (s < 60) return 'hace ${s}s';
    if (s < 3600) return 'hace ${s ~/ 60} min';
    return 'hace ${s ~/ 3600} h';
  }

  // ----------------------- Vista principal de la sesión -----------------------

  Widget _buildPanel() {
    final s = _local!;
    final totp = Totp(s.secret, stepSeconds: s.stepSeconds);
    final now = _nowMs();
    final step = totp.stepOf(now);
    final pin = totp.pin(step);
    final payload = buildQrPayload(
      sessionId: s.id,
      timestampMs: totp.stepStartMs(now),
      code: totp.qrCode(step),
    );
    final secsToNext = (totp.msToNextStep(now) / 1000).ceil();
    final leftMs = (s.endsAtMs - now).clamp(0, 1 << 40).toInt();
    final totalMs = math.max(1, s.endsAtMs - s.startsAtMs);
    final left = Duration(milliseconds: leftMs);
    final mm = left.inMinutes.toString().padLeft(2, '0');
    final ss = _two(left.inSeconds % 60);

    final enrolled = _enrolledFor(s);
    final validated = _claims
        .where((c) => c.status == ClaimStatus.validated)
        .length;
    final waitingValidation = _claims
        .where((c) => c.status == ClaimStatus.pending)
        .length;
    final review = _claims.where((c) => c.status == ClaimStatus.review).length;
    final present = validated + waitingValidation;
    final waiting = math.max(0, enrolled - present - review);
    final percent = enrolled == 0
        ? 0
        : math.min(100, (present * 100 / enrolled).round());

    ClaimInfo? last;
    for (final c in _claims) {
      final t =
          c.syncedAt?.millisecondsSinceEpoch ?? (c.scannedAt + c.clockOffsetMs);
      final lt = last == null
          ? 0
          : (last.syncedAt?.millisecondsSinceEpoch ??
                (last.scannedAt + last.clockOffsetMs));
      if (last == null || t >= lt) last = c;
    }
    String? lastCode;
    if (last != null) {
      final roster =
          ref.watch(enrolledStudentsProvider(s.courseId)).value ??
          const <EnrolledStudent>[];
      final id = last.studentId;
      lastCode = roster.where((e) => e.id == id).firstOrNull?.code;
    }

    final codeChip = s.courseCode.isEmpty
        ? ''
        : (s.section == null
              ? s.courseCode
              : '${s.courseCode} • Sec. ${s.section}');
    final week = (s.number + 1) ~/ 2; // 2 sesiones por semana
    final classPart = s.number > 0 ? 'Clase #${s.number} (Semana $week)' : '';
    final subtitle = [
      codeChip,
      classPart,
    ].where((e) => e.isNotEmpty).join(' — ');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                _topRow(s.room),
                const SizedBox(height: 14),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: const BoxDecoration(
                      color: _blueBg,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.menu_book_outlined,
                          size: 15,
                          color: AppColors.navy,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            _modalityLabel(s),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  s.courseName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                    height: 1.15,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                _timerQrCard(
                  mm: mm,
                  ss: ss,
                  urgent: leftMs < 60 * 1000,
                  timeProgress: leftMs / totalMs,
                  payload: payload,
                  pin: pin,
                  secsToNext: secsToNext,
                  stepSeconds: s.stepSeconds,
                ),
                const SizedBox(height: 14),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _AttendanceStat(
                          present: present,
                          enrolled: enrolled,
                          percent: percent,
                          review: review,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PendingStat(
                          waiting: waiting,
                          enrolled: enrolled,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _lastCard(last, lastCode, now),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _extend,
                  icon: const Icon(Icons.more_time, size: 21),
                  label: const Text('Extender +3 minutos extra'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD9E6F8),
                    foregroundColor: AppColors.navy,
                    minimumSize: const Size.fromHeight(56),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _confirmFinish,
                  icon: const Icon(Icons.stop_circle_outlined, size: 22),
                  label: const Text('Finalizar sesión de asistencia'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB3261E),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(58),
                    textStyle: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showClaims = true),
                    icon: const Icon(
                      Icons.checklist,
                      size: 19,
                      color: AppColors.navy,
                    ),
                    label: Text(
                      'Ver lista en vivo (${_claims.length})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ),
                // Sin dibujarse: mantiene activa la validación automática de los
                // registros y alimenta los contadores de esta pantalla.
                Offstage(
                  child: _ClaimsPanel(
                    key: ValueKey('auto-${s.id}'),
                    session: s.toInfo(),
                    secret: s.secret,
                    onClaims: _setClaims,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topRow(String room) {
    Widget square(IconData icon, String tooltip, VoidCallback onTap) =>
        Material(
          color: _blueBg,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Tooltip(
              message: tooltip,
              child: SizedBox(
                width: 42,
                height: 42,
                child: Icon(icon, size: 22, color: AppColors.navy),
              ),
            ),
          ),
        );

    return Row(
      children: [
        IconButton(
          tooltip: 'Salir (la sesión sigue activa)',
          onPressed: _leave,
          icon: const Icon(Icons.arrow_back, color: AppColors.navy),
        ),
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: const BoxDecoration(
                  color: _mintSoft,
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: _teal),
                    SizedBox(width: 7),
                    Text(
                      'EN VIVO',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: _teal,
                      ),
                    ),
                  ],
                ),
              ),
              if (room.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.meeting_room_outlined,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      room,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        square(Icons.lightbulb_outline, 'Consejos de proyección', _showTips),
        const SizedBox(width: 8),
        square(
          Icons.fullscreen,
          'Pantalla completa (solo QR)',
          () => _setExpanded(true),
        ),
      ],
    );
  }

  Widget _qr(String payload, double side, {bool badge = true}) {
    return SizedBox(
      width: side,
      height: side,
      child: Stack(
        alignment: Alignment.center,
        children: [
          QrImageView(
            data: payload,
            version: QrVersions.auto,
            size: side,
            backgroundColor: Colors.white,
            errorCorrectionLevel: _qrLevelH,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: _navyDark,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: _navyDark,
            ),
          ),
          if (badge)
            Container(
              width: side * 0.17,
              height: side * 0.17,
              decoration: BoxDecoration(
                color: _navyBtn,
                borderRadius: BorderRadius.circular(side * 0.04),
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Icon(
                Icons.verified_user,
                color: Colors.white,
                size: side * 0.085,
              ),
            ),
        ],
      ),
    );
  }

  Widget _timerQrCard({
    required String mm,
    required String ss,
    required bool urgent,
    required double timeProgress,
    required String payload,
    required String pin,
    required int secsToNext,
    required int stepSeconds,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Color(0xFFE6F7F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(28)),
        boxShadow: _shadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 27,
                color: urgent ? _red : AppColors.navy,
              ),
              const SizedBox(width: 10),
              Text(
                '$mm:$ss',
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  color: urgent ? _red : AppColors.navy,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _blueBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'MIN',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: timeProgress.clamp(0.0, 1.0).toDouble(),
              minHeight: 7,
              color: urgent ? _red : _navyBtn,
              backgroundColor: const Color(0xFFD5E0F2),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cierre automático al alcanzar 00:00',
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final side = math.min(c.maxWidth - 28, 300.0);
              return Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: _mintStrong, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A066A5C),
                        blurRadius: 22,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _qr(payload, side),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.autorenew,
                      size: 19,
                      color: AppColors.navy,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Token dinámico activo',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    Text(
                      '${secsToNext}s',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (secsToNext / stepSeconds)
                        .clamp(0.0, 1.0)
                        .toDouble(),
                    minHeight: 7,
                    color: _teal,
                    backgroundColor: const Color(0xFFD5E0F2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE1E8F4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.dialpad, size: 19, color: AppColors.textMuted),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Código manual',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                Text(
                  '${pin.substring(0, 3)} ${pin.substring(3)}',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lastCard(ClaimInfo? c, String? code, int nowMs) {
    if (c == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          color: _blueBg,
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: const Row(
          children: [
            Icon(Icons.hourglass_empty, size: 22, color: AppColors.navy),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Aún no hay registros. Aparecerán aquí cuando los estudiantes escaneen.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.navy,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final name = c.studentName.isEmpty ? 'Estudiante' : c.studentName;
    final (statusIcon, statusColor) = switch (c.status) {
      ClaimStatus.validated => (Icons.verified, _teal),
      ClaimStatus.review => (Icons.rate_review_outlined, _amberFg),
      ClaimStatus.rejected => (Icons.cancel, _red),
      ClaimStatus.pending => (Icons.schedule, AppColors.textMuted),
    };
    final detail = (code != null && code.isNotEmpty)
        ? 'Último registro • Matrícula $code'
        : 'Último registro • ${c.method == 'qr' ? 'QR' : 'Código manual'}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _mintStrong,
            child: Text(
              _hideNames ? '••' : _initials(name),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF065F52),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _hideNames ? 'Nombre oculto' : _shortName(name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(statusIcon, size: 16, color: statusColor),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _hideNames ? 'Último registro' : detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: _mintSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _ago(c, nowMs),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: _teal,
              ),
            ),
          ),
          IconButton(
            tooltip: _hideNames ? 'Mostrar nombre' : 'Ocultar nombre',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _hideNames = !_hideNames),
            icon: Icon(
              _hideNames
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 19,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------- Vista ampliada (para proyectar) -----------------------

  Widget _buildExpanded() {
    final s = _local!;
    final totp = Totp(s.secret, stepSeconds: s.stepSeconds);
    final now = _nowMs();
    final step = totp.stepOf(now);
    final pin = totp.pin(step);
    final payload = buildQrPayload(
      sessionId: s.id,
      timestampMs: totp.stepStartMs(now),
      code: totp.qrCode(step),
    );
    final secsToNext = (totp.msToNextStep(now) / 1000).ceil();
    final left = Duration(
      milliseconds: (s.endsAtMs - now).clamp(0, 1 << 40).toInt(),
    );
    final mm = left.inMinutes.toString().padLeft(2, '0');
    final ss = _two(left.inSeconds % 60);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setExpanded(false);
      },
      child: Scaffold(
        backgroundColor: _navyDark,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final side = math.max(
                200.0,
                math.min(math.min(c.maxWidth - 48, c.maxHeight * 0.50), 520.0),
              );

              return Stack(
                children: [
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            s.courseName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Termina en $mm:$ss',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.all(
                                Radius.circular(28),
                              ),
                            ),
                            child: _qr(payload, side, badge: false),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Código para ingresar manualmente',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: Colors.white70,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${pin.substring(0, 3)} ${pin.substring(3)}',
                              style: const TextStyle(
                                fontSize: 58,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 8,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: math.min(side, 320),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: (secsToNext / s.stepSeconds)
                                    .clamp(0.0, 1.0)
                                    .toDouble(),
                                minHeight: 7,
                                color: _mint,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'El código cambia en ${secsToNext}s',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.groups_outlined,
                                  size: 19,
                                  color: _mint,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_claims.length} ${_claims.length == 1 ? 'registro' : 'registros'}',
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Offstage(
                            child: _ClaimsPanel(
                              key: ValueKey('auto-expanded-${s.id}'),
                              session: s.toInfo(),
                              secret: s.secret,
                              onClaims: _setClaims,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      tooltip: 'Salir de pantalla completa',
                      onPressed: () => _setExpanded(false),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ----------------------- Registros de la sesión en curso -----------------------

  Widget _buildRunningClaims() {
    final s = _local!;
    return _light(
      title: 'Registros de asistencia',
      onBack: () => setState(() => _showClaims = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.courseName,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _amberBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.visibility_off_outlined, size: 18, color: _amberFg),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Esta vista muestra nombres de estudiantes: no la proyectes en el aula.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: Color(0xFF7A4A12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ClaimsPanel(
            key: ValueKey(s.id),
            session: s.toInfo(),
            secret: s.secret,
            onClaims: _setClaims,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => setState(() => _showClaims = false),
            icon: const Icon(Icons.qr_code_2),
            label: const Text('Volver al código QR'),
            style: FilledButton.styleFrom(
              backgroundColor: _navyBtn,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------ Revisión de una sesión pasada ------------------------

  Widget _buildViewing() {
    final info = _viewInfo!;
    return _light(
      title: 'Registros de asistencia',
      onBack: () => setState(() {
        _viewInfo = null;
        _viewSecret = null;
      }),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            info.courseName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          Text(
            '${info.room.isEmpty ? '' : '${info.room} • '}${_dateTime(info.startsAt)}',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          _ClaimsPanel(
            key: ValueKey(info.id),
            session: info,
            secret: _viewSecret!,
          ),
        ],
      ),
    );
  }

  // ------------------------------ Sesiones anteriores ------------------------------

  Widget _buildHistory() {
    return _light(
      title: 'Sesiones de clase',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sesiones anteriores',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ábrelas para validar los registros que los estudiantes sincronizaron después de la clase.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<SessionInfo>>(
            stream: _mySessions,
            builder: (context, snap) {
              final list = snap.data ?? const <SessionInfo>[];
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Aún no has iniciado sesiones.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                );
              }
              return Column(
                children: [
                  for (final s in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PastSessionTile(
                        info: s,
                        onOpen: () => _openPast(s),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: _blueBg,
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.navy),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Para iniciar una sesión nueva, abre un curso y pulsa "Activar Toma de Asistencia".',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.go('/teacher'),
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Ir a mis cursos'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.navy,
              padding: const EdgeInsets.symmetric(vertical: 14),
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

// ---------------------------------------------------------------------------
// Tarjetas de estadísticas
// ---------------------------------------------------------------------------
class _AttendanceStat extends StatelessWidget {
  const _AttendanceStat({
    required this.present,
    required this.enrolled,
    required this.percent,
    required this.review,
  });

  final int present;
  final int enrolled;
  final int percent;
  final int review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(22)),
        boxShadow: _shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Asistencia',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              if (enrolled > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _mintStrong,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$percent%',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF065F52),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$present',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  enrolled > 0 ? '/ $enrolled presentes' : 'presentes',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: enrolled == 0
                  ? 0
                  : (percent / 100).clamp(0.0, 1.0).toDouble(),
              minHeight: 7,
              color: _teal,
              backgroundColor: const Color(0xFFD5E0F2),
            ),
          ),
          if (review > 0) ...[
            const SizedBox(height: 8),
            Text(
              '+$review en revisión',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: _amberFg,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingStat extends StatelessWidget {
  const _PendingStat({required this.waiting, required this.enrolled});

  final int waiting;
  final int enrolled;

  @override
  Widget build(BuildContext context) {
    final known = enrolled > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(22)),
        boxShadow: _shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Pendientes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Icon(Icons.groups_outlined, size: 20, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                known ? '$waiting' : '—',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 5),
              if (known)
                const Text(
                  'alumnos',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.hourglass_empty,
                size: 15,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  known ? 'Esperando escaneo' : 'Sin matrícula en el curso',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
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

class _PastSessionTile extends StatelessWidget {
  const _PastSessionTile({required this.info, required this.onOpen});

  final SessionInfo info;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.history, color: AppColors.navy),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.courseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      '${info.room.isEmpty ? '' : '${info.room} • '}${_dateTime(info.startsAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Registros de una sesión + validación automática
// ---------------------------------------------------------------------------
class _ClaimsPanel extends ConsumerStatefulWidget {
  const _ClaimsPanel({
    super.key,
    required this.session,
    required this.secret,
    this.onClaims,
  });

  final SessionInfo session;
  final String secret;

  /// Avisa a la pantalla cada vez que cambia la lista de registros.
  final ValueChanged<List<ClaimInfo>>? onClaims;

  @override
  ConsumerState<_ClaimsPanel> createState() => _ClaimsPanelState();
}

class _ClaimsPanelState extends ConsumerState<_ClaimsPanel> {
  StreamSubscription<List<ClaimInfo>>? _sub;
  List<ClaimInfo> _claims = const [];
  bool _validating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sub = ref
        .read(attendanceRepositoryProvider)
        .watchClaims(widget.session.id)
        .listen(
          _onClaims,
          onError: (Object _) {
            if (mounted)
              setState(() => _error = 'No se pudieron leer los registros.');
          },
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _onClaims(List<ClaimInfo> claims) async {
    if (!mounted) return;
    setState(() => _claims = claims);
    widget.onClaims?.call(claims);
    await _autoValidate(claims);
  }

  /// Valida los registros nuevos con la clave de la sesión.
  Future<void> _autoValidate(List<ClaimInfo> claims) async {
    if (_validating) return;

    final byDevice = <String, Set<String>>{};
    for (final c in claims) {
      if (c.deviceId.isEmpty) continue;
      byDevice.putIfAbsent(c.deviceId, () => <String>{}).add(c.studentId);
    }
    bool shared(ClaimInfo c) => (byDevice[c.deviceId]?.length ?? 0) > 1;

    final totp = Totp(widget.secret, stepSeconds: widget.session.stepSeconds);
    final updates = <ClaimUpdate>[];

    for (final c in claims) {
      if (c.reviewed) continue; // decisión manual del docente: no se toca
      if (c.status == ClaimStatus.pending && c.syncedAt != null) {
        final out = ClaimValidator.validate(
          totp: totp,
          session: widget.session,
          claim: c,
          sharedDevice: shared(c),
        );
        if (out.status != ClaimStatus.pending) {
          updates.add(ClaimUpdate(c.studentId, out));
        }
      } else if (c.status == ClaimStatus.validated && shared(c)) {
        updates.add(
          ClaimUpdate(
            c.studentId,
            ValidationOutcome(
              ClaimStatus.review,
              reason: 'dispositivo_compartido',
              timeVerified: c.timeVerified,
            ),
          ),
        );
      }
    }
    if (updates.isEmpty) return;

    _validating = true;
    try {
      await ref
          .read(attendanceRepositoryProvider)
          .applyValidation(widget.session.id, updates);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo guardar la validación. Reintenta con conexión.',
        );
      }
    } finally {
      _validating = false;
    }
  }

  Future<void> _review(ClaimInfo c, bool approve) async {
    try {
      await ref
          .read(attendanceRepositoryProvider)
          .reviewClaim(widget.session.id, c.studentId, approve: approve);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('No se pudo guardar la decisión.')),
          );
      }
    }
  }

  int _count(ClaimStatus s) => _claims.where((c) => c.status == s).length;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x140B3A5E),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Registros de asistencia (${_claims.length})',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CountChip(
                'Confirmadas',
                _count(ClaimStatus.validated),
                AppColors.green,
                _mintSoft,
              ),
              _CountChip(
                'En revisión',
                _count(ClaimStatus.review),
                _amberFg,
                _amberBg,
              ),
              _CountChip(
                'Rechazadas',
                _count(ClaimStatus.rejected),
                _red,
                const Color(0xFFFEE2E2),
              ),
              _CountChip(
                'Por validar',
                _count(ClaimStatus.pending),
                AppColors.navy,
                _blueBg,
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: _red, fontSize: 12.5)),
          ],
          const SizedBox(height: 12),
          if (_claims.isEmpty)
            const Text(
              'Aún no hay registros. Los de estudiantes sin conexión aparecerán cuando sincronicen.',
              style: TextStyle(color: AppColors.textMuted, height: 1.4),
            ),
          for (final c in _claims)
            _ClaimTile(
              claim: c,
              onApprove: () => _review(c, true),
              onReject: () => _review(c, false),
            ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip(this.label, this.count, this.fg, this.bg);

  final String label;
  final int count;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

class _ClaimTile extends StatelessWidget {
  const _ClaimTile({
    required this.claim,
    required this.onApprove,
    required this.onReject,
  });

  final ClaimInfo claim;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final c = claim;
    final (label, fg, bg) = switch (c.status) {
      ClaimStatus.validated => ('Confirmada', AppColors.green, _mintSoft),
      ClaimStatus.review => ('En revisión', _amberFg, _amberBg),
      ClaimStatus.rejected => ('Rechazada', _red, const Color(0xFFFEE2E2)),
      ClaimStatus.pending => ('Por validar', AppColors.navy, _blueBg),
    };

    final scanned = TimeOfDay.fromDateTime(
      DateTime.fromMillisecondsSinceEpoch(c.scannedAt + c.clockOffsetMs),
    ).format(context);

    final notes = <String>[
      c.method == 'qr' ? 'QR' : 'Código manual',
      scanned,
      if (c.status == ClaimStatus.validated && !c.timeVerified)
        'hora no verificada (sin conexión)',
      if (c.reason != null && c.reason!.isNotEmpty) reasonText(c.reason),
    ];

    final canDecide =
        c.status == ClaimStatus.review || c.status == ClaimStatus.rejected;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFFF6F8FD),
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.studentName.isEmpty ? 'Estudiante' : c.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notes.join(' • '),
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.3,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (canDecide) ...[
            IconButton(
              tooltip: 'Aprobar',
              onPressed: onApprove,
              icon: const Icon(
                Icons.check_circle_outline,
                color: AppColors.green,
              ),
            ),
            if (c.status == ClaimStatus.review)
              IconButton(
                tooltip: 'Rechazar',
                onPressed: onReject,
                icon: const Icon(Icons.cancel_outlined, color: _red),
              ),
          ],
        ],
      ),
    );
  }
}
