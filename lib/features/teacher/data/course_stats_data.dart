import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attendance/data/attendance_repository.dart';
import 'course_repository.dart';
import 'enrollment_repository.dart';
import 'teacher_course_detail_data.dart';
import 'teacher_mock_data.dart';

enum StatsRisk { exceeded, limit, watch, early, regular, optimal }

String riskLabel(StatsRisk r) => switch (r) {
  StatsRisk.exceeded => 'Límite excedido',
  StatsRisk.limit => 'Al límite',
  StatsRisk.watch => 'En observación',
  StatsRisk.early => 'Alerta temprana',
  StatsRisk.regular => 'Regular',
  StatsRisk.optimal => 'Óptimo',
};

class StatsStudent {
  const StatsStudent({
    required this.id,
    required this.name,
    required this.code,
    required this.absences,
    required this.held,
    required this.maxAbsences,
    this.pendingJustifications = 0,
  });

  final String id;
  final String name;
  final String code;
  final int absences;

  /// Clases dictadas hasta ahora.
  final int held;
  final int maxAbsences;
  final int pendingJustifications;

  double get faultPercent => held == 0 ? 0 : absences * 100 / held;

  /// Riesgo según las faltas que le quedan antes del límite.
  StatsRisk get risk {
    if (absences == 0) return StatsRisk.optimal;
    final remaining = maxAbsences - absences;
    if (remaining < 0) return StatsRisk.exceeded;
    if (remaining == 0) return StatsRisk.limit;
    if (remaining == 1) return StatsRisk.watch;
    if (remaining == 2) return StatsRisk.early;
    if (remaining == 3) return StatsRisk.regular;
    return StatsRisk.optimal;
  }

  bool get isCritical => risk == StatsRisk.exceeded || risk == StatsRisk.limit;
  bool get isAttention => risk == StatsRisk.watch || risk == StatsRisk.early;
  bool get isInOrder => !isCritical && !isAttention;

  String get firstName {
    final w = name.trim().split(RegExp(r'\s+'));
    return w.isEmpty || w.first.isEmpty ? 'estudiante' : w.first;
  }

  String get initials {
    final w = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (w.isEmpty) return '?';
    if (w.length == 1) return w.first[0].toUpperCase();
    return (w.first[0] + w.last[0]).toUpperCase();
  }
}

class CourseStatsVm {
  const CourseStatsVm({
    required this.id,
    required this.name,
    required this.code,
    required this.cycle,
    required this.faculty,
    required this.week,
    required this.weekActive,
    required this.held,
    required this.total,
    required this.maxAbsences,
    required this.marks,
    required this.attendedMarks,
    required this.justified,
    required this.unjustified,
    required this.weekly,
    required this.weeklyStart,
    required this.students,
    required this.isSample,
    this.section,
    this.rate,
    this.facultyDelta,
  });

  final String id;
  final String name;
  final String code;
  final String? section;
  final String cycle;
  final String faculty;
  final int week;
  final bool weekActive;
  final int held;
  final int total;
  final int maxAbsences;

  /// Total de marcas posibles: estudiantes × clases dictadas.
  final int marks;
  final int attendedMarks;
  final int justified;
  final int unjustified;

  /// Tasa general de asistencia (%), o null si aún no hay datos.
  final double? rate;
  final double? facultyDelta;

  /// Asistencia (%) por semana; null = semana sin clases.
  final List<double?> weekly;

  /// Número de la primera semana de [weekly] (empieza en 1).
  final int weeklyStart;
  final List<StatsStudent> students;
  final bool isSample;

  int get criticalCount => students.where((s) => s.isCritical).length;
  int get attentionCount => students.where((s) => s.isAttention).length;
  int get inOrderCount => students.where((s) => s.isInOrder).length;
  double get progress =>
      total == 0 ? 0 : (held / total).clamp(0.0, 1.0).toDouble();
}

// ---------------------------------------------------------------------------
// DATOS DE EJEMPLO
// ---------------------------------------------------------------------------
const _samplePending = <String, int>{'a5': 2}; // Diego Palacios (mockup)

const _arqWeekly = <double?>[96, null, 97, 88, 80, 96, null, 88, 92, 99];

List<double?> _generatedWeekly(int weeks, double base, int seed) {
  const pattern = [4.0, 5.0, 1.0, -3.0, -8.0, 4.0, 2.0, -4.0, 1.0, 6.0];
  return List<double?>.generate(
    weeks,
    (i) => (base + pattern[(i + seed) % pattern.length])
        .clamp(55.0, 100.0)
        .toDouble(),
  );
}

