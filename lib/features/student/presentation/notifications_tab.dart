import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/notifications_data.dart';

const _red = Color(0xFFD92D20);
const _redBg = Color(0xFFFCE8E8);
const _redBorder = Color(0xFFF3C6C6);
const _teal = Color(0xFF066A5C);
const _mint = Color(0xFFD7F5EA);
const _mintStrong = Color(0xFF9DEBD9);
const _blueBg = Color(0xFFE3EBFA);
const _orange = Color(0xFFD9730D);
const _orangeBg = Color(0xFFFFE6CC);

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

class NotificationsTab extends ConsumerStatefulWidget {
  const NotificationsTab({super.key});

  @override
  ConsumerState<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends ConsumerState<NotificationsTab> {
  int _filter = 0; // 0 todas, 1 alertas, 2 académicas, 3 sistema

  void _soon(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$text (próximamente)')));
  }

  bool _matches(AppNotification n) => switch (_filter) {
    1 => n.category == NotificationCategory.alert,
    2 => n.category == NotificationCategory.academic,
    3 => n.category == NotificationCategory.system,
    _ => true,
  };

  void _handleAction(AppNotification n) {
    ref.read(notificationsProvider.notifier).markRead(n.id);
    switch (n.kind) {
      case NotificationKind.sessionOpen:
        context.push('/student/course/${n.courseId}/scan');
      case NotificationKind.justifyDeadline:
        context.push('/student/justifications');
      default:
        break;
    }
  }

  Widget _card(AppNotification n) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _NotificationCard(
      n: n,
      onTap: () => ref.read(notificationsProvider.notifier).markRead(n.id),
      onAction: () => _handleAction(n),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);
    final unread = unreadCount(all);

    final visible = all.where(_matches).toList();
    final pinned = visible
        .where((n) => n.group == NotificationGroup.pinned)
        .toList();
    final today = visible
        .where((n) => n.group == NotificationGroup.today)
        .toList();
    final earlier = visible
        .where((n) => n.group == NotificationGroup.earlier)
        .toList();

    int countOf(NotificationCategory c) =>
        all.where((n) => n.category == c).length;

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
            'Alertas (${countOf(NotificationCategory.alert)})',
            'Académicas (${countOf(NotificationCategory.academic)})',
            'Sistema (${countOf(NotificationCategory.system)})',
          ],
          onChanged: (i) => setState(() => _filter = i),
        ),
        const SizedBox(height: 16),
        if (visible.isEmpty)
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
              onOpen: () {
                notifier.markRead(n.id);
                context.push('/student/course/${n.courseId}');
              },
              onJustify: () {
                notifier.markRead(n.id);
                context.push('/student/justifications');
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
                  color: index == i ? const Color(0xFF0A2F52) : _blueBg,
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
// Alerta crítica
// ---------------------------------------------------------------------------
class _CriticalCard extends StatelessWidget {
  const _CriticalCard({
    required this.n,
    required this.onTap,
    required this.onOpen,
    required this.onJustify,
  });

  final AppNotification n;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final VoidCallback onJustify;

  @override
  Widget build(BuildContext context) {
    // Las cifras salen del curso (mismos datos que el detalle y el historial).
    final info = n.critical;
    if (info == null) return const SizedBox.shrink();
    final pct = info.held == 0 ? 0 : (info.absences * 100 / info.held).round();
    const limit = 20;
    final remaining = info.maxAbsences - info.absences;
    final name = info.courseName;
    final ratio = (pct / limit).clamp(0.0, 1.0).toDouble();

    final String explanation;
    if (remaining >= 2) {
      explanation =
          'Te quedan $remaining faltas permitidas. Cuida tu asistencia para no perder el derecho a examen.';
    } else if (remaining == 1) {
      explanation = 'Te queda solo 1 falta permitida. Si faltas a una clase más sin justificar, quedarás automáticamente inhabilitado de presentar el examen final.';
    } else if (remaining == 0) {
      explanation = 'Ya usaste todas tus faltas permitidas. Una inasistencia más sin justificar te inhabilitará para presentar el examen final.';
    } else {
      explanation =
          'Superaste el límite de faltas permitidas. Consulta con tu docente.';
    }

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
                                    'ALERTA CRÍTICA • LÍMITE PRÓXIMO',
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
                            'Estás cerca de perder el curso $name: $pct% de fallas, el límite es $limit%',
                            style: const TextStyle(
                              fontSize: 22,
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
                                        'Tolerancia de inasistencias',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.navy,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '$pct% / $limit% (${remaining <= 1 ? 'Crítico' : 'Riesgo'})',
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
                                Text(
                                  explanation,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.45,
                                    color: Color(0xFF3D4B5C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton(
                            onPressed: onOpen,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0A2F52),
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Ver detalle del curso',
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
                            onPressed: onJustify,
                            icon: const Icon(
                              Icons.assignment_late_outlined,
                              size: 19,
                              color: _red,
                            ),
                            label: const Text(
                              'Justificar inasistencia',
                              style: TextStyle(
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
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.n,
    required this.onTap,
    required this.onAction,
  });

  final AppNotification n;
  final VoidCallback onTap;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final (icon, fg, bg, statusDot) = switch (n.kind) {
      NotificationKind.sessionOpen => (
        Icons.qr_code_scanner,
        _teal,
        _mintStrong,
        true,
      ),
      NotificationKind.attendanceOk => (
        Icons.check_circle,
        _teal,
        _blueBg,
        false,
      ),
      NotificationKind.classReminder => (
        Icons.calendar_month_outlined,
        AppColors.navy,
        _blueBg,
        false,
      ),
      NotificationKind.justifyDeadline => (
        Icons.pending_actions,
        _orange,
        _orangeBg,
        false,
      ),
      _ => (Icons.cloud_done_outlined, AppColors.navy, _blueBg, false),
    };

    // En estos dos avisos la hora va abajo, junto al botón.
    final timeInHeader =
        n.kind != NotificationKind.sessionOpen &&
        n.kind != NotificationKind.justifyDeadline;

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
                        color: bg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 23, color: fg),
                    ),
                    if (statusDot)
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
                          if (timeInHeader)
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
                                  color: Color(0xFF0A2F52),
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
                      ..._footer(),
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

  List<Widget> _footer() {
    switch (n.kind) {
      case NotificationKind.sessionOpen:
        return [
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule, size: 15, color: AppColors.textMuted),
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
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: const Text('Escanear ahora'),
                style: FilledButton.styleFrom(
                  backgroundColor: _teal,
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
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ];
      case NotificationKind.justifyDeadline:
        return [
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.history, size: 15, color: AppColors.textMuted),
              const SizedBox(width: 5),
              Text(
                n.timeLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: _blueBg,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onAction,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.attach_file, size: 17, color: AppColors.navy),
                      SizedBox(width: 6),
                      Text(
                        'Adjuntar certificado',
                        style: TextStyle(
                          fontSize: 13,
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
        ];
      case NotificationKind.attendanceOk:
        return [
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [for (final c in n.chips) _InfoChip(c)],
          ),
        ];
      default:
        return const [];
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.chip);

  final NotificationChip chip;

  @override
  Widget build(BuildContext context) {
    final green = chip.tone == ChipTone.green;
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
