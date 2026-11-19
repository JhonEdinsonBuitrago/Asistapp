import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../justifications/data/justification_data.dart';
import 'student_courses_data.dart';

enum NotificationCategory { alert, academic, system }

enum NotificationKind {
  critical,
  sessionOpen,
  attendanceOk,
  classReminder,
  justifyDeadline,
  offlineSynced,
}

enum NotificationGroup { pinned, today, earlier }

enum ChipTone { green, blue }

class NotificationChip {
  const NotificationChip(this.label, this.tone);

  final String label;
  final ChipTone tone;
}

class CriticalCourseInfo {
  const CriticalCourseInfo({
    required this.courseName,
    required this.absences,
    required this.held,
    required this.maxAbsences,
  });

  final String courseName;
  final int absences;
  final int held;
  final int maxAbsences;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.category,
    required this.group,
    required this.title,
    required this.body,
    required this.timeLabel,
    this.courseId,
    this.unread = false,
    this.chips = const [],
    this.critical,
  });

  final String id;
  final NotificationKind kind;
  final NotificationCategory category;
  final NotificationGroup group;
  final String title;

  /// El texto entre ** ** se muestra en negrita.
  final String body;
  final String timeLabel;
  final String? courseId;
  final bool unread;
  final List<NotificationChip> chips;
  final CriticalCourseInfo? critical;

  AppNotification copyWith({bool? unread}) => AppNotification(
    id: id,
    kind: kind,
    category: category,
    group: group,
    title: title,
    body: body,
    timeLabel: timeLabel,
    courseId: courseId,
    unread: unread ?? this.unread,
    chips: chips,
    critical: critical,
  );
}

String _two(int n) => n.toString().padLeft(2, '0');

String _hm12(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${_two(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _when(DateTime d, DateTime now) {
  if (_sameDay(d, now)) return 'Hoy, ${_hm12(d)}';
  if (_sameDay(d, now.subtract(const Duration(days: 1))))
    return 'Ayer, ${_hm12(d)}';
  return '${_two(d.day)}/${_two(d.month)}, ${_hm12(d)}';
}

NotificationGroup _groupOf(DateTime d, DateTime now) =>
    _sameDay(d, now) ? NotificationGroup.today : NotificationGroup.earlier;

/// Genera los avisos con los datos reales del estudiante.
List<AppNotification> _compose(
  StudentOverview? ov,
  List<JustificationInfo> justs,
  DateTime now,
) {
  if (ov == null) return const [];
  final out = <AppNotification>[];

  // 1) Alerta crítica: el curso en peor estado.
  CourseAttendance? worst;
  for (final c in ov.courses) {
    if (c.course.limited || c.status == CourseStatus.safe) continue;
    if (worst == null || c.remaining < worst.remaining) worst = c;
  }
  if (worst != null) {
    out.add(
      AppNotification(
        id: 'critical-${worst.course.id}-${worst.absent}',
        kind: NotificationKind.critical,
        category: NotificationCategory.alert,
        group: NotificationGroup.pinned,
        title: 'Alerta crítica',
        body: '',
        timeLabel: 'Actualizado ahora',
        courseId: worst.course.id,
        unread: true,
        critical: CriticalCourseInfo(
          courseName: worst.course.name,
          absences: worst.absent,
          held: worst.held,
          maxAbsences: worst.course.maxAbsences,
        ),
      ),
    );
  }

  for (final c in ov.courses) {
    for (final e in c.entries) {
      // 2) Sesión abierta en la que aún no has registrado.
      if (e.kind == EntryKind.ongoing) {
        final room = e.session.room.isEmpty ? '' : ' en ${e.session.room}';
        out.add(
          AppNotification(
            id: 'open-${e.session.id}',
            kind: NotificationKind.sessionOpen,
            category: NotificationCategory.academic,
            group: NotificationGroup.today,
            title: '¡Sesión de asistencia abierta!',
            body:
                'Se abrió el registro de **${c.course.name}**$room. Puedes registrarte hasta las **${_hm12(e.session.endsAt)}**.',
            timeLabel: _when(e.session.startsAt, now),
            courseId: c.course.id,
            unread: true,
          ),
        );
        continue;
      }

      // 3) Registros confirmados recientemente.
      final claim = e.claim;
      if (claim == null || e.kind != EntryKind.present) continue;
      final at =
          claim.syncedAt ??
          DateTime.fromMillisecondsSinceEpoch(
            claim.scannedAt + claim.clockOffsetMs,
          );
      if (now.difference(at) > const Duration(days: 2)) continue;

      final pct = c.percent;
      out.add(
        AppNotification(
          id: 'ok-${e.session.id}',
          kind: NotificationKind.attendanceOk,
          category: NotificationCategory.academic,
          group: _groupOf(at, now),
          title: 'Asistencia registrada con éxito',
          body: 'Se verificó tu presencia en **${c.course.name}**.',
          timeLabel: _when(at, now),
          courseId: c.course.id,
          unread: true,
          chips: pct == null
              ? const []
              : [
                  NotificationChip(
                    'Asistencia: ${pct.round()}%',
                    ChipTone.green,
                  ),
                ],
        ),
      );

      if (!claim.timeVerified) {
        out.add(
          AppNotification(
            id: 'offline-${e.session.id}',
            kind: NotificationKind.offlineSynced,
            category: NotificationCategory.system,
            group: _groupOf(at, now),
            title: 'Registro sin conexión validado',
            body:
                'La asistencia que guardaste sin conexión en **${c.course.name}** se validó correctamente.',
            timeLabel: _when(at, now),
            courseId: c.course.id,
          ),
        );
      }
    }
  }

  // 4) Faltas que todavía puedes justificar.
  final summary = justifiableSummary(ov, justs, now);
  if (summary.count > 0) {
    final urgent = summary.minHoursLeft < 24;
    out.add(
      AppNotification(
        id: 'justify-${summary.count}',
        kind: NotificationKind.justifyDeadline,
        category: NotificationCategory.alert,
        group: NotificationGroup.today,
        title: urgent
            ? 'Plazo de justificación por vencer'
            : 'Tienes faltas por justificar',
        body: urgent
            ? 'Te quedan **${summary.minHoursLeft} h** para justificar una de tus faltas.'
            : 'Tienes **${summary.count} ${summary.count == 1 ? 'falta' : 'faltas'}** que puedes justificar. El plazo más corto vence en **${summary.minHoursLeft} h**.',
        timeLabel: 'Pendiente',
        unread: true,
      ),
    );
  }

  return out;
}

class NotificationsNotifier extends Notifier<List<AppNotification>> {
  /// Avisos que el estudiante ya leyó (se conserva mientras la app esté abierta).
  final Set<String> _read = {};

  @override
  List<AppNotification> build() {
    final overview = ref.watch(studentOverviewProvider).value;
    final justs =
        ref.watch(myJustificationsProvider).value ??
        const <JustificationInfo>[];
    return [
      for (final n in _compose(overview, justs, DateTime.now()))
        n.copyWith(unread: !_read.contains(n.id)),
    ];
  }

  void markRead(String id) {
    _read.add(id);
    state = [for (final n in state) n.id == id ? n.copyWith(unread: false) : n];
  }

  void markAllRead() {
    for (final n in state) {
      _read.add(n.id);
    }
    state = [for (final n in state) n.copyWith(unread: false)];
  }
}

final notificationsProvider =
    NotifierProvider.autoDispose<NotificationsNotifier, List<AppNotification>>(
      NotificationsNotifier.new,
    );

int unreadCount(List<AppNotification> list) =>
    list.where((n) => n.unread).length;
