import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../attendance/data/attendance_models.dart';

enum CourseStatus { safe, warning, risk }

/// Curso en el que el estudiante está matriculado.
class EnrolledCourse {
  const EnrolledCourse({
    required this.id,
    required this.name,
    required this.code,
    required this.period,
    required this.totalSessions,
    required this.maxAbsences,
    required this.teacherName,
    required this.modality,
    required this.notes,
    required this.limited,
    this.enrolledAt,
  });

  final String id;
  final String name;
  final String code;
  final String period;
  final int totalSessions;
  final int maxAbsences;
  final String teacherName;
  final String modality;
  final String notes;

  /// true si no se pudo leer el documento completo del curso (solo hay
  /// nombre y código, tomados de la matrícula).
  final bool limited;
  final DateTime? enrolledAt;

  String get teacherLabel =>
      teacherName.trim().isEmpty ? 'Docente del curso' : teacherName.trim();
}

enum EntryKind { present, absent, processing, review, ongoing }

/// Una sesión del curso y lo que pasó con el estudiante en ella.
class ClassEntry {
  const ClassEntry({
    required this.number,
    required this.session,
    required this.kind,
    this.claim,
    this.note,
  });

  final int number;
  final SessionInfo session;
  final EntryKind kind;
  final ClaimInfo? claim;
  final String? note;
}

class CourseAttendance {
  const CourseAttendance({required this.course, required this.entries});

  final EnrolledCourse course;

  /// De la sesión más antigua a la más reciente.
  final List<ClassEntry> entries;

  int _count(EntryKind k) => entries.where((e) => e.kind == k).length;

  int get present => _count(EntryKind.present);
  int get absent => _count(EntryKind.absent);
  int get inProcess => _count(EntryKind.processing) + _count(EntryKind.review);

  /// Clases que ya cuentan (asistidas + faltas).
  int get held => present + absent;
  double? get percent => held == 0 ? null : present * 100 / held;
  int get remaining => course.maxAbsences - absent;

  /// Mismas reglas que ve el docente: a 2 faltas del límite es alerta, y en o
  /// sobre el límite es riesgo.
  CourseStatus get status {
    if (course.limited || absent == 0) return CourseStatus.safe;
    final r = remaining;
    if (r <= 0) return CourseStatus.risk;
    if (r <= 2) return CourseStatus.warning;
    return CourseStatus.safe;
  }
}

class StudentOverview {
  const StudentOverview(this.courses);

  final List<CourseAttendance> courses;

  int get present => courses.fold<int>(0, (s, c) => s + c.present);
  int get held => courses.fold<int>(0, (s, c) => s + c.held);
  double? get attendance => held == 0 ? null : present * 100 / held;
  int get riskCount =>
      courses.where((c) => c.status != CourseStatus.safe).length;
}

class StudentCoursesRepository {
  StudentCoursesRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static const _wait = Duration(seconds: 15);

  EnrolledCourse _build(
    String id,
    Map<String, dynamic> enrollment,
    Map<String, dynamic>? course,
  ) {
    final enrolledAt = (enrollment['enrolledAt'] as Timestamp?)?.toDate();
    final fallbackName = enrollment['courseName'] as String? ?? 'Curso';
    final fallbackCode = enrollment['courseCode'] as String? ?? '';

    if (course == null) {
      return EnrolledCourse(
        id: id,
        name: fallbackName,
        code: fallbackCode,
        period: '',
        totalSessions: 0,
        maxAbsences: 0,
        teacherName: '',
        modality: 'presencial',
        notes: '',
        limited: true,
        enrolledAt: enrolledAt,
      );
    }
    return EnrolledCourse(
      id: id,
      name: course['name'] as String? ?? fallbackName,
      code: course['code'] as String? ?? fallbackCode,
      period: course['period'] as String? ?? '',
      totalSessions: (course['totalSessions'] as num?)?.toInt() ?? 0,
      maxAbsences: (course['maxAbsences'] as num?)?.toInt() ?? 0,
      teacherName: course['teacherName'] as String? ?? '',
      modality: course['modality'] as String? ?? 'presencial',
      notes: course['notes'] as String? ?? '',
      limited: false,
      enrolledAt: enrolledAt,
    );
  }

