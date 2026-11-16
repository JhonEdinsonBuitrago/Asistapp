import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../justifications/data/justification_data.dart';
import '../../justifications/presentation/student_justifications_screen.dart'
    show showJustifySheet;
import '../data/student_courses_data.dart';
import 'real_course_detail_screen.dart' show CourseLimitBox;

const _teal = Color(0xFF066A5C);
const _red = Color(0xFFD92D20);
const _redBg = Color(0xFFFCE8E8);
const _redBorder = Color(0xFFF3C6C6);
const _soft = Color(0xFFEFF3FC);
const _chipBlue = Color(0xFFE3EBFA);
const _mint = Color(0xFFD7F5EA);
const _amber = Color(0xFFF5A623);
const _amberFg = Color(0xFFB45309);
const _amberBg = Color(0xFFFFE8CC);
const _navyBtn = Color(0xFF0A2F52);

String _two(int n) => n.toString().padLeft(2, '0');

const _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(22)),
  boxShadow: [
    BoxShadow(color: Color(0x120B3A5E), blurRadius: 16, offset: Offset(0, 6)),
  ],
);

void _showRequest(BuildContext context, JustificationInfo j) {
  final rows = <(String, String)>[
    ('Clase', 'Sesión ${j.sessionNumber} • ${jDateLine(j.sessionDate)}'),
    ('Motivo', j.category.label),
    ('Descripción', j.description),
    if (j.reference.isNotEmpty) ('Referencia del comprobante', j.reference),
    (
      'Estado',
      switch (j.status) {
        JustificationStatus.pending => 'En revisión del docente',
        JustificationStatus.approved => 'Aprobada • Constancia #${j.code}',
        JustificationStatus.rejected => 'Rechazada',
      },
    ),
    if (j.decisionNote.isNotEmpty) ('Nota del docente', j.decisionNote),
  ];

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        'Solicitud de justificación',
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
                        height: 1.3,
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

class RealHistoryScreen extends ConsumerStatefulWidget {
  const RealHistoryScreen({super.key, required this.courseId});

  final String courseId;

  @override
  ConsumerState<RealHistoryScreen> createState() => _RealHistoryScreenState();
}

class _RealHistoryScreenState extends ConsumerState<RealHistoryScreen> {
  int _filter =
      0; // 0 todas, 1 presentes, 2 faltas, 3 justificadas, 4 en proceso

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/student/course/${widget.courseId}');
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(studentCourseAttendanceProvider(widget.courseId));
    try {
      await ref.read(studentCourseAttendanceProvider(widget.courseId).future);
    } catch (_) {
      // El error se muestra en pantalla.
    }
  }

  bool _inProcess(ClassEntry e) =>
      e.kind == EntryKind.processing ||
      e.kind == EntryKind.review ||
      e.kind == EntryKind.ongoing;

  bool _isJustified(ClassEntry e, Map<String, JustificationInfo> jmap) =>
      e.kind == EntryKind.absent &&
      jmap[e.session.id]?.status == JustificationStatus.approved;

  List<ClassEntry> _visible(
    CourseAttendance a,
    Map<String, JustificationInfo> jmap,
  ) {
    return a.entries.reversed.where((e) {
      return switch (_filter) {
        1 => e.kind == EntryKind.present,
        2 => e.kind == EntryKind.absent,
        3 => _isJustified(e, jmap),
        4 => _inProcess(e),
        _ => true,
      };
    }).toList();
  }

  Future<void> _justify(
    CourseAttendance a,
    ClassEntry e,
    JustificationInfo? previous,
  ) async {
    final sent = await showJustifySheet(
      context,
      attendance: a,
      entry: e,
      previous: previous,
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Solicitud enviada. El docente la revisará.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(studentCourseAttendanceProvider(widget.courseId));
    final justs =
        ref.watch(myJustificationsProvider).value ??
        const <JustificationInfo>[];
    final jmap = {for (final j in justs) j.sessionId: j};

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
                        onPressed: _back,
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.navy,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Historial de Asistencia',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Actualizar',
                        onPressed: _refresh,
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
                              'No se pudo cargar el historial. Revisa tu conexión.',
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
                    ),
                    data: (a) => a == null
                        ? const Center(
                            child: Text(
                              'No estás matriculado en este curso.',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          )
                        : _content(a, jmap),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(CourseAttendance a, Map<String, JustificationInfo> jmap) {
    final c = a.course;
    final list = _visible(a, jmap);
    final now = DateTime.now();
    final processCount = a.entries.where(_inProcess).length;
    final justifiedCount = a.entries.where((e) => _isJustified(e, jmap)).length;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: _cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c.period.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: const BoxDecoration(
                      color: _chipBlue,
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                    child: Text(
                      'CICLO ${c.period.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                if (c.period.isNotEmpty) const SizedBox(height: 12),
                Text(
                  c.name,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (c.code.isNotEmpty) c.code,
                    if (c.teacherName.trim().isNotEmpty)
                      'Prof. ${c.teacherName.trim()}',
                  ].join(' • '),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _PresentStat(a: a)),
                const SizedBox(width: 12),
                Expanded(
                  child: _AbsentStat(a: a, justified: justifiedCount),
                ),
              ],
            ),
          ),
          if (!c.limited) ...[
            const SizedBox(height: 14),
            CourseLimitBox(attendance: a),
          ],
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(0, 'Todas', a.entries.length),
                const SizedBox(width: 8),
                _chip(1, 'Presentes', a.present),
                const SizedBox(width: 8),
                _chip(2, 'Faltas', a.absent),
                const SizedBox(width: 8),
                _chip(3, 'Justificadas', justifiedCount),
                const SizedBox(width: 8),
                _chip(4, 'En proceso', processCount),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
              child: Center(
                child: Text(
                  a.entries.isEmpty
                      ? 'Aún no hay clases en este curso. Cuando el docente inicie una sesión, aparecerá aquí.'
                      : 'No hay sesiones en esta categoría.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          for (final e in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _EntryCard(
                entry: e,
                justification: jmap[e.session.id],
                now: now,
                onJustify: () => _justify(a, e, jmap[e.session.id]),
                onView: () {
                  final j = jmap[e.session.id];
                  if (j != null) _showRequest(context, j);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(int i, String label, int count) {
    final selected = _filter == i;
    return GestureDetector(
      onTap: () => setState(() => _filter = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? _navyBtn : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? _navyBtn : const Color(0xFFE1E8F4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.18)
                    : _chipBlue,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.navy,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresentStat extends StatelessWidget {
  const _PresentStat({required this.a});

  final CourseAttendance a;

  @override
  Widget build(BuildContext context) {
    final pct = a.percent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Asistencias',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${a.present}',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: _teal,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '/ ${a.held} clases',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct == null
                        ? 0
                        : (pct / 100).clamp(0.0, 1.0).toDouble(),
                    minHeight: 7,
                    color: _teal,
                    backgroundColor: const Color(0xFFD5E0F2),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                pct == null ? '—' : '${pct.round()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AbsentStat extends StatelessWidget {
  const _AbsentStat({required this.a, required this.justified});

  final CourseAttendance a;
  final int justified;

  @override
  Widget build(BuildContext context) {
    final unjustified = a.absent - justified;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inasistencias',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _red,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _two(a.absent),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: _red,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'total',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '$unjustified sin just.',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _red,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '• $justified just.',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.green,
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

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.justification,
    required this.now,
    required this.onJustify,
    required this.onView,
  });

  final ClassEntry entry;
  final JustificationInfo? justification;
  final DateTime now;
  final VoidCallback onJustify;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final s = e.session;
    final j = justification;
    final absent = e.kind == EntryKind.absent;
    final jState = absent ? justifyStateOf(e, j, now) : null;
    final justified = jState == JustifyState.approved;

    final (accent, pillBg, pillFg, pillText, pillIcon) = justified
        ? (
            _amber,
            _amberBg,
            _amberFg,
            'Falta Justificada',
            Icons.verified_user_outlined,
          )
        : switch (e.kind) {
            EntryKind.present => (
              _teal,
              const Color(0xFF86EFD9),
              const Color(0xFF065F52),
              'Presente',
              Icons.check_circle,
            ),
            EntryKind.absent => (
              _red,
              _redBg,
              _red,
              'Falta',
              Icons.cancel_outlined,
            ),
            EntryKind.processing => (
              const Color(0xFF1F5A8C),
              _chipBlue,
              AppColors.navy,
              'En validación',
              Icons.schedule,
            ),
            EntryKind.review => (
              _amber,
              _amberBg,
              _amberFg,
              'En revisión',
              Icons.rate_review_outlined,
            ),
            EntryKind.ongoing => (
              _teal,
              _soft,
              AppColors.navy,
              'En curso',
              Icons.sensors,
            ),
          };

    String? line;
    IconData lineIcon = Icons.info_outline;
    final claim = e.claim;
    if (e.kind == EntryKind.present && claim != null) {
      final marked = DateTime.fromMillisecondsSinceEpoch(
        claim.scannedAt + claim.clockOffsetMs,
      );
      final method = claim.method == 'pin' ? 'Código manual' : 'QR dinámico';
      line =
          '$method${claim.timeVerified ? '' : ' (sin conexión)'} • ${jHm(marked)}';
      lineIcon = claim.method == 'pin' ? Icons.dialpad : Icons.qr_code_2;
    } else if (e.note != null && !justified) {
      line = e.note;
    }

    final subtitle = [
      '${jHm(s.startsAt)} - ${jHm(s.endsAt)}',
      if (s.room.isNotEmpty) s.room,
    ].join(' • ');

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
              padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
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
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'SESIÓN ${e.number}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: accent,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '  •  ${jDateLine(s.startsAt)}',
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              style: const TextStyle(
                                fontSize: 11.5,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Sesión de clase',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 12.5,
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
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: pillBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(pillIcon, size: 14, color: pillFg),
                            const SizedBox(width: 4),
                            Text(
                              pillText,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: pillFg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (line != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: e.kind == EntryKind.absent
                            ? _redBg
                            : const Color(0xFFF3F6FC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            lineIcon,
                            size: 17,
                            color: e.kind == EntryKind.absent
                                ? _red
                                : AppColors.navy,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              line,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: e.kind == EntryKind.absent
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: e.kind == EntryKind.absent
                                    ? _red
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (jState != null) ..._justifyFooter(jState),
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

  List<Widget> _justifyFooter(JustifyState st) {
    final j = justification;
    final left = justifyDeadline(entry.session.endsAt).difference(now);

    Widget box({required Color bg, Color? border, required Widget child}) =>
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: border == null ? null : Border.all(color: border),
          ),
          child: child,
        );

    switch (st) {
      case JustifyState.approved:
        return [
          box(
            bg: _mint,
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 18,
                  color: Color(0xFF065F52),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Constancia #${j?.code ?? ''} • Aprobada por el docente',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF065F52),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onView,
                  child: const Text(
                    'Ver',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ];
      case JustifyState.pending:
        return [
          box(
            bg: _amberBg,
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 18, color: _amberFg),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Justificación en revisión',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _amberFg,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onView,
                  child: const Text(
                    'Ver',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ];
      case JustifyState.rejected:
      case JustifyState.retry:
        final retry = st == JustifyState.retry;
        return [
          box(
            bg: _redBg,
            border: _redBorder,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  j == null || j.decisionNote.isEmpty
                      ? 'Justificación rechazada'
                      : 'Justificación rechazada: ${j.decisionNote}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _red,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (retry)
                      FilledButton(
                        onPressed: onJustify,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Volver a solicitar'),
                      )
                    else
                      const Text(
                        'Plazo vencido',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _red,
                        ),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: onView,
                      child: const Text(
                        'Ver',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ];
      case JustifyState.canJustify:
        return [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: _amberFg),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Quedan ${jLeft(left)} para justificar',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _amberFg,
                    ),
                  ),
                ),
                Material(
                  color: _chipBlue,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onJustify,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Justificar',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: AppColors.navy,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];
      case JustifyState.expired:
        return [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: _red),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Plazo vencido (sin justificar)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _red,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF1F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Inapelable',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8A97A6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];
    }
  }
}
