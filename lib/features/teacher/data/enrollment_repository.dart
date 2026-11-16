import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Minúsculas y sin tildes, para buscar sin distinguir acentos.
String normalizeText(String s) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñ';
  const to = 'aaaaeeeeiiiioooouuuun';
  var out = s.toLowerCase();
  for (var i = 0; i < from.length; i++) {
    out = out.replaceAll(from[i], to[i]);
  }
  return out.trim();
}

List<String> _words(String name) =>
    name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// Estudiante registrado en la app (el "directorio" para matricular).
class DirectoryStudent {
  const DirectoryStudent({
    required this.id,
    required this.name,
    required this.code,
    required this.email,
  });

  final String id;
  final String name;
  final String code;
  final String email;

  String get initials {
    final w = _words(name);
    if (w.isEmpty) return '?';
    if (w.length == 1) return w.first[0].toUpperCase();
    return (w.first[0] + w.last[0]).toUpperCase();
  }

  /// Por ejemplo "Camila V."
  String get shortName {
    final w = _words(name);
    if (w.isEmpty) return 'Estudiante';
    if (w.length == 1) return w.first;
    return '${w.first} ${w.last[0].toUpperCase()}.';
  }

  String get searchKey => normalizeText('$name $code $email');

  factory DirectoryStudent.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    return DirectoryStudent(
      id: doc.id,
      name: (d['name'] as String? ?? '').trim(),
      code: (d['studentCode'] as String? ?? '').trim(),
      email: (d['email'] as String? ?? '').trim(),
    );
  }
}

/// Estudiante ya matriculado en un curso.
class EnrolledStudent {
  const EnrolledStudent({
    required this.id,
    required this.name,
    required this.code,
    required this.email,
    this.enrolledAt,
  });

  final String id;
  final String name;
  final String code;
  final String email;
  final DateTime? enrolledAt;

  factory EnrolledStudent.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    return EnrolledStudent(
      id: doc.id,
      name: d['name'] as String? ?? '',
      code: d['code'] as String? ?? '',
      email: d['email'] as String? ?? '',
      enrolledAt: (d['enrolledAt'] as Timestamp?)?.toDate(),
    );
  }
}

class EnrollmentRepository {
  EnrollmentRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  /// Estudiantes registrados en la app (hasta 500), ordenados por nombre.
  Future<List<DirectoryStudent>> loadDirectory() async {
    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: 'student')
        .limit(500)
        .get()
        .timeout(const Duration(seconds: 15));

    final list =
        snap.docs
            .map(DirectoryStudent.fromDoc)
            .where((s) => s.name.isNotEmpty)
            .toList()
          ..sort(
            (a, b) => normalizeText(a.name).compareTo(normalizeText(b.name)),
          );
    return list;
  }

  Stream<List<EnrolledStudent>> watchEnrolled(String courseId) {
    return _db
        .collection('courses')
        .doc(courseId)
        .collection('enrollments')
        .snapshots()
        .map(
          (snap) => snap.docs.map(EnrolledStudent.fromDoc).toList()
            ..sort(
              (a, b) => normalizeText(a.name).compareTo(normalizeText(b.name)),
            ),
        );
  }

  /// Matricula a los estudiantes. Devuelve cuántos quedaron guardados.
  Future<int> enroll({
    required String courseId,
    required String courseName,
    required String courseCode,
    required List<DirectoryStudent> students,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Sin sesión');

    final course = _db.collection('courses').doc(courseId);
    var done = 0;

    // Lotes de 100 estudiantes (cada uno escribe 2 documentos).
    for (var i = 0; i < students.length; i += 100) {
      final end = i + 100 > students.length ? students.length : i + 100;
      final chunk = students.sublist(i, end);
      final batch = _db.batch();

      for (final s in chunk) {
        batch.set(course.collection('enrollments').doc(s.id), {
          'studentId': s.id,
          'name': s.name,
          'code': s.code,
          'email': s.email,
          'addedBy': uid,
          'enrolledAt': FieldValue.serverTimestamp(),
        });
        batch.set(
          _db
              .collection('users')
              .doc(s.id)
              .collection('enrollments')
              .doc(courseId),
          {
            'courseId': courseId,
            'courseName': courseName,
            'courseCode': courseCode,
            'teacherId': uid,
            'enrolledAt': FieldValue.serverTimestamp(),
          },
        );
      }
      batch.update(course, {
        'studentCount': FieldValue.increment(chunk.length),
        'updatedAt': FieldValue.serverTimestamp(),
        'teacherName': _auth.currentUser?.displayName ?? '',
      });

      await batch.commit().timeout(const Duration(seconds: 20));
      done += chunk.length;
    }
    return done;
  }
}

final enrollmentRepositoryProvider = Provider<EnrollmentRepository>(
  (ref) =>
      EnrollmentRepository(FirebaseFirestore.instance, FirebaseAuth.instance),
);

/// Estudiantes matriculados en un curso, en tiempo real.
final enrolledStudentsProvider = StreamProvider.autoDispose
    .family<List<EnrolledStudent>, String>(
      (ref, courseId) =>
          ref.read(enrollmentRepositoryProvider).watchEnrolled(courseId),
    );
