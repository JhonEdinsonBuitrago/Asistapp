import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../student/data/student_courses_data.dart';

/// Horas después de terminar la clase para pedir la justificación.
/// Debe coincidir con `duration.value(72, 'h')` de las reglas de Firestore.
const kJustifyHours = 72;

enum JustificationStatus { pending, approved, rejected }

JustificationStatus justificationStatusFrom(String? s) => switch (s) {
  'approved' => JustificationStatus.approved,
  'rejected' => JustificationStatus.rejected,
  _ => JustificationStatus.pending,
};

enum JustificationCategory { medico, calamidad, academico, laboral, otro }

extension JustificationCategoryX on JustificationCategory {
  String get label => switch (this) {
    JustificationCategory.medico => 'Médica',
    JustificationCategory.calamidad => 'Calamidad',
    JustificationCategory.academico => 'Académica',
    JustificationCategory.laboral => 'Laboral',
    JustificationCategory.otro => 'Otro',
  };

  String get hint => switch (this) {
    JustificationCategory.medico => 'Consulta, incapacidad o examen médico',
    JustificationCategory.calamidad =>
      'Fallecimiento, accidente o emergencia familiar',
    JustificationCategory.academico =>
      'Actividad institucional o evaluación en otra asignatura',
    JustificationCategory.laboral => 'Obligación de trabajo certificada',
    JustificationCategory.otro =>
      'Fuerza mayor que no está en las opciones anteriores',
  };

  IconData get icon => switch (this) {
    JustificationCategory.medico => Icons.medical_services_outlined,
    JustificationCategory.calamidad => Icons.volunteer_activism_outlined,
    JustificationCategory.academico => Icons.school_outlined,
    JustificationCategory.laboral => Icons.work_outline,
    JustificationCategory.otro => Icons.more_horiz,
  };
}

JustificationCategory justificationCategoryFrom(String? s) =>
    JustificationCategory.values.firstWhere(
      (c) => c.name == s,
      orElse: () => JustificationCategory.otro,
    );

/// Constancia visible de una justificación (se calcula con su identificador).
String justificationCode(String id) {
  final h = id.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) % 1000003);
  return 'JST-${(h % 9000) + 1000}';
}

class JustificationInfo {
  const JustificationInfo({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.sessionId,
    required this.sessionNumber,
    required this.sessionDate,
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    required this.teacherId,
    required this.category,
    required this.description,
    required this.reference,
    required this.status,
    this.createdAt,
    this.decidedAt,
    this.decisionNote = '',
  });

  final String id;
  final String courseId;
  final String courseName;
  final String sessionId;
  final int sessionNumber;
  final DateTime sessionDate;
  final String studentId;
  final String studentName;
  final String studentCode;
  final String teacherId;
  final JustificationCategory category;
  final String description;
  final String reference;
  final JustificationStatus status;
  final DateTime? createdAt;
  final DateTime? decidedAt;
  final String decisionNote;

  String get code => justificationCode(id);

  factory JustificationInfo.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? <String, dynamic>{};
    return JustificationInfo(
      id: doc.id,
      courseId: d['courseId'] as String? ?? '',
      courseName: d['courseName'] as String? ?? 'Curso',
      sessionId: d['sessionId'] as String? ?? '',
      sessionNumber: (d['sessionNumber'] as num?)?.toInt() ?? 0,
      sessionDate: (d['sessionDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      studentId: d['studentId'] as String? ?? '',
      studentName: d['studentName'] as String? ?? '',
      studentCode: d['studentCode'] as String? ?? '',
      teacherId: d['teacherId'] as String? ?? '',
      category: justificationCategoryFrom(d['category'] as String?),
      description: d['description'] as String? ?? '',
      reference: d['reference'] as String? ?? '',
      status: justificationStatusFrom(d['status'] as String?),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      decidedAt: (d['decidedAt'] as Timestamp?)?.toDate(),
      decisionNote: d['decisionNote'] as String? ?? '',
    );
  }
}

class JustificationRepository {
  JustificationRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static const _wait = Duration(seconds: 15);

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('justifications');

  List<JustificationInfo> _sorted(List<JustificationInfo> list) => list
    ..sort(
      (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
        a.createdAt ?? DateTime.now(),
      ),
    );

