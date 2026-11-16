import 'package:cloud_firestore/cloud_firestore.dart';

enum ClaimStatus { pending, validated, review, rejected }

ClaimStatus claimStatusFrom(String? s) => switch (s) {
  'validated' => ClaimStatus.validated,
  'review' => ClaimStatus.review,
  'rejected' => ClaimStatus.rejected,
  _ => ClaimStatus.pending,
};

String reasonText(String? code) => switch (code) {
  'codigo_invalido' => 'Código inválido',
  'fuera_de_sesion' => 'Fuera del horario de la sesión',
  'qr_vencido' => 'El QR ya había vencido al escanearlo',
  'hora_no_coincide' => 'La hora del dispositivo no coincide con la del QR',
  'sincronizacion_tardia' => 'Sincronizado después de 24 horas',
  'ingreso_manual_sin_conexion' => 'Código manual escrito sin conexión',
  'dispositivo_compartido' => 'Mismo dispositivo usado por varios estudiantes',
  'aprobado_por_docente' => 'Aprobado por el docente',
  'rechazado_por_docente' => 'Rechazado por el docente',
  _ => '',
};

/// Contenido del QR: asistapp:1:<idSesion>:<horaDelQR>:<codigo de 12 caracteres>
String buildQrPayload({
  required String sessionId,
  required int timestampMs,
  required String code,
}) => 'asistapp:1:$sessionId:$timestampMs:$code';

({String sessionId, int timestamp, String code})? parseQrPayload(String raw) {
  final p = raw.trim().split(':');
  if (p.length != 5 || p[0] != 'asistapp' || p[1] != '1') return null;
  final ts = int.tryParse(p[3]);
  if (p[2].isEmpty || ts == null || !RegExp(r'^[0-9a-f]{12}$').hasMatch(p[4])) {
    return null;
  }
  return (sessionId: p[2], timestamp: ts, code: p[4]);
}

class AlreadyRegisteredException implements Exception {}

class OfflineException implements Exception {}

class SessionInfo {
  const SessionInfo({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.room,
    required this.teacherId,
    required this.startsAt,
    required this.endsAt,
    required this.stepSeconds,
  });

  final String id;
  final String courseId;
  final String courseName;
  final String room;
  final String teacherId;
  final DateTime startsAt;
  final DateTime endsAt;
  final int stepSeconds;

  factory SessionInfo.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return SessionInfo(
      id: doc.id,
      courseId: d['courseId'] as String? ?? '',
      courseName: d['courseName'] as String? ?? 'Clase',
      room: d['room'] as String? ?? '',
      teacherId: d['teacherId'] as String? ?? '',
      startsAt: (d['startsAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endsAt: (d['endsAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      stepSeconds: (d['stepSeconds'] as num?)?.toInt() ?? 20,
    );
  }
}

class ClaimInfo {
  const ClaimInfo({
    required this.studentId,
    required this.studentName,
    required this.method,
    required this.code,
    required this.scannedAt,
    required this.clockOffsetMs,
    required this.offsetKnown,
    required this.deviceId,
    required this.status,
    required this.timeVerified,
    required this.reviewed,
    required this.hasPendingWrites,
    this.qrTimestamp,
    this.syncedAt,
    this.reason,
  });

  final String studentId;
  final String studentName;
  final String method; // 'qr' | 'pin'
  final String code;
  final int? qrTimestamp;
  final int scannedAt; // hora del dispositivo (ms)
  final int clockOffsetMs;
  final bool offsetKnown;
  final String deviceId;
  final DateTime? syncedAt; // hora del servidor al recibirlo
  final ClaimStatus status;
  final String? reason;
  final bool timeVerified;
  final bool reviewed; // decidido manualmente por el docente
  final bool hasPendingWrites; // todavía no llegó al servidor

  factory ClaimInfo.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return ClaimInfo(
      studentId: d['studentId'] as String? ?? doc.id,
      studentName: d['studentName'] as String? ?? '',
      method: d['method'] as String? ?? 'qr',
      code: d['code'] as String? ?? '',
      qrTimestamp: (d['qrTimestamp'] as num?)?.toInt(),
      scannedAt: (d['scannedAt'] as num?)?.toInt() ?? 0,
      clockOffsetMs: (d['clockOffsetMs'] as num?)?.toInt() ?? 0,
      offsetKnown: d['offsetKnown'] == true,
      deviceId: d['deviceId'] as String? ?? '',
      syncedAt: (d['syncedAt'] as Timestamp?)?.toDate(),
      status: claimStatusFrom(d['status'] as String?),
      reason: d['reason'] as String?,
      timeVerified: d['timeVerified'] == true,
      reviewed: d['reviewedBy'] != null,
      hasPendingWrites: doc.metadata.hasPendingWrites,
    );
  }
}
