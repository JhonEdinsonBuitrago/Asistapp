import 'attendance_models.dart';
import 'totp.dart';

class ValidationOutcome {
  const ValidationOutcome(
    this.status, {
    this.reason,
    this.timeVerified = false,
  });

  final ClaimStatus status;
  final String? reason;
  final bool timeVerified;
}

/// Reglas de validación de un registro. Es una función pura: no usa red.
class ClaimValidator {
  static const _onlineWindowMs =
      90 * 1000; // escrito casi al escanear = hubo conexión
  static const _toleranceMs = 30 * 1000; // diferencia de relojes aceptable
  static const _uploadSlackMs = 20 * 1000; // margen por la subida
  static const _syncDeadlineMs = 24 * 60 * 60 * 1000; // plazo de sincronización

  static ValidationOutcome validate({
    required Totp totp,
    required SessionInfo session,
    required ClaimInfo claim,
    required bool sharedDevice,
  }) {
    final synced = claim.syncedAt?.millisecondsSinceEpoch;
    if (synced == null) return const ValidationOutcome(ClaimStatus.pending);

    ValidationOutcome rejected(String reason) =>
        ValidationOutcome(ClaimStatus.rejected, reason: reason);

    final startsAt = session.startsAt.millisecondsSinceEpoch;
    final endsAt = session.endsAt.millisecondsSinceEpoch;

    // Hora del escaneo según el dispositivo, corregida con la diferencia que
    // había medido contra el servidor (si la conocía).
    final scanAdj = claim.scannedAt + claim.clockOffsetMs;

    // Si el registro llegó al servidor casi al instante de escanear, la hora
    // del servidor es la verdadera y no depende del reloj del teléfono.
    final writtenOnline = (synced - scanAdj).abs() <= _onlineWindowMs;
    final ref = writtenOnline ? synced : scanAdj;

    String? doubt;

    if (claim.method == 'qr') {
      final qrTs = claim.qrTimestamp;
      if (qrTs == null || !totp.verifyQr(qrTs, claim.code)) {
        return rejected('codigo_invalido');
      }
      if (qrTs < startsAt - _toleranceMs || qrTs > endsAt + _toleranceMs) {
        return rejected('fuera_de_sesion');
      }

      final delta = ref - qrTs;
      final maxDelay = totp.stepMs + 25 * 1000;

      if (writtenOnline) {
        if (delta > maxDelay + _uploadSlackMs) return rejected('qr_vencido');
        if (delta < -_toleranceMs) doubt = 'hora_no_coincide';
      } else {
        if (delta > maxDelay || delta < -_toleranceMs)
          doubt = 'hora_no_coincide';
        if (scanAdj > synced) doubt = 'hora_no_coincide';
      }
      if (synced - qrTs > _syncDeadlineMs) doubt ??= 'sincronizacion_tardia';
    } else {
      // Código manual de 6 dígitos: no trae la hora del QR.
      if (!totp.verifyPin(ref, claim.code)) return rejected('codigo_invalido');
      if (ref < startsAt - _toleranceMs || ref > endsAt + _toleranceMs) {
        return rejected('fuera_de_sesion');
      }
      if (!writtenOnline) doubt = 'ingreso_manual_sin_conexion';
      if (synced - ref > _syncDeadlineMs) doubt ??= 'sincronizacion_tardia';
    }

    if (sharedDevice) doubt = 'dispositivo_compartido';

    if (doubt != null) {
      return ValidationOutcome(
        ClaimStatus.review,
        reason: doubt,
        timeVerified: writtenOnline,
      );
    }
    return ValidationOutcome(
      ClaimStatus.validated,
      timeVerified: writtenOnline,
    );
  }
}