  /// Solicitudes del estudiante (en tiempo real).
  Stream<List<JustificationInfo>> watchMine() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const <JustificationInfo>[]);
    return _col
        .where('studentId', isEqualTo: uid)
        .snapshots()
        .map((s) => _sorted(s.docs.map(JustificationInfo.fromDoc).toList()));
  }

  /// Solicitudes dirigidas al docente (en tiempo real).
  Stream<List<JustificationInfo>> watchForTeacher() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const <JustificationInfo>[]);
    return _col
        .where('teacherId', isEqualTo: uid)
        .snapshots()
        .map((s) => _sorted(s.docs.map(JustificationInfo.fromDoc).toList()));
  }

  /// Envía la solicitud. Con [replace] borra antes la rechazada anterior.
  Future<void> submit({
    required String courseId,
    required String courseName,
    required String sessionId,
    required int sessionNumber,
    required DateTime sessionDate,
    required String teacherId,
    required String studentName,
    required String studentCode,
    required JustificationCategory category,
    required String description,
    String reference = '',
    bool replace = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sin sesión');

    final ref = _col.doc('${sessionId}_${user.uid}');
    if (replace) await ref.delete().timeout(_wait);

    await ref
        .set({
          'courseId': courseId,
          'courseName': courseName,
          'sessionId': sessionId,
          'sessionNumber': sessionNumber,
          'sessionDate': Timestamp.fromDate(sessionDate),
          'studentId': user.uid,
          'studentName': studentName,
          'studentCode': studentCode,
          'teacherId': teacherId,
          'category': category.name,
          'description': description.trim(),
          'reference': reference.trim(),
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        })
        .timeout(_wait);
  }

  Future<void> withdraw(String id) => _col.doc(id).delete().timeout(_wait);

  /// El docente aprueba o rechaza.
  Future<void> decide(String id, {required bool approve, String note = ''}) {
    return _col
        .doc(id)
        .update({
          'status': approve ? 'approved' : 'rejected',
          'decidedAt': FieldValue.serverTimestamp(),
          'decidedBy': _auth.currentUser?.uid,
          'decisionNote': note.trim(),
        })
        .timeout(_wait);
  }
}

final justificationRepositoryProvider = Provider<JustificationRepository>(
  (ref) => JustificationRepository(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
  ),
);

final myJustificationsProvider =
    StreamProvider.autoDispose<List<JustificationInfo>>(
      (ref) => ref.read(justificationRepositoryProvider).watchMine(),
    );

final teacherJustificationsProvider =
    StreamProvider.autoDispose<List<JustificationInfo>>(
      (ref) => ref.read(justificationRepositoryProvider).watchForTeacher(),
    );

// ---------------------------------------------------------------------------
// Reglas de elegibilidad (lado del estudiante)
// ---------------------------------------------------------------------------
DateTime justifyDeadline(DateTime sessionEnd) =>
    sessionEnd.add(const Duration(hours: kJustifyHours));

enum JustifyState { canJustify, pending, approved, rejected, retry, expired }

/// Estado de justificación de una falta. Solo aplica a entradas con falta.
JustifyState justifyStateOf(ClassEntry e, JustificationInfo? j, DateTime now) {
  final open = now.isBefore(justifyDeadline(e.session.endsAt));
  if (j != null) {
    switch (j.status) {
      case JustificationStatus.pending:
        return JustifyState.pending;
      case JustificationStatus.approved:
        return JustifyState.approved;
      case JustificationStatus.rejected:
        return open ? JustifyState.retry : JustifyState.rejected;
    }
  }
  return open ? JustifyState.canJustify : JustifyState.expired;
}

/// Cuántas faltas puede justificar el estudiante y cuánto falta para la más
/// urgente (en horas).
({int count, int minHoursLeft}) justifiableSummary(
  StudentOverview overview,
  List<JustificationInfo> justs,
  DateTime now, {
  String? courseId,
}) {
  final map = {for (final j in justs) j.sessionId: j};
  var count = 0;
  Duration? min;
  for (final ca in overview.courses) {
    if (courseId != null && ca.course.id != courseId) continue;
    for (final e in ca.entries) {
      if (e.kind != EntryKind.absent) continue;
      final st = justifyStateOf(e, map[e.session.id], now);
      if (st == JustifyState.canJustify || st == JustifyState.retry) {
        count++;
        final left = justifyDeadline(e.session.endsAt).difference(now);
        if (min == null || left < min) min = left;
      }
    }
  }
  return (count: count, minHoursLeft: min == null ? 0 : min.inHours);
}

// ---------------------------------------------------------------------------
// Formato
// ---------------------------------------------------------------------------
const _dayNames = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const _monthNames = [
  'Ene',
  'Feb',
  'Mar',
  'Abr',
  'May',
  'Jun',
  'Jul',
  'Ago',
  'Sep',
  'Oct',
  'Nov',
  'Dic',
];

String _two(int n) => n.toString().padLeft(2, '0');

String jDateLine(DateTime d) =>
    '${_dayNames[d.weekday - 1]}, ${_two(d.day)} ${_monthNames[d.month - 1]} ${d.year}';

String jHm(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${_two(h)}:${_two(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// "hace 5 min", "hace 3 h", "hace 2 días".
String jAgo(DateTime? d) {
  if (d == null) return 'hace un momento';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'hace un momento';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  final days = diff.inDays;
  return 'hace $days ${days == 1 ? 'día' : 'días'}';
}

/// Tiempo restante: "41 h", "2 días", "35 min".
String jLeft(Duration d) {
  if (d.isNegative) return '0 h';
  final h = d.inHours;
  if (h >= 48) return '${h ~/ 24} días';
  if (h >= 1) return '$h h';
  return '${d.inMinutes} min';
}
