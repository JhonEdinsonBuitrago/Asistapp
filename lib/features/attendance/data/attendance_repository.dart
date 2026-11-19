import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/clock_service.dart';
import 'attendance_models.dart';
import 'claim_validator.dart';
import 'local_session_store.dart';
import 'totp.dart';

class ClaimUpdate {
  const ClaimUpdate(this.studentId, this.outcome);
  final String studentId;
  final ValidationOutcome outcome;
}

class SessionAttendance {
  const SessionAttendance({
    required this.startsAt,
    required this.endsAt,
    required this.presentIds,
    this.reviewCount = 0,
    this.pendingCount = 0,
    this.offlineCount = 0,
  });

  final DateTime startsAt;
  final DateTime endsAt;

  /// Estudiantes con asistencia confirmada en esa sesión.
  final Set<String> presentIds;

  /// Registros en revisión, por validar y confirmados sin conexión.
  final int reviewCount;
  final int pendingCount;
  final int offlineCount;
}

class StudentSessionRecord {
  const StudentSessionRecord({required this.session, this.claim});

  final SessionInfo session;

  /// Registro del estudiante en esa sesión; null si no registró asistencia.
  final ClaimInfo? claim;
}

class AttendanceRepository {
  AttendanceRepository(this._db, this._auth, this._clock);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final ClockService _clock;

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('sessions');

  DocumentReference<Map<String, dynamic>> _claimRef(
    String sessionId,
    String studentId,
  ) => _sessions.doc(sessionId).collection('claims').doc(studentId);

  // ------------------------------ Estudiante ------------------------------

  /// Sesión abierta del curso. Sin conexión devuelve lo que haya en caché.
  Stream<SessionInfo?> watchOpenSession(String courseId) {
    return _sessions
        .where('courseId', isEqualTo: courseId)
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map((snap) {
          final now = DateTime.now();
          final open =
              snap.docs
                  .map(SessionInfo.fromDoc)
                  .where((s) => s.endsAt.isAfter(now))
                  .toList()
                ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
          return open.isEmpty ? null : open.first;
        });
  }

  /// Registro propio, con la marca de si ya llegó al servidor.
  Stream<ClaimInfo?> watchMyClaim(String sessionId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _claimRef(sessionId, uid)
        .snapshots(includeMetadataChanges: true)
        .map((s) => s.exists ? ClaimInfo.fromDoc(s) : null);
  }

  /// Reinicia la conexión con el servidor para enviar de inmediato lo pendiente.
  Future<void> retrySync() async {
    await _db.disableNetwork();
    await _db.enableNetwork();
  }

  /// Guarda el registro SIN esperar al servidor. Sin conexión, Firestore lo
  /// deja en el dispositivo y lo envía solo cuando vuelve la señal.
  Future<void> saveClaim({
    required String sessionId,
    required String method, // 'qr' | 'pin'
    required String code,
    int? qrTimestamp,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sin sesión');

    final ref = _claimRef(sessionId, user.uid);
    if (await _existsInCache(ref)) throw AlreadyRegisteredException();

    final data = <String, dynamic>{
      'studentId': user.uid,
      'studentName': user.displayName ?? user.email ?? '',
      'method': method,
      'code': code,
      if (qrTimestamp != null) 'qrTimestamp': qrTimestamp,
      'scannedAt': DateTime.now().millisecondsSinceEpoch,
      'clockOffsetMs': _clock.offsetMs,
      'offsetKnown': _clock.isKnown,
      'deviceId': await installId(),
      'status': 'pending',
      'syncedAt': FieldValue.serverTimestamp(),
    };

    // No se espera: sin conexión esta espera no terminaría.
    unawaited(ref.set(data).catchError((Object _) {}));
  }

  Future<bool> _existsInCache(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      final s = await ref.get(const GetOptions(source: Source.cache));
      return s.exists;
    } catch (_) {
      return false;
    }
  }

  // -------------------------------- Docente --------------------------------

