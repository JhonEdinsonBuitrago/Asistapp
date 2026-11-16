import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../attendance/data/local_session_store.dart';
import '../data/teacher_notifications_data.dart';

const _red = Color(0xFFD92D20);
const _redDark = Color(0xFFB3261E);
const _redBg = Color(0xFFFCE8E8);
const _redBorder = Color(0xFFF3C6C6);
const _teal = Color(0xFF066A5C);
const _mint = Color(0xFFD7F5EA);
const _mintStrong = Color(0xFF9DEBD9);
const _blueBg = Color(0xFFE3EBFA);
const _orange = Color(0xFFD9730D);
const _orangeBg = Color(0xFFFFE6CC);
const _amberFg = Color(0xFFB45309);
const _amberBg = Color(0xFFFFE8CC);
const _navyBtn = Color(0xFF0A2F52);

const _cardShadow = [
  BoxShadow(color: Color(0x120B3A5E), blurRadius: 16, offset: Offset(0, 6)),
];

List<InlineSpan> _spans(String text) {
  final parts = text.split('**');
  return [
    for (var i = 0; i < parts.length; i++)
      TextSpan(
        text: parts[i],
        style: i.isOdd
            ? const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              )
            : null,
      ),
  ];
}

class TeacherNotificationsTab extends ConsumerStatefulWidget {
  const TeacherNotificationsTab({super.key});

  @override
  ConsumerState<TeacherNotificationsTab> createState() =>
      _TeacherNotificationsTabState();
}

