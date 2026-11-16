import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attendance/data/attendance_models.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../student/data/student_profile_data.dart';
import 'course_repository.dart';
import 'course_stats_data.dart';
import 'enrollment_repository.dart';
import 'teacher_course_detail_data.dart';
import 'teacher_mock_data.dart';
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

// ---------------------------------------------------------------------------
// DATOS DE EJEMPLO
// ---------------------------------------------------------------------------
const _arqTitles = <int, String>{
  1: 'Introducción a la Arquitectura de Software',
  2: 'Atributos de Calidad',
  3: 'Estilos Arquitectónicos',
  4: 'Arquitectura en Capas',
  5: 'Patrón MVC y MVVM',
  6: 'Principios SOLID',
  7: 'Patrones de Diseño Creacionales',
  8: 'Patrones de Diseño Estructurales',
  9: 'Patrones de Diseño de Comportamiento',
  10: 'Diseño de APIs REST',
  11: 'Arquitectura Orientada a Servicios',
  12: 'Mensajería y Colas',
  13: 'Sistemas Distribuidos y Tolerancia a Fallos',
  14: 'Evaluación Parcial: Arquitectura de Microservicios',
  15: 'CQRS y Event Sourcing',
  16: 'Diseño Orientado al Dominio (DDD)',
  17: 'Patrones de Resiliencia en Cloud',
  18: 'Microservicios y API Gateways',
};

const _mateoMinutes = <int, int>{17: 4, 15: 2, 13: 1};

String _two(int n) => n.toString().padLeft(2, '0');

int _hash(String s) =>
    s.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) % 1000003);

/// Clases en las que el estudiante faltó: número de clase -> ¿justificada?
Map<int, bool> _absencePlan(
  String courseId,
  String studentId,
  int absences,
  int held,
  int seed,
) {
  if (courseId == 'arq' && studentId == 'a4') {
    // Mateo Flores Quispe (el del mockup): 4 injustificadas y 2 justificadas.
    return {5: false, 7: true, 9: false, 14: false, 16: true, 18: false};
  }
  final n = absences.clamp(0, held).toInt();
  if (n == 0) return {};
  final numbers = List<int>.generate(held, (i) => i + 1)..shuffle(Random(seed));
  final picked = numbers.take(n).toList()..sort();
  final justified = picked.take(n ~/ 3).toSet();
  return {for (final k in picked) k: justified.contains(k)};
}

StudentDetailVm? sampleStudentDetail(
  String courseId,
  String studentId,
  DateTime now,
) {
  final d = sampleCourseDetail(courseId, now);
  final course = sampleTeacherCourses
      .where((c) => c.id == courseId)
      .firstOrNull;
  final student = d?.students.where((s) => s.id == studentId).firstOrNull;
  if (d == null || course == null || student == null) return null;

  final held = d.heldSessions;
  final seed = _hash('$courseId:$studentId');
  final plan = _absencePlan(courseId, studentId, student.absences, held, seed);
  final isMateo = courseId == 'arq' && studentId == 'a4';
  final perWeek = course.weekdays.length;
  final isArq = courseId == 'arq';

  final records = <ClassRecord>[];
  for (var n = held; n >= 1; n--) {
    // Las clases se cuentan desde el lunes 17 de febrero de 2025.
    final week = (n - 1) ~/ perWeek;
    final weekday = course.weekdays[(n - 1) % perWeek];
    final day = DateTime(2025, 2, 17 + week * 7 + weekday - 1);
    final start = DateTime(
      day.year,
      day.month,
      day.day,
      course.startHour,
      course.startMinute,
    );
    final end = DateTime(
      day.year,
      day.month,
      day.day,
      course.endHour,
      course.endMinute,
    );

    final room = isArq
        ? (n.isEven ? 'Laboratorio L-204' : 'Aula Magna B')
        : course.room;
    final title = isArq ? (_arqTitles[n] ?? 'Tema $n') : 'Tema $n';
    final timeLabel =
        '${_two(start.hour)}:${_two(start.minute)} - ${_two(end.hour)}:${_two(end.minute)} hrs';

    final justified =
        plan[n]; // null = asistió; false = injustificada; true = justificada

    if (justified == null) {
      final minutes =
          (isMateo ? _mateoMinutes[n] : null) ?? ((n * 7 + seed) % 12 + 1);
      records.add(
        ClassRecord(
          number: n,
          date: start,
          title: title,
          timeLabel: timeLabel,
          room: room,
          status: ClassStatus.present,
          method: n % 7 == 0 ? ClassMethod.manual : ClassMethod.qr,
          offline: n % 5 == 0,
          markedAt: start.add(Duration(minutes: minutes)),
        ),
      );
    } else if (justified) {
      final fixed = isMateo ? const {16: 'MED-4091', 7: 'MED-3877'}[n] : null;
      records.add(
        ClassRecord(
          number: n,
          date: start,
          title: title,
          timeLabel: timeLabel,
          room: room,
          status: ClassStatus.justified,
          justification: Justification(
            code: fixed ?? 'MED-${3000 + (n * 131 + seed) % 2000}',
            approvedBy: 'Bienestar Estudiantil',
            reason: 'Motivo médico acreditado mediante certificado oficial.',
          ),
        ),
      );
    } else {
      records.add(
        ClassRecord(
          number: n,
          date: start,
          title: title,
          timeLabel: timeLabel,
          room: room,
          status: ClassStatus.absent,
          note: title.startsWith('Evaluación')
              ? 'Ausencia en evaluación regular'
              : 'Sin registro de asistencia',
        ),
      );
    }
  }

  return StudentDetailVm(
    courseId: courseId,
    courseName: d.name,
    courseCode: d.code,
    section: d.section,
    cycle: d.cycle,
    studentId: studentId,
    studentName: student.name,
    studentCode: student.code,
    program: sampleStudentProgram,
    maxAbsences: d.maxAbsences,
    records: records,
    isSample: true,
  );
}

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
