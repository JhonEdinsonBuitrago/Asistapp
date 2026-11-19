import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attendance/data/attendance_models.dart';
import '../../attendance/data/attendance_repository.dart';
import 'course_repository.dart';
import 'course_stats_data.dart';
import 'enrollment_repository.dart';
import '../../justifications/data/justification_data.dart';

enum ClassStatus { present, justified, absent, review, pending, rejected }

enum ClassMethod { qr, manual }

class Justification {
  const Justification({
    required this.code,
    required this.approvedBy,
    required this.reason,
  });

  final String code;
  final String approvedBy;
  final String reason;
}

class ClassRecord {
  const ClassRecord({
    required this.number,
    required this.date,
    required this.title,
    required this.timeLabel,
    required this.status,
    this.room = '',
    this.method,
    this.offline = false,
    this.markedAt,
    this.note,
    this.justification,
  });

  final int number;
  final DateTime date;
  final String title;
  final String timeLabel;
  final String room;
  final ClassStatus status;
  final ClassMethod? method;

  /// El registro se hizo sin conexión.
  final bool offline;

  /// Hora en que el estudiante registró su asistencia.
  final DateTime? markedAt;
  final String? note;
  final Justification? justification;
}

class StudentDetailVm {
  const StudentDetailVm({
    required this.courseId,
    required this.courseName,
    required this.courseCode,
    required this.cycle,
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    required this.maxAbsences,
    required this.records,
    required this.isSample,
    this.section,
    this.email,
    this.program,
  });

  final String courseId;
  final String courseName;
  final String courseCode;
  final String? section;
  final String cycle;
  final String studentId;
  final String studentName;
  final String studentCode;
  final String? email;
  final String? program;
  final int maxAbsences;

  /// De la clase más reciente a la más antigua.
  final List<ClassRecord> records;
  final bool isSample;

  int get held => records.length;
  int get present =>
      records.where((r) => r.status == ClassStatus.present).length;
  int get justified =>
      records.where((r) => r.status == ClassStatus.justified).length;
  int get inReview => records
      .where(
        (r) =>
            r.status == ClassStatus.review || r.status == ClassStatus.pending,
      )
      .length;

  /// Todo lo que no es una asistencia confirmada cuenta como falta.
  int get absences => held - present;
  int get unjustified => absences - justified;
  int get remaining => maxAbsences - absences;
  double get attendancePercent => held == 0 ? 0 : present * 100 / held;
  double get faultPercent => held == 0 ? 0 : absences * 100 / held;

  StatsStudent get _asStats => StatsStudent(
    id: studentId,
    name: studentName,
    code: studentCode,
    absences: absences,
    held: held,
    maxAbsences: maxAbsences,
  );

  StatsRisk get risk => _asStats.risk;
  bool get isCritical => _asStats.isCritical;
  String get firstName => _asStats.firstName;
  String get initials => _asStats.initials;
}

String _two(int n) => n.toString().padLeft(2, '0');

// ---------------------------------------------------------------------------
// DATOS REALES (cursos creados por el docente)
// ---------------------------------------------------------------------------
StudentDetailVm buildRealStudentDetail({
  required CreatedCourse course,
  required EnrolledStudent student,
  required List<StudentSessionRecord> sessions,
  Map<String, JustificationInfo> justifications = const {},
}) {
  final records = <ClassRecord>[];

  for (var i = sessions.length - 1; i >= 0; i--) {
    final s = sessions[i].session;
    final c = sessions[i].claim;
    final n = i + 1;
    final start = s.startsAt;
    final end = s.endsAt;

    ClassRecord make(
      ClassStatus status, {
      ClassMethod? method,
      bool offline = false,
      DateTime? markedAt,
      String? note,
      Justification? justification,
    }) => ClassRecord(
      number: n,
      date: start,
      title: 'Sesión de clase',
      timeLabel:
          '${_two(start.hour)}:${_two(start.minute)} - ${_two(end.hour)}:${_two(end.minute)} hrs',
      room: s.room,
      status: status,
      method: method,
      offline: offline,
      markedAt: markedAt,
      note: note,
      justification: justification,
    );

    if (c == null) {
      final j = justifications[s.id];
      if (j != null && j.status == JustificationStatus.approved) {
        records.add(
          make(
            ClassStatus.justified,
            justification: Justification(
              code: j.code,
              approvedBy: 'Docente del curso',
              reason: j.description,
            ),
          ),
        );
      } else {
        records.add(
          make(
            ClassStatus.absent,
            note: (j != null && j.status == JustificationStatus.pending)
                ? 'Justificación pendiente de tu revisión'
                : 'Sin registro de asistencia',
          ),
        );
      }
      continue;
    }

    final marked = DateTime.fromMillisecondsSinceEpoch(
      c.scannedAt + c.clockOffsetMs,
    );
    final method = c.method == 'pin' ? ClassMethod.manual : ClassMethod.qr;
    final offline = !c.timeVerified;
    final reason = reasonText(c.reason);

    switch (c.status) {
      case ClaimStatus.validated:
        records.add(
          make(
            ClassStatus.present,
            method: method,
            offline: offline,
            markedAt: marked,
          ),
        );
      case ClaimStatus.review:
        records.add(
          make(
            ClassStatus.review,
            method: method,
            offline: offline,
            markedAt: marked,
            note: reason.isEmpty ? 'Pendiente de tu revisión' : reason,
          ),
        );
      case ClaimStatus.pending:
        records.add(
          make(
            ClassStatus.pending,
            method: method,
            offline: offline,
            markedAt: marked,
            note: 'Esperando validación',
          ),
        );
      case ClaimStatus.rejected:
        records.add(
          make(
            ClassStatus.rejected,
            method: method,
            offline: offline,
            markedAt: marked,
            note: reason.isEmpty ? 'El registro no pasó la validación' : reason,
          ),
        );
    }
  }

  return StudentDetailVm(
    courseId: course.id,
    courseName: course.name,
    courseCode: course.code,
    cycle: course.period,
    studentId: student.id,
    studentName: student.name,
    studentCode: student.code,
    email: student.email.isEmpty ? null : student.email,
    maxAbsences: course.maxAbsences,
    records: records,
    isSample: false,
  );
}

/// Registros de un estudiante en cada sesión del curso.
final studentRecordsProvider = FutureProvider.autoDispose
    .family<List<StudentSessionRecord>, ({String courseId, String studentId})>(
      (ref, key) => ref
          .read(attendanceRepositoryProvider)
          .loadStudentRecords(key.courseId, key.studentId),
    );
