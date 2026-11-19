import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/clock_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/name_utils.dart';
import '../../attendance/data/attendance_models.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../teacher/data/course_repository.dart' show modalityTitle;
import '../data/student_courses_data.dart';
import '../../../core/widgets/detail_option_tile.dart';
import '../../justifications/data/justification_data.dart';

const _teal = Color(0xFF066A5C);
const _mint = Color(0xFFD7F5EA);
const _blueBg = Color(0xFFE3EBFA);
const _soft = Color(0xFFEFF3FC);
const _red = Color(0xFFD92D20);
const _amber = Color(0xFFF5B942);
const _amberFg = Color(0xFFB45309);
const _amberBg = Color(0xFFFFE8CC);

const _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(24)),
  boxShadow: [
    BoxShadow(color: Color(0x140B3A5E), blurRadius: 18, offset: Offset(0, 6)),
  ],
);

String _two(int n) => n.toString().padLeft(2, '0');

class RealCourseDetailScreen extends ConsumerWidget {
  const RealCourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/student');
    }
  }

  void _soon(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$text (próximamente)')));
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(studentCourseAttendanceProvider(courseId));
    ref.invalidate(studentOverviewProvider);
    try {
      await ref.read(studentCourseAttendanceProvider(courseId).future);
    } catch (_) {
      // El error se muestra en pantalla.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studentCourseAttendanceProvider(courseId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _back(context),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.navy,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Detalle del Curso',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Actualizar',
                        onPressed: () => _refresh(ref),
                        icon: const Icon(Icons.refresh, color: AppColors.navy),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: async.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'No se pudo cargar el curso. Revisa tu conexión.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _red, height: 1.4),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => _refresh(ref),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    data: (a) => a == null
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(28),
                              child: Text(
                                'No estás matriculado en este curso.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            ),
                          )
                        : _content(context, ref, a),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, CourseAttendance a) {
    final c = a.course;

    return RefreshIndicator(
      onRefresh: () => _refresh(ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _back(context),
                icon: const Icon(
                  Icons.chevron_left,
                  size: 20,
                  color: AppColors.navy,
                ),
                label: const Text(
                  'Mis cursos',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const Spacer(),
              if (c.code.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: const BoxDecoration(
                    color: _blueBg,
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  child: Text(
                    c.code,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _HeaderCard(course: c),
          if (c.limited) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _amberBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 19, color: _amberFg),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No se pudo leer la información completa del curso (faltas máximas, ciclo). Revisa tu conexión y actualiza.',
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
          ],
          const SizedBox(height: 16),
          _BalanceCard(a: a),
          const SizedBox(height: 16),
          _ActiveSessionCard(
            courseId: c.id,
            courseName: c.name,
            onReturned: () {
              ref.invalidate(studentCourseAttendanceProvider(c.id));
              ref.invalidate(studentOverviewProvider);
            },
          ),
          const SizedBox(height: 16),
          DetailOptionTile(
            icon: Icons.history,
            title: 'Historial Completo de Asistencia',
            subtitle: 'Cada clase con su estado y la hora de tu registro',
            onTap: () async {
              await context.push('/student/course/${c.id}/history');
              ref.invalidate(studentCourseAttendanceProvider(c.id));
            },
          ),
          const SizedBox(height: 12),
          DetailOptionTile(
            icon: Icons.assignment_outlined,
            title: 'Justificar Faltas',
            subtitle: 'Solicita que el docente justifique una inasistencia',
            chip: 'Plazo: ${kJustifyHours}h',
            onTap: () => context.push('/student/course/${c.id}/justify'),
          ),
          if (c.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.sticky_note_2_outlined,
                        size: 20,
                        color: AppColors.navy,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Información del docente',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.notes.trim(),
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: Color(0xFF3D4B5C),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Encabezado del curso
// ---------------------------------------------------------------------------
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.course});

  final EnrolledCourse course;

  @override
  Widget build(BuildContext context) {
    final c = course;
    final hasTeacher = c.teacherName.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c.period.isNotEmpty)
            Text(
              'CICLO ${c.period.toUpperCase()}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.textMuted,
              ),
            ),
          if (c.period.isNotEmpty) const SizedBox(height: 8),
          Text(
            c.name,
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
                  child: hasTeacher
                      ? Text(
                          initialsOf(c.teacherName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : const Icon(
                          Icons.person_outline,
                          color: Colors.white,
                          size: 22,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasTeacher
                            ? 'Prof. ${c.teacherName.trim()}'
                            : c.teacherLabel,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Docente • ${modalityTitle(c.modality)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
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
    );
  }
}

// ---------------------------------------------------------------------------
// Balance de asistencia
// ---------------------------------------------------------------------------
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.a});

  final CourseAttendance a;

  @override
  Widget build(BuildContext context) {
    final c = a.course;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration,
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
                    if (c.period.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Período Académico ${c.period}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: const BoxDecoration(
                  color: _blueBg,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                child: Text(
                  a.held == 0
                      ? 'Sin clases aún'
                      : '${a.held} ${a.held == 1 ? 'clase' : 'clases'}',
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
          if (a.held == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'Aún no hay clases dictadas.\nTu asistencia aparecerá aquí cuando registres la primera.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, height: 1.4),
                ),
              ),
            )
          else
            Center(
              child: _Ring(present: a.present, absent: a.absent),
            ),
          if (!c.limited) ...[
            const SizedBox(height: 18),
            CourseLimitBox(attendance: a),
          ],
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StatBox(
                    bg: _soft,
                    border: const Color(0xFFDDE6F5),
                    label: 'Dictadas',
                    labelColor: AppColors.textMuted,
                    value: '${a.held}',
                    valueColor: AppColors.navy,
                    caption: c.totalSessions > 0
                        ? 'de ${c.totalSessions}'
                        : 'clases',
                    captionColor: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatBox(
                    bg: const Color(0xFFB7F2E0),
                    border: const Color(0xFF8FE3CA),
                    label: 'ASISTIDAS',
                    labelColor: _teal,
                    value: '${a.present}',
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
                    label: 'INASIST.',
                    labelColor: _red,
                    value: '${a.absent}',
                    valueColor: _red,
                    caption: c.limited ? 'faltas' : 'máx. ${c.maxAbsences}',
                    captionColor: _red,
                  ),
                ),
              ],
            ),
          ),
          if (a.inProcess > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _amberBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.hourglass_top, size: 18, color: _amberFg),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${a.inProcess} ${a.inProcess == 1 ? 'registro' : 'registros'} en validación o revisión: no cuenta${a.inProcess == 1 ? '' : 'n'} hasta que el docente ${a.inProcess == 1 ? 'lo confirme' : 'los confirme'}.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: Color(0xFF7A4A12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
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
  });

  final Color bg;
  final Color border;
  final String label;
  final Color labelColor;
  final String value;
  final Color valueColor;
  final String caption;
  final Color captionColor;

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
          Text(
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

/// Aviso de faltas permitidas (también se usa en el historial).
class CourseLimitBox extends StatelessWidget {
  const CourseLimitBox({super.key, required this.attendance});

  final CourseAttendance attendance;

  @override
  Widget build(BuildContext context) {
    final a = attendance;
    final r = a.remaining;
    final max = a.course.maxAbsences;
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
                const Text(
                  'Límite reglamentario: 20%',
                  style: TextStyle(
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
                      TextSpan(text: 'Máximo permitido: $max inasistencias. '),
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

class _Ring extends StatelessWidget {
  const _Ring({required this.present, required this.absent});

  final int present;
  final int absent;

  @override
  Widget build(BuildContext context) {
    final total = present + absent;
    final pct = total == 0 ? 0 : (present * 100 / total).round();

    return SizedBox(
      width: 140,
      height: 140,
      child: CustomPaint(
        painter: _RingPainter(present: present, absent: absent),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$pct%',
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
  const _RingPainter({required this.present, required this.absent});

  final int present;
  final int absent;

  static const _stroke = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);

    Paint paint(Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = color;

    canvas.drawCircle(
      rect.center,
      rect.width / 2,
      paint(const Color(0xFFE6ECF7)),
    );

    final total = present + absent;
    if (total == 0) return;

    const full = 2 * math.pi;
    final presentSweep = present / total * full;
    final absentSweep = absent / total * full;

    canvas.drawArc(rect, -math.pi / 2, presentSweep, false, paint(_teal));
    if (absent > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2 + presentSweep,
        absentSweep,
        false,
        paint(_amber),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.present != present || old.absent != absent;
}

// ---------------------------------------------------------------------------
// Clase en progreso (en vivo)
// ---------------------------------------------------------------------------
class _ActiveSessionCard extends ConsumerStatefulWidget {
  const _ActiveSessionCard({
    required this.courseId,
    required this.courseName,
    required this.onReturned,
  });

  final String courseId;
  final String courseName;
  final VoidCallback onReturned;

  @override
  ConsumerState<_ActiveSessionCard> createState() => _ActiveSessionCardState();
}

class _ActiveSessionCardState extends ConsumerState<_ActiveSessionCard> {
  StreamSubscription<SessionInfo?>? _sessionSub;
  StreamSubscription<ClaimInfo?>? _claimSub;
  Timer? _ticker;

  SessionInfo? _session;
  ClaimInfo? _claim;
  String? _claimFor;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _listenClaim(String sessionId) {
    if (_claimFor == sessionId) return;
    _claimSub?.cancel();
    _claimFor = sessionId;
    _claimSub = ref
        .read(attendanceRepositoryProvider)
        .watchMyClaim(sessionId)
        .listen((c) {
          if (mounted) setState(() => _claim = c);
        }, onError: (Object _) {});
  }

  Future<void> _register() async {
    await context.push('/student/course/${widget.courseId}/scan');
    widget.onReturned();
  }

  Future<void> _viewStatus(SessionInfo s) async {
    await context.push(
      Uri(
        path: '/student/course/${widget.courseId}/saved',
        queryParameters: {
          's': s.id,
          if (s.room.isNotEmpty) 'room': s.room,
          'name': widget.courseName,
        },
      ).toString(),
    );
    widget.onReturned();
  }

  ({String text, Color color}) _claimText(ClaimInfo c) {
    if (c.hasPendingWrites || c.syncedAt == null) {
      return (
        text: 'Guardado en este dispositivo • se enviará con conexión',
        color: _amberFg,
      );
    }
    return switch (c.status) {
      ClaimStatus.pending => (
        text: 'Enviado • esperando la validación del docente',
        color: AppColors.navy,
      ),
      ClaimStatus.validated => (text: 'Asistencia confirmada', color: _teal),
      ClaimStatus.review => (text: 'En revisión del docente', color: _amberFg),
      ClaimStatus.rejected => (text: 'Registro no validado', color: _red),
    };
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.fromMillisecondsSinceEpoch(
      ref.read(clockServiceProvider).nowMs(),
    );
    final s = _session;
    final active = s != null && s.endsAt.isAfter(now);

    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration,
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Buscando clase en progreso…',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (!active) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration,
        child: const Column(
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 38,
              color: AppColors.textMuted,
            ),
            SizedBox(height: 8),
            Text(
              'Sin clase en progreso',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Podrás registrar tu asistencia cuando el docente inicie la sesión.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    final session = s;
    final left = session.endsAt.difference(now);
    final mm = _two(left.inMinutes);
    final ss = _two(left.inSeconds % 60);
    final claim = _claim;
    final roomText = session.room.isEmpty ? '' : '${session.room} • ';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 5, backgroundColor: _teal),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Clase en progreso',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const Icon(Icons.timer_outlined, size: 16, color: _red),
              const SizedBox(width: 4),
              Text(
                '$mm:$ss min restantes',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (claim == null) ...[
            Text(
              'Valida tu asistencia escaneando el código QR dinámico del aula o escribiendo el código de 6 dígitos.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.4,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${roomText}Código dinámico activo',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _register,
                icon: const Icon(Icons.qr_code_scanner, size: 22),
                label: const Text('Registrar Asistencia Ahora'),
                style: FilledButton.styleFrom(
                  backgroundColor: _teal,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _mint.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.how_to_reg_outlined,
                    size: 20,
                    color: _claimText(claim).color,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _claimText(claim).text,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: _claimText(claim).color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _viewStatus(session),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navy,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Ver estado de mi registro',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
