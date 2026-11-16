import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// DATOS DE EJEMPLO: se reemplazarán cuando el programa y el ciclo del
// estudiante existan en Firestore.
const sampleStudentProgram = 'Ingeniería de Software';
const sampleStudentCycle = '2025-I';

class StudentProfileData {
  const StudentProfileData({
    required this.name,
    required this.email,
    this.studentCode,
    this.phone,
  });

  final String name;
  final String email;
  final String? studentCode;
  final String? phone;
}

/// Perfil del usuario, leído en tiempo real de `users/{uid}`.
final studentProfileProvider = StreamProvider.autoDispose<StudentProfileData?>((
  ref,
) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
        final d = doc.data();
        if (d == null) return null;
        return StudentProfileData(
          name: d['name'] as String? ?? '',
          email: d['email'] as String? ?? user.email ?? '',
          studentCode: d['studentCode'] as String?,
          phone: d['phone'] as String?,
        );
      });
});