class _TeacherNotificationsTabState
    extends ConsumerState<TeacherNotificationsTab> {
  final _store = LocalSessionStore();
  Timer? _timer;
  int _ticks = 0;
  LocalSession? _active; // sesión en curso en este dispositivo
  int _filter = 0; // 0 todas, 1 alertas, 2 clases, 3 sistema

  @override
  void initState() {
    super.initState();
    _loadActive();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _ticks++;
      if (_ticks % 5 == 0) {
        _loadActive();
      } else if (_active != null && mounted) {
        setState(() {}); // refresca la cuenta regresiva
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Busca si hay una sesión en curso en este dispositivo.
  Future<void> _loadActive() async {
    final s = await _store.load();
    if (!mounted) return;
    final alive =
        s != null &&
        s.endsAtMs > DateTime.now().millisecondsSinceEpoch + s.offsetMs;
    final next = alive ? s : null;
    if (_active?.id != next?.id || _active?.endsAtMs != next?.endsAtMs) {
      setState(() => _active = next);
    }
  }

  void _soon(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$text (próximamente)')));
  }

  bool _matches(TeacherNotification n) => switch (_filter) {
    1 => n.category == TeacherNotificationCategory.alert,
    2 => n.category == TeacherNotificationCategory.classes,
    3 => n.category == TeacherNotificationCategory.system,
    _ => true,
  };

  void _handleAction(TeacherNotification n) {
    ref.read(teacherNotificationsProvider.notifier).markRead(n.id);
    switch (n.kind) {
      case TeacherNotificationKind.classToday:
        context.push('/teacher/course/${n.courseId}/session');
      case TeacherNotificationKind.reviewPending:
      case TeacherNotificationKind.lateSync:
        context.push('/teacher/session');
      case TeacherNotificationKind.justifyPending:
        context.push('/teacher/justifications');
      default:
        break;
    }
  }

  Widget _card(TeacherNotification n) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _NotificationCard(
      n: n,
      onTap: () =>
          ref.read(teacherNotificationsProvider.notifier).markRead(n.id),
      onAction: () => _handleAction(n),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(teacherNotificationsProvider);
    final notifier = ref.read(teacherNotificationsProvider.notifier);
    final unread = teacherUnreadCount(all);

    final visible = all.where(_matches).toList();
    final pinned = visible
        .where((n) => n.group == TeacherNotificationGroup.pinned)
        .toList();
    final today = visible
        .where((n) => n.group == TeacherNotificationGroup.today)
        .toList();
    final earlier = visible
        .where((n) => n.group == TeacherNotificationGroup.earlier)
        .toList();

    int countOf(TeacherNotificationCategory c) =>
        all.where((n) => n.category == c).length;

    final active = _active;
    final showActive = active != null && (_filter == 0 || _filter == 2);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _Header(
          unread: unread,
          onMarkAll: unread == 0 ? null : notifier.markAllRead,
        ),
        const SizedBox(height: 14),
        _Filters(
          index: _filter,
          labels: [
            'Todas (${all.length})',
            'Alertas (${countOf(TeacherNotificationCategory.alert)})',
            'Clases (${countOf(TeacherNotificationCategory.classes)})',
            'Sistema (${countOf(TeacherNotificationCategory.system)})',
          ],
          onChanged: (i) => setState(() => _filter = i),
        ),
        const SizedBox(height: 16),
        if (showActive)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _ActiveSessionCard(
              session: active,
              onOpen: () => context.push('/teacher/session'),
            ),
          ),
        if (visible.isEmpty && !showActive)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No hay notificaciones en esta categoría.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ),
        for (final n in pinned)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: _CriticalCard(
              n: n,
              onTap: () => notifier.markRead(n.id),
              onStats: () {
                notifier.markRead(n.id);
                context.push('/teacher/course/${n.courseId}/stats');
              },
              onStudent: () {
                notifier.markRead(n.id);
                context.push(
                  '/teacher/course/${n.courseId}/student/${n.studentId}',
                );
              },
            ),
          ),
        if (today.isNotEmpty) ...[
          const _SectionLabel('HOY', trailing: 'Recientes'),
          for (final n in today) _card(n),
        ],
        if (earlier.isNotEmpty) ...[
          const SizedBox(height: 6),
          const _SectionLabel('AYER Y ANTERIORES'),
          for (final n in earlier) _card(n),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Cabecera y filtros
// ---------------------------------------------------------------------------
class _Header extends StatelessWidget {
  const _Header({required this.unread, required this.onMarkAll});

  final int unread;
  final VoidCallback? onMarkAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Actividad',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(width: 10),
        if (unread > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: const BoxDecoration(
              color: _blueBg,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: Text(
              '$unread ${unread == 1 ? 'nueva' : 'nuevas'}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
          ),
        const Spacer(),
        Opacity(
          opacity: onMarkAll == null ? 0.5 : 1,
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFD3DDF0)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onMarkAll,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.done_all, size: 16, color: AppColors.navy),
                    SizedBox(width: 6),
                    Text(
                      'Marcar leídas',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
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

class _Filters extends StatelessWidget {
  const _Filters({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: index == i ? _navyBtn : _blueBg,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: index == i ? Colors.white : AppColors.navy,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sesión en curso (dato real)
// ---------------------------------------------------------------------------
class _ActiveSessionCard extends StatelessWidget {
  const _ActiveSessionCard({required this.session, required this.onOpen});

  final LocalSession session;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch + session.offsetMs;
    final left = Duration(milliseconds: math.max(0, session.endsAtMs - now));
    final mm = left.inMinutes.toString().padLeft(2, '0');
    final ss = (left.inSeconds % 60).toString().padLeft(2, '0');
    final place = session.room.isEmpty ? '' : '${session.room} • ';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _mint,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _mintStrong),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: _mintStrong,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sensors, size: 22, color: _teal),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Sesión de asistencia en curso',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF065F52),
                  ),
                ),
              ),
              const CircleAvatar(radius: 5, backgroundColor: _teal),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            session.courseName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${place}termina en $mm:$ss',
            style: const TextStyle(fontSize: 13, color: Color(0xFF0B5C47)),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Volver a la sesión'),
            iconAlignment: IconAlignment.end,
            style: FilledButton.styleFrom(
              backgroundColor: _teal,
              minimumSize: const Size.fromHeight(48),
              textStyle: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Alerta crítica
// ---------------------------------------------------------------------------
class _CriticalCard extends StatelessWidget {
  const _CriticalCard({
    required this.n,
    required this.onTap,
    required this.onStats,
    required this.onStudent,
  });

  final TeacherNotification n;
  final VoidCallback onTap;
  final VoidCallback onStats;
  final VoidCallback onStudent;

  @override
  Widget build(BuildContext context) {
    final info = n.critical;
    if (info == null) return const SizedBox.shrink();

    final pct = info.total == 0 ? 0.0 : info.count * 100 / info.total;
    final ratio = info.total == 0
        ? 0.0
        : (info.count / info.total).clamp(0.0, 1.0).toDouble();
    final first = info.students.isEmpty
        ? 'estudiante'
        : info.students.first.name.trim().split(RegExp(r'\s+')).first;

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(22)),
        boxShadow: _cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: _redBg,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 5, color: _red),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9D3D3),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _red.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 22,
                                  color: _red,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    'ALERTA CRÍTICA • ESTUDIANTES EN EL LÍMITE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: _red,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  n.timeLabel,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF9B4A4A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${info.count} ${info.count == 1 ? 'estudiante está' : 'estudiantes están'} en o sobre el límite de faltas en ${info.courseName}',
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _redBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Estudiantes en riesgo crítico',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.navy,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${info.count} / ${info.total} (${pct.toStringAsFixed(1)}%)',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: _red,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: ratio,
                                    minHeight: 8,
                                    color: _red,
                                    backgroundColor: const Color(0xFFE6ECF7),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                for (final s in info.students)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        Icon(
                                          s.exceeded
                                              ? Icons.error
                                              : Icons.warning_amber_rounded,
                                          size: 16,
                                          color: _red,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            s.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.navy,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${s.absences} de ${s.held} • ${s.exceeded ? 'Excedido' : 'Al límite'}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: _red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  'El máximo permitido es ${info.maxAbsences} faltas. Quien lo supere pierde el derecho a la evaluación final según el reglamento académico.',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    height: 1.45,
                                    color: Color(0xFF3D4B5C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton(
                            onPressed: onStats,
                            style: FilledButton.styleFrom(
                              backgroundColor: _navyBtn,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Ver estadísticas del curso',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 18),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: onStudent,
                            icon: const Icon(
                              Icons.person_search_outlined,
                              size: 19,
                              color: _red,
                            ),
                            label: Text(
                              'Ver a $first',
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(50),
                              side: const BorderSide(color: Color(0xFFE6D3D3)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
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

// ---------------------------------------------------------------------------
// Aviso estándar
// ---------------------------------------------------------------------------
({
  IconData icon,
  Color fg,
  Color bg,
  bool dot,
  String? action,
  IconData actionIcon,
  bool primary,
})
_styleOf(TeacherNotificationKind k) {
  switch (k) {
    case TeacherNotificationKind.classToday:
      return (
        icon: Icons.sensors,
        fg: _teal,
        bg: _mintStrong,
        dot: true,
        action: 'Iniciar sesión',
        actionIcon: Icons.sensors,
        primary: true,
      );
    case TeacherNotificationKind.classTomorrow:
      return (
        icon: Icons.calendar_month_outlined,
        fg: AppColors.navy,
        bg: _blueBg,
        dot: false,
        action: null,
        actionIcon: Icons.arrow_forward,
        primary: false,
      );
    case TeacherNotificationKind.reviewPending:
      return (
        icon: Icons.rate_review_outlined,
        fg: _amberFg,
        bg: _amberBg,
        dot: false,
        action: 'Revisar registros',
        actionIcon: Icons.fact_check_outlined,
        primary: false,
      );
    case TeacherNotificationKind.justifyPending:
      return (
        icon: Icons.pending_actions,
        fg: _orange,
        bg: _orangeBg,
        dot: false,
        action: 'Revisar',
        actionIcon: Icons.assignment_outlined,
        primary: false,
      );
    case TeacherNotificationKind.lateSync:
      return (
        icon: Icons.hourglass_top,
        fg: _orange,
        bg: _orangeBg,
        dot: false,
        action: 'Revisar registros',
        actionIcon: Icons.fact_check_outlined,
        primary: false,
      );
    case TeacherNotificationKind.sessionClosed:
      return (
        icon: Icons.check_circle,
        fg: _teal,
        bg: _blueBg,
        dot: false,
        action: null,
        actionIcon: Icons.arrow_forward,
        primary: false,
      );
    case TeacherNotificationKind.offlineSynced:
      return (
        icon: Icons.cloud_done_outlined,
        fg: AppColors.navy,
        bg: _blueBg,
        dot: false,
        action: null,
        actionIcon: Icons.arrow_forward,
        primary: false,
      );
    case TeacherNotificationKind.weeklySummary:
      return (
        icon: Icons.insights,
        fg: AppColors.navy,
        bg: _blueBg,
        dot: false,
        action: null,
        actionIcon: Icons.arrow_forward,
        primary: false,
      );
    case TeacherNotificationKind.critical:
      return (
        icon: Icons.warning_amber_rounded,
        fg: _red,
        bg: _redBg,
        dot: false,
        action: null,
        actionIcon: Icons.arrow_forward,
        primary: false,
      );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.n,
    required this.onTap,
    required this.onAction,
  });

  final TeacherNotification n;
  final VoidCallback onTap;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final st = _styleOf(n.kind);
    final hasAction = st.action != null;

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(22)),
        boxShadow: _cardShadow,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: st.bg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(st.icon, size: 23, color: st.fg),
                    ),
                    if (st.dot)
                      Positioned(
                        right: -1,
                        top: -1,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _teal,
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                                height: 1.25,
                              ),
                            ),
                          ),
                          if (!hasAction)
                            Padding(
                              padding: const EdgeInsets.only(left: 8, top: 2),
                              child: Text(
                                n.timeLabel,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          if (n.unread)
                            Padding(
                              padding: const EdgeInsets.only(left: 8, top: 5),
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(
                                  color: _navyBtn,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text.rich(
                        TextSpan(children: _spans(n.body)),
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: Color(0xFF3D4B5C),
                        ),
                      ),
                      if (hasAction)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.schedule,
                                size: 15,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  n.timeLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _ActionButton(
                                label: st.action!,
                                icon: st.actionIcon,
                                primary: st.primary,
                                onTap: onAction,
                              ),
                            ],
                          ),
                        ),
                      if (n.chips.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [for (final c in n.chips) _InfoChip(c)],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: _teal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
    return Material(
      color: _blueBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: AppColors.navy),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.chip);

  final TeacherChip chip;

  @override
  Widget build(BuildContext context) {
    final green = chip.tone == TeacherChipTone.green;
    final fg = green ? _teal : AppColors.navy;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: green ? _mint : _blueBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (green) ...[
            Icon(Icons.check_circle_outline, size: 14, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            chip.label,
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