  /// Cursos en los que el estudiante está matriculado (en tiempo real).
  Stream<List<EnrolledCourse>> watchMyCourses() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const <EnrolledCourse>[]);

    return _db
        .collection('users')
        .doc(uid)
        .collection('enrollments')
        .snapshots()
        .asyncMap((snap) async {
          final list = await Future.wait(
            snap.docs.map((e) async {
              Map<String, dynamic>? course;
              try {
                final c = await _db
                    .collection('courses')
                    .doc(e.id)
                    .get()
                    .timeout(const Duration(seconds: 10));
                course = c.data();
              } catch (_) {
                // Sin permiso o sin conexión: se usa lo que trae la matrícula.
              }
              return _build(e.id, e.data(), course);
            }),
          );
          list.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
          return list;
        });
  }

  Future<EnrolledCourse?> fetchCourse(String courseId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final enrollment = await _db
        .collection('users')
        .doc(uid)
        .collection('enrollments')
        .doc(courseId)
        .get()
        .timeout(_wait);
    if (!enrollment.exists) return null;

    Map<String, dynamic>? course;
    try {
      final c = await _db
          .collection('courses')
          .doc(courseId)
          .get()
          .timeout(const Duration(seconds: 10));
      course = c.data();
    } catch (_) {
      // Se usa lo que trae la matrícula.
    }
    return _build(courseId, enrollment.data() ?? <String, dynamic>{}, course);
  }

  /// Sesiones del curso y el registro del estudiante en cada una.
  Future<CourseAttendance> loadAttendance(EnrolledCourse course) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return CourseAttendance(course: course, entries: const []);

    final snap = await _db
        .collection('sessions')
        .where('courseId', isEqualTo: course.id)
        .get()
        .timeout(_wait);

    final all = snap.docs.map(SessionInfo.fromDoc).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    // Solo cuentan las sesiones desde que el estudiante fue matriculado.
    final since = course.enrolledAt;
    final relevant = <(int, SessionInfo)>[];
    for (var i = 0; i < all.length; i++) {
      if (since == null || all[i].endsAt.isAfter(since)) {
        relevant.add((i + 1, all[i]));
      }
    }

    final claims = await Future.wait(
      relevant.map((p) async {
        final d = await _db
            .collection('sessions')
            .doc(p.$2.id)
            .collection('claims')
            .doc(uid)
            .get()
            .timeout(_wait);
        return d.exists ? ClaimInfo.fromDoc(d) : null;
      }),
    );

    final now = DateTime.now();
    final entries = <ClassEntry>[];

    for (var i = 0; i < relevant.length; i++) {
      final number = relevant[i].$1;
      final session = relevant[i].$2;
      final claim = claims[i];
      final ended = !session.endsAt.isAfter(now);

      EntryKind kind;
      String? note;

      if (claim == null) {
        kind = ended ? EntryKind.absent : EntryKind.ongoing;
        note = ended ? 'Sin registro de asistencia' : 'La sesión sigue abierta';
      } else {
        switch (claim.status) {
          case ClaimStatus.validated:
            kind = EntryKind.present;
          case ClaimStatus.pending:
            kind = EntryKind.processing;
            note = 'Esperando la validación del docente';
          case ClaimStatus.review:
            kind = EntryKind.review;
            final r = reasonText(claim.reason);
            note = r.isEmpty ? 'El docente revisará tu registro' : r;
          case ClaimStatus.rejected:
            kind = EntryKind.absent;
            final r = reasonText(claim.reason);
            note = r.isEmpty
                ? 'Registro no validado'
                : 'Registro no validado: $r';
        }
      }

      entries.add(
        ClassEntry(
          number: number,
          session: session,
          kind: kind,
          claim: claim,
          note: note,
        ),
      );
    }

    return CourseAttendance(course: course, entries: entries);
  }
}

final studentCoursesRepositoryProvider = Provider<StudentCoursesRepository>(
  (ref) => StudentCoursesRepository(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
  ),
);

final myEnrolledCoursesProvider =
    StreamProvider.autoDispose<List<EnrolledCourse>>(
      (ref) => ref.read(studentCoursesRepositoryProvider).watchMyCourses(),
    );

/// Todos los cursos del estudiante con su asistencia (inicio y perfil).
final studentOverviewProvider = FutureProvider.autoDispose<StudentOverview>((
  ref,
) async {
  final repo = ref.read(studentCoursesRepositoryProvider);
  final courses = await ref.watch(myEnrolledCoursesProvider.future);

  final list = await Future.wait(
    courses.map((c) async {
      try {
        return await repo.loadAttendance(c);
      } catch (_) {
        return CourseAttendance(course: c, entries: const []);
      }
    }),
  );
  return StudentOverview(list);
});

/// Asistencia del estudiante en un curso (detalle e historial).
final studentCourseAttendanceProvider = FutureProvider.autoDispose
    .family<CourseAttendance?, String>((ref, courseId) async {
      final repo = ref.read(studentCoursesRepositoryProvider);
      final course = await repo.fetchCourse(courseId);
      if (course == null) return null;
      return repo.loadAttendance(course);
    });
