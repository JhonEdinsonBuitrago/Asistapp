import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attendance/data/attendance_repository.dart';
import 'course_repository.dart';
import 'course_stats_data.dart';
import 'enrollment_repository.dart';

/// Un curso activo con sus estudiantes y sus sesiones.
class CourseSnapshot {
  const CourseSnapshot({
    required this.course,
    required this.enrolled,
    required this.sessions,
  });

  final CreatedCourse course;
  final List<EnrolledStudent> enrolled;
  final List<SessionAttendance> sessions;

  Set<String> get enrolledIds => {for (final e in enrolled) e.id};

  CourseStatsVm get stats => buildRealStats(
    course: course,
    enrolled: enrolled,
    sessions: sessions,
    now: DateTime.now(),
  );
}

class TeacherOverview {
  const TeacherOverview(this.courses);

  final List<CourseSnapshot> courses;

  /// Asistencia global (%), o null si todavía no hay datos.
  double? get attendance {
    var marks = 0;
    var attended = 0;
    for (final c in courses) {
      final ids = c.enrolledIds;
      marks += ids.length * c.sessions.length;
      for (final s in c.sessions) {
        attended += s.presentIds.where(ids.contains).length;
      }
    }
    return marks == 0 ? null : attended * 100 / marks;
  }

  int _since(DateTime from) => courses.fold<int>(
    0,
    (sum, c) =>
        sum + c.sessions.where((s) => !s.startsAt.isBefore(from)).length,
  );

  int get sessionsToday {
    final n = DateTime.now();
    return _since(DateTime(n.year, n.month, n.day));
  }

  int get sessionsWeek {
    final n = DateTime.now();
    final monday = DateTime(
      n.year,
      n.month,
      n.day,
    ).subtract(Duration(days: n.weekday - 1));
    return _since(monday);
  }
}

/// Cursos activos del docente con su asistencia (inicio, perfil y avisos).
final teacherOverviewProvider = FutureProvider.autoDispose<TeacherOverview>((
  ref,
) async {
  final courses = await ref.watch(myCoursesProvider.future);
  final active = courses.where((c) => !c.isDraft).toList();

  final list = await Future.wait(
    active.map((c) async {
      final enrolled = await ref.watch(enrolledStudentsProvider(c.id).future);
      final sessions = await ref.watch(courseAttendanceProvider(c.id).future);
      return CourseSnapshot(course: c, enrolled: enrolled, sessions: sessions);
    }),
  );

  return TeacherOverview(list);
});

/// Vuelve a leer las sesiones y los registros.
void refreshTeacherData(WidgetRef ref) {
  ref.invalidate(courseAttendanceProvider);
  ref.invalidate(teacherOverviewProvider);
}
