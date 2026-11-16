import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Códigos temporales (TOTP, RFC 6238) con HMAC-SHA1.
/// El paso se alinea a la hora Unix, así docente y servidor calculan lo mismo
/// sin comunicarse.
class Totp {
  Totp(this.secret, {this.stepSeconds = 20});

  /// Clave de la sesión, en base64.
  final String secret;
  final int stepSeconds;

  static String generateSecret() {
    final r = Random.secure();
    return base64Encode(List<int>.generate(20, (_) => r.nextInt(256)));
  }

  int get stepMs => stepSeconds * 1000;
  int stepOf(int unixMs) => unixMs ~/ stepMs;
  int stepStartMs(int unixMs) => stepOf(unixMs) * stepMs;
  int msToNextStep(int unixMs) => stepMs - (unixMs % stepMs);

  List<int> _hmac(int step) {
    // 8 bytes: 4 ceros + el contador en 32 bits (evita enteros de 64 bits, que
    // no existen en web).
    final msg = ByteData(8)..setUint32(4, step);
    return Hmac(
      sha1,
      base64Decode(secret),
    ).convert(msg.buffer.asUint8List()).bytes;
  }

  /// Código de 6 dígitos para escribir a mano.
  String pin(int step) {
    final h = _hmac(step);
    final o = h[19] & 0x0f;
    final bin =
        ((h[o] & 0x7f) << 24) |
        ((h[o + 1] & 0xff) << 16) |
        ((h[o + 2] & 0xff) << 8) |
        (h[o + 3] & 0xff);
    return (bin % 1000000).toString().padLeft(6, '0');
  }

  /// Código largo (48 bits) que viaja dentro del QR.
  String qrCode(int step) =>
      _hmac(step)
          .take(6)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

  bool verifyQr(int qrTimestampMs, String code) =>
      qrCode(stepOf(qrTimestampMs)) == code;

  /// Acepta el paso de [timeMs] y uno anterior y posterior.
  bool verifyPin(int timeMs, String code, {int tolerance = 1}) {
    final base = stepOf(timeMs);
    for (var d = -tolerance; d <= tolerance; d++) {
      if (pin(base + d) == code) return true;
    }
    return false;
  }
}
