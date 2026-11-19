import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../justifications/data/justification_data.dart';
import 'course_stats_data.dart';
import 'teacher_overview_data.dart';
import '../../attendance/data/attendance_repository.dart';

enum TeacherNotificationCategory { alert, classes, system }

enum TeacherNotificationKind {
  critical,
  classToday,
  classTomorrow,
  reviewPending,
  justifyPending,
  sessionClosed,
  offlineSynced,
  lateSync,
  weeklySummary,
}

enum TeacherNotificationGroup { pinned, today, earlier }

enum TeacherChipTone { green, blue }

class TeacherChip {
  const TeacherChip(this.label, this.tone);

  final String label;
  final TeacherChipTone tone;
}

class CriticalStudent {
  const CriticalStudent({
    required this.id,
    required this.name,
    required this.absences,
    required this.held,
    required this.exceeded,
  });

  final String id;
  final String name;
  final int absences;
  final int held;

  /// true = superó el máximo; false = está justo en el límite.
  final bool exceeded;
}

class CriticalInfo {
  const CriticalInfo({
    required this.courseName,
    required this.count,
    required this.total,
    required this.maxAbsences,
    required this.students,
  });

  final String courseName;
  final int count;
  final int total;
  final int maxAbsences;
  final List<CriticalStudent> students;
}

class TeacherNotification {
  const TeacherNotification({
    required this.id,
    required this.kind,
    required this.category,
    required this.group,
    required this.title,
    required this.body,
    required this.timeLabel,
    this.courseId,
    this.studentId,
    this.unread = false,
    this.chips = const [],
    this.critical,
  });

  final String id;
  final TeacherNotificationKind kind;
  final TeacherNotificationCategory category;
  final TeacherNotificationGroup group;
  final String title;

  /// El texto entre ** ** se muestra en negrita.
  final String body;
  final String timeLabel;
  final String? courseId;
  final String? studentId;
  final bool unread;
  final List<TeacherChip> chips;
  final CriticalInfo? critical;

