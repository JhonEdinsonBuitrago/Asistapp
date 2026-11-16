import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CourseModality {
  const CourseModality(this.id, this.title, this.description);

  final String id;
  final String title;
  final String description;
}

const courseModalities = <CourseModality>[
  CourseModality(
    'presencial',
    'Presencial',
    'Aula Magna / Pabellón Central (QR dinámico y código en el aula)',
  ),
  CourseModality(
    'laboratorio',
    'Laboratorio de Cómputo',
    'QR Dinámico rotativo en pantalla principal',
  ),
  CourseModality(
    'hibrido',
    'Formato Híbrido Sincrónico',
    'Código OTP de 6 dígitos + QR dinámico (clases en línea o mixtas)',
  ),
];

String modalityTitle(String id) => courseModalities
    .firstWhere((m) => m.id == id, orElse: () => courseModalities.first)
    .title;

class CourseInput {
  const CourseInput({
    required this.name,
    required this.code,
    required this.period,
    required this.totalSessions,
    required this.modality,
    required this.notes,
  });

  final String name;
  final String code;
  final String period;
  final int totalSessions;
  final String modality;
  final String notes;
}

class CreatedCourse {
  const CreatedCourse({
    required this.id,
    required this.name,
    required this.code,
    required this.period,
    required this.totalSessions,
    required this.academicHours,
    required this.maxAbsences,
    required this.modality,
    required this.status,
    this.createdAt,
    this.studentCount = 0,
  });

  final String id;
  final String name;
  final String code;
  final String period;
  final int totalSessions;
  final int academicHours;
  final int maxAbsences;
  final String modality;
  final String status; // 'active' | 'draft'
  final DateTime? createdAt;
  final int studentCount;

  bool get isDraft => status == 'draft';

  factory CreatedCourse.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return CreatedCourse(
      id: doc.id,
      name: d['name'] as String? ?? '',
      code: d['code'] as String? ?? '',
      period: d['period'] as String? ?? '',
      totalSessions: (d['totalSessions'] as num?)?.toInt() ?? 0,
      academicHours: (d['academicHours'] as num?)?.toInt() ?? 0,
      maxAbsences: (d['maxAbsences'] as num?)?.toInt() ?? 0,
      modality: d['modality'] as String? ?? 'presencial',
      status: d['status'] as String? ?? 'active',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      studentCount: (d['studentCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class CourseRepository {
  CourseRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static const tolerancePercent = 20;

  CollectionReference<Map<String, dynamic>> get _courses =>
      _db.collection('courses');

  /// Identifica el curso antes de guardarlo: si se reintenta, no se duplica.
  DocumentReference<Map<String, dynamic>> newCourseRef() => _courses.doc();

  Stream<List<CreatedCourse>> watchMyCourses() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const <CreatedCourse>[]);
    return _courses.where('teacherId', isEqualTo: uid).snapshots().map((snap) {
      final now = DateTime.now();
      return snap.docs.map(CreatedCourse.fromDoc).toList()
        ..sort((a, b) => (b.createdAt ?? now).compareTo(a.createdAt ?? now));
    });
  }

  /// ¿Ya tienes otro curso con este código? Sin conexión no bloquea.
  Future<bool> codeExists(String code, {String? exceptId}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    try {
      final snap = await _courses
          .where('teacherId', isEqualTo: uid)
          .where('code', isEqualTo: code)
          .limit(5)
          .get()
          .timeout(const Duration(seconds: 8));
      return snap.docs.any((d) => d.id != exceptId);
    } catch (_) {
      return false;
    }
  }

  Future<void> saveCourse(
    DocumentReference<Map<String, dynamic>> ref,
    CourseInput c, {
    required bool draft,
  }) {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sin sesión');

    return ref
        .set({
          'teacherId': user.uid,
          'teacherName': user.displayName ?? user.email ?? '',
          'name': c.name,
          'code': c.code,
          'period': c.period,
          'totalSessions': c.totalSessions,
          'academicHours': c.totalSessions * 2,
          'tolerancePercent': tolerancePercent,
          'maxAbsences': c.totalSessions * tolerancePercent ~/ 100,
          'modality': c.modality,
          'notes': c.notes,
          'status': draft ? 'draft' : 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(const Duration(seconds: 12));
  }

  Future<void> activateCourse(String id) => _courses.doc(id).update({
    'status': 'active',
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<void> deleteDraft(String id) => _courses.doc(id).delete();
}

final courseRepositoryProvider = Provider<CourseRepository>(
  (ref) => CourseRepository(FirebaseFirestore.instance, FirebaseAuth.instance),
);

/// Cursos del docente, en tiempo real.
final myCoursesProvider = StreamProvider.autoDispose<List<CreatedCourse>>(
  (ref) => ref.read(courseRepositoryProvider).watchMyCourses(),
);