CourseStatsVm? sampleCourseStats(String id, DateTime now) {
  final d = sampleCourseDetail(id, now);
  final course = sampleTeacherCourses.where((c) => c.id == id).firstOrNull;
  if (d == null || course == null) return null;

  final held = d.heldSessions;
  final students = [
    for (final s in d.students)
      StatsStudent(
        id: s.id,
        name: s.name,
        code: s.code,
        absences: s.absences,
        held: held,
        maxAbsences: d.maxAbsences,
        pendingJustifications: _samplePending[s.id] ?? 0,
      ),
  ];

  final marks = students.length * held;
  final rate = d.attendance ?? 0.0;
  final absentMarks = (marks * (1 - rate / 100)).round();
  final justified = (absentMarks * 2 / 3).round();

  final perWeek = course.weekdays.isEmpty ? 1 : course.weekdays.length;
  final week = held ~/ perWeek + 1;
  final seed = id.codeUnits.fold<int>(0, (a, b) => a + b) % 7;
  final all = id == 'arq' ? _arqWeekly : _generatedWeekly(week, rate, seed);
  final start = all.length > 10 ? all.length - 10 : 0;

  return CourseStatsVm(
    id: id,
    name: d.name,
    code: d.code,
    section: d.section,
    cycle: d.cycle,
    faculty: sampleTeacher.faculty,
    week: week,
    weekActive: true,
    held: held,
    total: d.totalSessions,
    maxAbsences: d.maxAbsences,
    marks: marks,
    attendedMarks: marks - absentMarks,
    justified: justified,
    unjustified: absentMarks - justified,
    rate: rate,
    facultyDelta: d.facultyDelta,
    weekly: all.sublist(start),
    weeklyStart: start + 1,
    students: students,
    isSample: true,
  );
}

// ---------------------------------------------------------------------------
// DATOS REALES (cursos creados por el docente)
// ---------------------------------------------------------------------------
double? _weekRate(List<SessionAttendance> list, Set<String> ids) {
  if (list.isEmpty || ids.isEmpty) return null;
  var present = 0;
  for (final s in list) {
    present += s.presentIds.where(ids.contains).length;
  }
  return present * 100 / (ids.length * list.length);
}

CourseStatsVm buildRealStats({
  required CreatedCourse course,
  required List<EnrolledStudent> enrolled,
  required List<SessionAttendance> sessions,
  required DateTime now,
  int justifiedMarks = 0,
}) {
  final held = sessions.length;
  final ids = {for (final e in enrolled) e.id};

  var attendedMarks = 0;
  final students = <StatsStudent>[];
  for (final e in enrolled) {
    final attended = sessions.where((s) => s.presentIds.contains(e.id)).length;
    attendedMarks += attended;
    students.add(
      StatsStudent(
        id: e.id,
        name: e.name,
        code: e.code,
        absences: held - attended,
        held: held,
        maxAbsences: course.maxAbsences,
      ),
    );
  }

  final marks = enrolled.length * held;
  final rate = marks == 0 ? null : attendedMarks * 100 / marks;

  var weekly = <double?>[];
  var week = 1;
  var weeklyStart = 1;
  var active = false;
  if (sessions.isNotEmpty) {
    final first = sessions
        .map((s) => s.startsAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    int weekOf(DateTime d) => d.difference(first).inDays ~/ 7;

    final current = weekOf(now) < 0 ? 0 : weekOf(now);
    final startWeek = current >= 10 ? current - 9 : 0;
    week = current + 1;
    weeklyStart = startWeek + 1;
    weekly = [
      for (var w = startWeek; w <= current; w++)
        _weekRate(sessions.where((s) => weekOf(s.startsAt) == w).toList(), ids),
    ];
    active = sessions.any((s) => s.endsAt.isAfter(now));
  }

  return CourseStatsVm(
    id: course.id,
    name: course.name,
    code: course.code,
    cycle: course.period,
    faculty: '',
    week: week,
    weekActive: active,
    held: held,
    total: course.totalSessions,
    maxAbsences: course.maxAbsences,
    marks: marks,
    attendedMarks: attendedMarks,
    justified: justifiedMarks > marks - attendedMarks
        ? marks - attendedMarks
        : justifiedMarks,
    unjustified:
        marks -
        attendedMarks -
        (justifiedMarks > marks - attendedMarks
            ? marks - attendedMarks
            : justifiedMarks),
    rate: rate,
    weekly: weekly,
    weeklyStart: weeklyStart,
    students: students,
    isSample: false,
  );
}

/// Sesiones del curso con los estudiantes que tienen asistencia confirmada.
final courseAttendanceProvider = FutureProvider.autoDispose
    .family<List<SessionAttendance>, String>(
      (ref, courseId) =>
          ref.read(attendanceRepositoryProvider).loadCourseAttendance(courseId),
    );
