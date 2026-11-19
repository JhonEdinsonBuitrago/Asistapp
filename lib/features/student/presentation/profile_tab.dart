import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/name_utils.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../auth/data/auth_repository.dart';
import '../data/notifications_data.dart';
import '../data/student_profile_data.dart';
import '../data/student_courses_data.dart';

const _teal = Color(0xFF066A5C);
const _mint = Color(0xFFD7F5EA);
const _blueBg = Color(0xFFE3EBFA);
const _red = Color(0xFFD92D20);
const _redBg = Color(0xFFFEE2E2);

const _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(24)),
  boxShadow: [
    BoxShadow(color: Color(0x120B3A5E), blurRadius: 16, offset: Offset(0, 6)),
  ],
);

void showInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.navy,
        ),
      ),
      content: Text(message, style: const TextStyle(height: 1.4)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

void showSupportDialog(BuildContext context) => showInfoDialog(
  context,
  title: 'Ayuda y soporte',
  message: 'Las preguntas frecuentes y el contacto de soporte técnico los definirá la institución educativa.',
);

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key, required this.onOpenNotifications});

  /// Cambia a la pestaña de notificaciones.
  final VoidCallback onOpenNotifications;

  void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _editProfile(
    BuildContext context,
    String name,
    StudentProfileData? profile,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        initialName: name,
        initialPhone: profile?.phone ?? '',
        studentCode: profile?.studentCode,
      ),
    );
    if (saved == true && context.mounted) _snack(context, 'Perfil actualizado');
  }

  Future<void> _changePassword(
    BuildContext context,
    WidgetRef ref,
    String email,
  ) async {
    if (email.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          '¿Cambiar tu contraseña?',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy),
        ),
        content: Text(
          'Te enviaremos un enlace a $email para que elijas una contraseña nueva. Revisa también la carpeta de spam.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Enviar enlace'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (context.mounted) _snack(context, 'Te enviamos un enlace a $email');
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      _snack(
        context,
        e.code == 'too-many-requests'
            ? 'Demasiados intentos. Intenta más tarde.'
            : 'No se pudo enviar el enlace (${e.code}).',
      );
    } catch (_) {
      if (context.mounted) _snack(context, 'No se pudo enviar el enlace.');
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          '¿Cerrar sesión?',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy),
        ),
        content: const Text('Tendrás que iniciar sesión de nuevo para entrar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cerrar sesión', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(authRepositoryProvider).signOut();
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final profile = ref.watch(studentProfileProvider).value;
    final hasUnread = unreadCount(ref.watch(notificationsProvider)) > 0;

    final fullName = displayNameOf(
      (profile?.name.isNotEmpty ?? false) ? profile!.name : user?.displayName,
      user?.email,
    );
    final email = (profile?.email.isNotEmpty ?? false)
        ? profile!.email
        : (user?.email ?? '');
    final code = profile?.studentCode;

    // Datos reales si el estudiante tiene cursos; si no, datos de ejemplo.
    final overview = ref.watch(studentOverviewProvider).value;
    final attendanceText = overview?.attendance == null
        ? '—'
        : '${overview!.attendance!.round()}%';
    final courses = overview?.courses.length ?? 0;
    final critical = overview?.riskCount ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _HeaderCard(
          name: fullName,
          email: email,
          initials: initialsOf(fullName),
          code: code,
          onPhoto: () =>
              _snack(context, 'Cambiar foto de perfil (próximamente)'),
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.percent,
                  iconBg: _mint,
                  iconColor: _teal,
                  value: attendanceText,
                  label: 'Asistencia global',
                  valueColor: AppColors.navy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.menu_book_outlined,
                  iconBg: _blueBg,
                  iconColor: AppColors.navy,
                  value: '$courses',
                  label: 'Cursos activos',
                  valueColor: AppColors.navy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.warning_amber_rounded,
                  iconBg: critical > 0 ? _redBg : _blueBg,
                  iconColor: critical > 0 ? _red : AppColors.navy,
                  value: '$critical',
                  label: 'Faltas críticas',
                  valueColor: critical > 0 ? _red : AppColors.navy,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: _cardDecoration,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              _MenuRow(
                icon: Icons.person_outline,
                title: 'Editar perfil',
                subtitle: 'Datos personales, teléfono y foto',
                onTap: () => _editProfile(context, fullName, profile),
              ),
              _MenuRow(
                icon: Icons.lock_reset,
                title: 'Cambiar contraseña',
                subtitle: 'Seguridad y autenticación de cuenta',
                onTap: () => _changePassword(context, ref, email),
              ),
              _MenuRow(
                icon: Icons.notifications_active_outlined,
                title: 'Notificaciones',
                subtitle: 'Alertas de asistencia y recordatorios',
                dot: hasUnread,
                onTap: onOpenNotifications,
              ),
              _MenuRow(
                icon: Icons.support_agent,
                title: 'Ayuda / Soporte',
                subtitle: 'Preguntas frecuentes y ticket técnico',
                onTap: () => showSupportDialog(context),
              ),
              _MenuRow(
                icon: Icons.gavel_outlined,
                title: 'Términos y Privacidad',
                subtitle: 'Reglamento y tratamiento de datos',
                onTap: () => showInfoDialog(
                  context,
                  title: 'Términos y Privacidad',
                  message: 'El reglamento y el tratamiento de datos personales los definirá la institución educativa.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Material(
          color: _redBg,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _logout(context, ref),
            child: const SizedBox(
              height: 56,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, color: _red, size: 21),
                  SizedBox(width: 10),
                  Text(
                    'Cerrar sesión',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: _red,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Cabecera con foto, nombre y datos
// ---------------------------------------------------------------------------
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.name,
    required this.email,
    required this.initials,
    required this.onPhoto,
    this.code,
  });

  final String name;
  final String email;
  final String initials;
  final String? code;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration,
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFBFEFE3), Color(0xFFC9D8F2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: 0.15),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor: AppColors.navy,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 2,
                bottom: 2,
                child: Material(
                  color: const Color(0xFF0A2F52),
                  shape: const CircleBorder(
                    side: BorderSide(color: Colors.white, width: 3),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onPhoto,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.photo_camera_outlined,
                        size: 17,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.school_outlined,
                size: 15,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  email,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (code != null && code!.isNotEmpty)
                _ProfileChip('Código: $code'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: _blueBg,
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Estadísticas
// ---------------------------------------------------------------------------
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: _cardDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: valueColor,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Menú
// ---------------------------------------------------------------------------
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.dot = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: _blueBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: AppColors.navy),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      if (dot) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFB4BFD0)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Editar perfil
// ---------------------------------------------------------------------------
class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.initialName,
    required this.initialPhone,
    this.studentCode,
  });

  final String initialName;
  final String initialPhone;
  final String? studentCode;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.initialPhone,
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _validatePhone(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null; // es opcional
    final digits = t.replaceAll(RegExp(r'[\s+\-()]'), '');
    return RegExp(r'^\d{7,15}$').hasMatch(digits) ? null : 'Teléfono no válido';
  }

  InputDecoration _decoration(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: AppColors.textMuted),
    filled: true,
    fillColor: AppColors.chipBackground,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide.none,
    ),
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final name = _name.text.trim();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'name': name, 'phone': _phone.text.trim()})
          .timeout(const Duration(seconds: 12));
      await user.updateDisplayName(name);
      if (mounted) Navigator.of(context).pop(true);
    } on TimeoutException {
      if (mounted) {
        setState(
          () => _error = 'Sin conexión. Revisa tu internet e intenta de nuevo.',
        );
      }
    } catch (_) {
      if (mounted)
        setState(() => _error = 'No se pudieron guardar los cambios.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6E0F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Editar perfil',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.studentCode == null
                      ? 'El correo no se puede cambiar.'
                      : 'El correo y el código estudiantil (${widget.studentCode}) no se pueden cambiar.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nombre completo',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration(
                    'Tu nombre completo',
                    Icons.person_outline,
                  ),
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Ingresa tu nombre completo'
                      : null,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Teléfono (opcional)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: _decoration(
                    'ej. 3001234567',
                    Icons.phone_outlined,
                  ),
                  validator: _validatePhone,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(color: _red, fontSize: 12.5),
                  ),
                ],
                const SizedBox(height: 18),
                GradientButton(
                  label: 'Guardar cambios',
                  icon: Icons.check,
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
