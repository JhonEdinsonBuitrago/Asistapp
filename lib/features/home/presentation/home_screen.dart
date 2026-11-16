import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/data/auth_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.role});
  final String role; // 'student' | 'teacher'

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final isTeacher = role == 'teacher';

    return Scaffold(
      appBar: AppBar(
        title: Text(isTeacher ? 'Panel docente' : 'Panel estudiante'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isTeacher ? Icons.assignment_ind : Icons.school,
                size: 64,
                color: AppColors.green,
              ),
              const SizedBox(height: 16),
              Text(
                'Hola, ${user?.displayName ?? ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user?.email ?? '',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 4),
              Text(
                isTeacher
                    ? 'Sesión iniciada como docente'
                    : 'Sesión iniciada como estudiante',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              if (isTeacher) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.push('/teacher/session'),
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Iniciar sesión de clase (QR)'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