  /// Activa una sesión. Es el único momento que exige conexión.
  /// Activa una sesión. Es el único momento que exige conexión.
  /// Activa una sesión. Es el único momento que exige conexión.
  Future<LocalSession> createSession({
    required String courseId,
    required String courseName,
    required String room,
    required int minutes,
    int stepSeconds = 20,
    String courseCode = '',
    String? section,
    int sessionNumber = 0,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sin sesión');

    // Calibra el reloj del docente contra el servidor.
    if (!await _clock.sync()) throw OfflineException();

    final stepMs = stepSeconds * 1000;
    final now = _clock.nowMs();
    // El inicio se alinea al paso del código, para que el primer QR quede
    // dentro del horario de la sesión.
    final startsAt = now - (now % stepMs);
    final endsAt = now + minutes * 60 * 1000;
    final secret = Totp.generateSecret();
    final doc = _sessions.doc();
    const wait = Duration(seconds: 15);

    await doc
        .set({
          'courseId': courseId,
          'courseName': courseName,
          'courseCode': courseCode,
          if (section != null) 'section': section,
          'sessionNumber': sessionNumber,
          'room': room,
          'teacherId': user.uid,
          'status': 'open',
          'stepSeconds': stepSeconds,
          'startsAt': Timestamp.fromMillisecondsSinceEpoch(startsAt),
          'endsAt': Timestamp.fromMillisecondsSinceEpoch(endsAt),
          'clockOffsetMs': _clock.offsetMs,
          'createdAt': FieldValue.serverTimestamp(),
        })
        .timeout(wait);

    await doc
        .collection('private')
        .doc('secret')
        .set({'secret': secret, 'createdAt': FieldValue.serverTimestamp()})
        .timeout(wait);

    return LocalSession(
      id: doc.id,
      teacherId: user.uid,
      courseId: courseId,
      courseName: courseName,
      room: room,
      secret: secret,
      stepSeconds: stepSeconds,
      startsAtMs: startsAt,
      endsAtMs: endsAt,
      offsetMs: _clock.offsetMs,
      courseCode: courseCode,
      section: section,
      number: sessionNumber,
    );
  }

  /// Alarga la sesión: los estudiantes pueden seguir registrándose hasta la
  /// nueva hora de cierre.
  Future<void> extendSession(String sessionId, int newEndMs) {
    return _sessions.doc(sessionId).update({
      'endsAt': Timestamp.fromMillisecondsSinceEpoch(newEndMs),
    });
  }

  /// Cuántas sesiones ha iniciado este docente para el curso.
  Future<int> countSessions(String courseId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0;
    try {
      final snap = await _sessions
          .where('teacherId', isEqualTo: uid)
          .where('courseId', isEqualTo: courseId)
          .count()
          .get()
          .timeout(const Duration(seconds: 8));
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Sesiones del curso con los estudiantes cuya asistencia está confirmada.
  Future<List<SessionAttendance>> loadCourseAttendance(String courseId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const <SessionAttendance>[];

    final snap = await _sessions
        .where('teacherId', isEqualTo: uid)
        .where('courseId', isEqualTo: courseId)
        .get()
        .timeout(const Duration(seconds: 15));

    final sessions = snap.docs.map(SessionInfo.fromDoc).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    return Future.wait(
      sessions.map((s) async {
        final claims = await _sessions
            .doc(s.id)
            .collection('claims')
            .get()
            .timeout(const Duration(seconds: 15));

        final present = <String>{};
        var review = 0;
        var pending = 0;
        var offline = 0;
        for (final d in claims.docs) {
          final data = d.data();
          switch (data['status']) {
            case 'validated':
              present.add(d.id);
              if (data['timeVerified'] != true) offline++;
            case 'review':
              review++;
            case 'pending':
              pending++;
          }
        }

        return SessionAttendance(
          startsAt: s.startsAt,
          endsAt: s.endsAt,
          presentIds: present,
          reviewCount: review,
          pendingCount: pending,
          offlineCount: offline,
        );
      }),
    );
  }

  /// Registro de un estudiante en cada sesión del curso, en orden cronológico.
  Future<List<StudentSessionRecord>> loadStudentRecords(
    String courseId,
    String studentId,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const <StudentSessionRecord>[];

    final snap = await _sessions
        .where('teacherId', isEqualTo: uid)
        .where('courseId', isEqualTo: courseId)
        .get()
        .timeout(const Duration(seconds: 15));

    final sessions = snap.docs.map(SessionInfo.fromDoc).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    return Future.wait(
      sessions.map((s) async {
        final doc = await _sessions
            .doc(s.id)
            .collection('claims')
            .doc(studentId)
            .get()
            .timeout(const Duration(seconds: 15));
        return StudentSessionRecord(
          session: s,
          claim: doc.exists ? ClaimInfo.fromDoc(doc) : null,
        );
      }),
    );
  }

  Future<String?> fetchSecret(String sessionId) async {
    final doc = await _sessions
        .doc(sessionId)
        .collection('private')
        .doc('secret')
        .get();
    return doc.data()?['secret'] as String?;
  }

  Stream<List<SessionInfo>> watchMySessions() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const <SessionInfo>[]);
    return _sessions.where('teacherId', isEqualTo: uid).snapshots().map((snap) {
      final list = snap.docs.map(SessionInfo.fromDoc).toList()
        ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
      return list.take(15).toList();
    });
  }

  Stream<List<ClaimInfo>> watchClaims(String sessionId) {
    return _sessions
        .doc(sessionId)
        .collection('claims')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(ClaimInfo.fromDoc).toList()
                ..sort((a, b) => a.scannedAt.compareTo(b.scannedAt)),
        );
  }

  /// Guarda el resultado de la validación (solo el docente puede).
  Future<void> applyValidation(
    String sessionId,
    List<ClaimUpdate> updates,
  ) async {
    final batch = _db.batch();
    for (final u in updates) {
      batch.update(_claimRef(sessionId, u.studentId), {
        'status': u.outcome.status.name,
        'reason': u.outcome.reason,
        'timeVerified': u.outcome.timeVerified,
        'validatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> reviewClaim(
    String sessionId,
    String studentId, {
    required bool approve,
  }) {
    return _claimRef(sessionId, studentId).update({
      'status': approve ? 'validated' : 'rejected',
      'reason': approve ? 'aprobado_por_docente' : 'rechazado_por_docente',
      'reviewedBy': _auth.currentUser?.uid,
      'validatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cierra la sesión antes de su hora de fin.
  Future<void> closeSession(String sessionId, int endMs) {
    return _sessions.doc(sessionId).update({
      'status': 'closed',
      'endsAt': Timestamp.fromMillisecondsSinceEpoch(endMs),
    });
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => AttendanceRepository(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
    ref.read(clockServiceProvider),
  ),
);
