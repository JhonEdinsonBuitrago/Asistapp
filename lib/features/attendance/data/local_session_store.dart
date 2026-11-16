import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'attendance_models.dart';

class LocalSession {
  const LocalSession({
    required this.id,
    required this.teacherId,
    required this.courseId,
    required this.courseName,
    required this.room,
    required this.secret,
    required this.stepSeconds,
    required this.startsAtMs,
    required this.endsAtMs,
    required this.offsetMs,
    this.courseCode = '',
    this.section,
    this.number = 0,
  });

  final String id;
  final String teacherId;
  final String courseId;
  final String courseName;
  final String room;
  final String secret;
  final int stepSeconds;
  final int startsAtMs;
  final int endsAtMs;

  /// Diferencia entre el reloj del docente y el del servidor, medida al activar.
  final int offsetMs;

  final String courseCode;
  final String? section;

  /// Número de la clase (0 si no se conoce).
  final int number;

  /// Misma sesión con otra hora de cierre.
  LocalSession withEnd(int newEndsAtMs) => LocalSession(
    id: id,
    teacherId: teacherId,
    courseId: courseId,
    courseName: courseName,
    room: room,
    secret: secret,
    stepSeconds: stepSeconds,
    startsAtMs: startsAtMs,
    endsAtMs: newEndsAtMs,
    offsetMs: offsetMs,
    courseCode: courseCode,
    section: section,
    number: number,
  );

  SessionInfo toInfo() => SessionInfo(
    id: id,
    courseId: courseId,
    courseName: courseName,
    room: room,
    teacherId: teacherId,
    startsAt: DateTime.fromMillisecondsSinceEpoch(startsAtMs),
    endsAt: DateTime.fromMillisecondsSinceEpoch(endsAtMs),
    stepSeconds: stepSeconds,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'teacherId': teacherId,
    'courseId': courseId,
    'courseName': courseName,
    'room': room,
    'secret': secret,
    'stepSeconds': stepSeconds,
    'startsAtMs': startsAtMs,
    'endsAtMs': endsAtMs,
    'offsetMs': offsetMs,
    'courseCode': courseCode,
    'section': section,
    'number': number,
  };

  factory LocalSession.fromJson(Map<String, dynamic> j) => LocalSession(
    id: j['id'] as String,
    teacherId: j['teacherId'] as String,
    courseId: j['courseId'] as String,
    courseName: j['courseName'] as String,
    room: j['room'] as String,
    secret: j['secret'] as String,
    stepSeconds: (j['stepSeconds'] as num).toInt(),
    startsAtMs: (j['startsAtMs'] as num).toInt(),
    endsAtMs: (j['endsAtMs'] as num).toInt(),
    offsetMs: (j['offsetMs'] as num).toInt(),
    courseCode: (j['courseCode'] as String?) ?? '',
    section: j['section'] as String?,
    number: (j['number'] as num?)?.toInt() ?? 0,
  );
}

class LocalSessionStore {
  static const _key = 'teacher_active_session';

  Future<LocalSession?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final s = LocalSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      // Solo se reanuda la sesión de la misma cuenta.
      if (s.teacherId != FirebaseAuth.instance.currentUser?.uid) return null;
      return s;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(LocalSession s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(s.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