  TeacherNotification copyWith({bool? unread}) => TeacherNotification(
    id: id,
    kind: kind,
    category: category,
    group: group,
    title: title,
    body: body,
    timeLabel: timeLabel,
    courseId: courseId,
    studentId: studentId,
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

TeacherNotificationGroup _groupOf(DateTime d, DateTime now) => _sameDay(d, now)
    ? TeacherNotificationGroup.today
    : TeacherNotificationGroup.earlier;

/// Genera los avisos con los datos reales del docente.
List<TeacherNotification> _compose(
  TeacherOverview? ov,
  List<JustificationInfo> justs,
  DateTime now,
) {
  final out = <TeacherNotification>[];

  if (ov != null) {
    // 1) Alerta crítica: el curso con más estudiantes en o sobre el límite.
    CourseSnapshot? worst;
    CourseStatsVm? worstStats;
    var worstCount = 0;
    for (final c in ov.courses) {
      final st = c.stats;
      if (st.criticalCount > worstCount) {
        worst = c;
        worstStats = st;
        worstCount = st.criticalCount;
      }
    }
    if (worst != null && worstStats != null) {
      final critical = worstStats.students.where((s) => s.isCritical).toList()
        ..sort((a, b) => b.absences.compareTo(a.absences));
      out.add(
        TeacherNotification(
          id: 'critical-${worst.course.id}-$worstCount',
          kind: TeacherNotificationKind.critical,
          category: TeacherNotificationCategory.alert,
          group: TeacherNotificationGroup.pinned,
          title: 'Alerta crítica',
          body: '',
          timeLabel: 'Actualizado ahora',
          courseId: worst.course.id,
          studentId: critical.first.id,
          unread: true,
          critical: CriticalInfo(
            courseName: worst.course.name,
            count: worstCount,
            total: worstStats.students.length,
            maxAbsences: worstStats.maxAbsences,
            students: [
              for (final s in critical.take(3))
                CriticalStudent(
                  id: s.id,
                  name: s.name,
                  absences: s.absences,
                  held: s.held,
                  exceeded: s.absences > worstStats.maxAbsences,
                ),
            ],
          ),
        ),
      );
    }

    for (final c in ov.courses) {
      // 2) Registros que esperan tu decisión.
      final review = c.sessions.fold<int>(0, (s, x) => s + x.reviewCount);
      if (review > 0) {
        out.add(
          TeacherNotification(
            id: 'review-${c.course.id}-$review',
            kind: TeacherNotificationKind.reviewPending,
            category: TeacherNotificationCategory.alert,
            group: TeacherNotificationGroup.today,
            title: 'Registros esperando tu revisión',
            body:
                '**$review ${review == 1 ? 'registro' : 'registros'}** de **${c.course.name}** ${review == 1 ? 'quedó' : 'quedaron'} en revisión y ${review == 1 ? 'necesita' : 'necesitan'} tu decisión.',
            timeLabel: 'Pendiente',
            courseId: c.course.id,
            unread: true,
          ),
        );
      }
    }

    // 3) Sesiones que terminaron en los últimos 3 días.
    final since = now.subtract(const Duration(days: 3));
    final recent = <(CourseSnapshot, SessionAttendance)>[];
    for (final c in ov.courses) {
      for (final s in c.sessions) {
        if (!s.endsAt.isAfter(now) && s.endsAt.isAfter(since))
          recent.add((c, s));
      }
    }
    recent.sort((a, b) => b.$2.endsAt.compareTo(a.$2.endsAt));

    for (final (c, s) in recent.take(4)) {
      final ids = c.enrolledIds;
      final total = ids.length;
      final present = s.presentIds.where(ids.contains).length;
      final pct = total == 0 ? 0 : (present * 100 / total).round();
      final key = '${c.course.id}-${s.startsAt.millisecondsSinceEpoch}';

      out.add(
        TeacherNotification(
          id: 'closed-$key',
          kind: TeacherNotificationKind.sessionClosed,
          category: TeacherNotificationCategory.classes,
          group: _groupOf(s.endsAt, now),
          title: 'Sesión finalizada',
          body: total == 0
              ? '**${c.course.name}**: no hay estudiantes matriculados en el curso.'
              : '**${c.course.name}**: **$present de $total** estudiantes con asistencia confirmada.',
          timeLabel: _when(s.endsAt, now),
          courseId: c.course.id,
          chips: total == 0
              ? const []
              : [
                  TeacherChip('$pct% asistencia', TeacherChipTone.green),
                  TeacherChip(
                    '${total - present} sin confirmar',
                    TeacherChipTone.blue,
                  ),
                ],
        ),
      );

      if (s.offlineCount > 0) {
        out.add(
          TeacherNotification(
            id: 'offline-$key',
            kind: TeacherNotificationKind.offlineSynced,
            category: TeacherNotificationCategory.system,
            group: _groupOf(s.endsAt, now),
            title: 'Registros sin conexión validados',
            body:
                'Se validaron **${s.offlineCount} ${s.offlineCount == 1 ? 'registro' : 'registros'}** hechos sin conexión en **${c.course.name}**.',
            timeLabel: _when(s.endsAt, now),
            courseId: c.course.id,
          ),
        );
      }
    }
  }

  // 4) Justificaciones pendientes, por curso.
  final byCourse = <String, List<JustificationInfo>>{};
  for (final j in justs) {
    if (j.status == JustificationStatus.pending) {
      byCourse.putIfAbsent(j.courseId, () => []).add(j);
    }
  }
  for (final entry in byCourse.entries) {
    final list = entry.value;
    final newest = list
        .map((j) => j.createdAt ?? now)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    out.add(
      TeacherNotification(
        id: 'justify-${entry.key}-${list.length}',
        kind: TeacherNotificationKind.justifyPending,
        category: TeacherNotificationCategory.alert,
        group: _groupOf(newest, now),
        title: 'Justificaciones pendientes',
        body:
            'Tienes **${list.length} ${list.length == 1 ? 'justificación' : 'justificaciones'}** por revisar en **${list.first.courseName}**. Los estudiantes esperan tu respuesta.',
        timeLabel: _when(newest, now),
        courseId: entry.key,
        unread: true,
      ),
    );
  }

  return out;
}

class TeacherNotificationsNotifier extends Notifier<List<TeacherNotification>> {
  /// Avisos que el docente ya leyó (se conserva mientras la app esté abierta).
  final Set<String> _read = {};

  @override
  List<TeacherNotification> build() {
    final overview = ref.watch(teacherOverviewProvider).value;
    final justs =
        ref.watch(teacherJustificationsProvider).value ??
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

final teacherNotificationsProvider =
    NotifierProvider.autoDispose<
      TeacherNotificationsNotifier,
      List<TeacherNotification>
    >(TeacherNotificationsNotifier.new);

int teacherUnreadCount(List<TeacherNotification> list) =>
    list.where((n) => n.unread).length;
