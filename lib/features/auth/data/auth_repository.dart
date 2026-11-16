import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthRepository {
  AuthRepository(this._auth, this._db);
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role, // 'student' | 'teacher'
    String? studentCode,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;
    try {
      await user.updateDisplayName(name.trim());
      await _db.collection('users').doc(user.uid).set({
        'name': name.trim(),
        'email': email.trim(),
        'role': role,
        if (studentCode != null && studentCode.trim().isNotEmpty)
          'studentCode': studentCode.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      await user.delete(); // evita cuentas sin perfil si falla Firestore
      rethrow;
    }
  }

  /// Inicia sesión y devuelve el rol del usuario ('student' | 'teacher').
  Future<String> signIn({
    required String email,
    required String password,
    bool remember = true,
  }) async {
    // La persistencia configurable solo existe en web.
    if (kIsWeb) {
      await _auth.setPersistence(
        remember ? Persistence.LOCAL : Persistence.SESSION,
      );
    }
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final role = await fetchRole(cred.user!.uid);
    if (role == null) {
      await _auth.signOut();
      throw FirebaseAuthException(code: 'profile-not-found');
    }
    return role;
  }

  Future<String?> fetchRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['role'] as String?;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(FirebaseAuth.instance, FirebaseFirestore.instance),
);
