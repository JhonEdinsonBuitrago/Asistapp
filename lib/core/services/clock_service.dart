import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mide la diferencia entre el reloj del dispositivo y el del servidor.
/// Solo funciona con conexión; sin ella se asume diferencia 0.
class ClockService {
  ClockService(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  int _offsetMs = 0;
  bool _known = false;

  int get offsetMs => _offsetMs;
  bool get isKnown => _known;

  /// Hora estimada del servidor, en milisegundos.
  int nowMs() => DateTime.now().millisecondsSinceEpoch + _offsetMs;

  Future<bool> sync() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final ref = _db.collection('users').doc(user.uid);
    try {
      final t0 = DateTime.now().millisecondsSinceEpoch;
      await ref
          .update({'clockProbe': FieldValue.serverTimestamp()})
          .timeout(const Duration(seconds: 8));
      final snap = await ref
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 8));
      final t1 = DateTime.now().millisecondsSinceEpoch;
      final server =
          (snap.data()?['clockProbe'] as Timestamp?)?.millisecondsSinceEpoch;
      if (server == null) return false;
      _offsetMs = server - (t0 + t1) ~/ 2;
      _known = true;
      return true;
    } catch (_) {
      return false;
    }
  }
}

final clockServiceProvider = Provider<ClockService>(
  (ref) => ClockService(FirebaseFirestore.instance, FirebaseAuth.instance),
);

/// Identificador anónimo de esta instalación de la app.
/// Sirve para detectar un mismo teléfono registrando a varios estudiantes.
Future<String> installId() async {
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString('install_id');
  if (id == null) {
    final r = Random.secure();
    id = List.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await prefs.setString('install_id', id);
  }
  return id;
}
