import 'course_repository.dart';
import 'enrollment_repository.dart';

enum CourseTone { excellent, normal, risk, optimal }

enum RosterStatus {
  perfect,
  excellent,
  ok,
  regular,
  attention,
  risk,
  lost,
  none,
}

enum RosterGroup { ok, regular, risk, none }

class RosterStudent {
  const RosterStudent({
    required this.id,
    required this.name,
    required this.code,
    required this.absences,
    required this.attendance,
    this.starred = false,
    this.noData = false,
  });

  final String id;
  final String name;
  final String code;
  final int absences;
  final bool noData;

  /// Porcentaje de asistencia.
  final int attendance;
  final bool starred;

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  RosterStatus status(int maxAbsences) {
    if (noData) return RosterStatus.none;
    if (absences > maxAbsences) return RosterStatus.lost;
    if (attendance < 80) return RosterStatus.risk;
    if (attendance < 85) return RosterStatus.attention;
    if (attendance < 90) return RosterStatus.regular;
    if (attendance >= 100) return RosterStatus.perfect;
    if (attendance >= 95) return RosterStatus.excellent;
    return RosterStatus.ok;
  }

  RosterGroup group(int maxAbsences) {
    if (noData) return RosterGroup.none;
    if (absences > maxAbsences || attendance < 80) return RosterGroup.risk;
    if (attendance < 90) return RosterGroup.regular;
    return RosterGroup.ok;
  }

  String faultsText(int maxAbsences) {
    if (noData) return 'Sin registros aún';
    final base = '$absences ${absences == 1 ? 'falta' : 'faltas'}';
    if (absences > maxAbsences) return '$base (Límite excedido)';
    if (absences > 0 && absences == maxAbsences) return '$base (Al límite)';
    if (absences > 0 && absences == maxAbsences - 1)
      return '$base (1 del límite)';
    return base;
  }
}

class CourseDetailVm {
  const CourseDetailVm({
    required this.id,
    required this.name,
    required this.code,
    required this.cycle,
    required this.heldSessions,
    required this.totalSessions,
    required this.maxAbsences,
    required this.hasClassToday,
    required this.students,
    required this.isSample,
    this.section,
    this.scheduleLabel,
    this.room,
    this.attendance,
    this.facultyDelta,
    this.tone,
  });

  final String id;
  final String name;
  final String code;
  final String? section;
  final String cycle;
  final String? scheduleLabel;
  final String? room;
  final int heldSessions;
  final int totalSessions;

  /// Promedio de asistencia del curso; null si aún no hay sesiones.
  final double? attendance;

  /// Diferencia con el promedio de la facultad, en puntos porcentuales.
  final double? facultyDelta;
  final CourseTone? tone;
  final int maxAbsences;
  final bool hasClassToday;
  final List<RosterStudent> students;
  final bool isSample;

  double get progress => totalSessions == 0 ? 0 : heldSessions / totalSessions;
  int get progressPercent => (progress * 100).round();

  int countOf(RosterGroup g) =>
      students.where((s) => s.group(maxAbsences) == g).length;
}

/// Detalle de un curso real creado por el docente (aún sin matrícula).
RosterStudent rosterFromEnrolled(EnrolledStudent e) => RosterStudent(
  id: e.id,
  name: e.name,
  code: e.code,
  absences: 0,
  attendance: 0,
  noData: true,
);

/// Detalle de un curso real creado por el docente.
CourseDetailVm courseDetailFromCreated(
  CreatedCourse c, {
  List<EnrolledStudent> enrolled = const [],
}) => CourseDetailVm(
  id: c.id,
  name: c.name,
  code: c.code,
  cycle: c.period,
  heldSessions: 0,
  totalSessions: c.totalSessions,
  maxAbsences: c.maxAbsences,
  hasClassToday: false,
  students: enrolled.map(rosterFromEnrolled).toList(),
  isSample: false,
);
