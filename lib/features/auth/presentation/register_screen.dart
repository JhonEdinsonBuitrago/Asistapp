import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_widgets.dart';

final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  String _role = 'student';
  bool _obscure = true;
  bool _accepted = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => _showInfo('Términos y Condiciones');
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => _showInfo('Política de Privacidad');
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _code, _pass, _confirm]) {
      c.dispose();
    }
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  /// 0 = vacía, 1 = débil, 2 = media, 3 = segura.
  int _strength(String p) {
    if (p.isEmpty) return 0;
    var points = 0;
    if (p.length >= 8) points++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) points++;
    if (RegExp(r'\d').hasMatch(p)) points++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) points++;
    if (p.length < 8 || points <= 1) return 1;
    return points >= 4 ? 3 : 2;
  }

  String _message(String code) => switch (code) {
    'email-already-in-use' => 'Ese correo ya está registrado.',
    'invalid-email' => 'El correo no es válido.',
    'weak-password' => 'La contraseña es muy débil.',
    'network-request-failed' => 'Sin conexión a internet.',
    _ => 'No se pudo crear la cuenta ($code).',
  };

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _showInfo(String title) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: const Text(
          'El contenido de este documento lo definirá la institución educativa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_accepted) {
      _snack('Debes aceptar los Términos y la Política de Privacidad.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .register(
            name: _name.text,
            email: _email.text,
            password: _pass.text,
            role: _role,
            studentCode: _role == 'student' ? _code.text : null,
          );
      if (!mounted) return;
      _snack('Cuenta creada correctamente');
      context.go(_role == 'teacher' ? '/teacher' : '/student');
    } on FirebaseAuthException catch (e) {
      if (mounted) _snack(_message(e.code));
    } catch (_) {
      if (mounted) _snack('Ocurrió un error. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF8A97A6)),
      prefixIcon: Icon(icon, color: AppColors.textMuted),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.chipBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _pill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: const BoxDecoration(
      color: Color(0xFFCFF3E8),
      borderRadius: BorderRadius.all(Radius.circular(20)),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.green,
      ),
    ),
  );

  Widget _hint(String text) => Text(
    text,
    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
  );

  @override
  Widget build(BuildContext context) {
    final strength = _strength(_pass.text);
    final passwordsMatch =
        _confirm.text.isNotEmpty && _confirm.text == _pass.text;
    const linkStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: AppColors.navy,
      decoration: TextDecoration.underline,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  AuthTopBar(
                    onBack: () =>
                        context.canPop() ? context.pop() : context.go('/'),
                    label: 'REGISTRO INSTITUCIONAL',
                    trailing: const Icon(
                      Icons.verified_user_outlined,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const AuthLogoCard(size: 76, verified: true),
                  const SizedBox(height: 12),
                  const Text(
                    'ASISTAPP',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Crea tu cuenta',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Registra tus datos institucionales para comenzar a verificar tu asistencia en clases.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  RoleToggle(
                    value: _role,
                    onChanged: (r) => setState(() => _role = r),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.all(Radius.circular(28)),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x140B3A5E),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Nombre
                          FieldLabel(
                            text: 'Nombre completo',
                            trailing: _hint('Obligatorio'),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            decoration: _decoration(
                              hint: 'ej. Sofía Martínez Valdés',
                              icon: Icons.person_outline,
                            ),
                            validator: (v) => (v == null || v.trim().length < 3)
                                ? 'Ingresa tu nombre completo'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // Correo
                          FieldLabel(
                            text: 'Correo institucional',
                            trailing: _pill('Institucional'),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: _decoration(
                              hint: 'ej. matricula@universidad.edu',
                              icon: Icons.badge_outlined,
                            ),
                            validator: (v) =>
                                _emailRegex.hasMatch(v?.trim() ?? '')
                                ? null
                                : 'Correo no válido',
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 14,
                                color: AppColors.green,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _hint(
                                  'Usa tu correo con dominio institucional activo.',
                                ),
                              ),
                            ],
                          ),

                          // Código estudiantil (solo estudiantes)
                          if (_role == 'student') ...[
                            const SizedBox(height: 16),
                            FieldLabel(
                              text: 'Código estudiantil',
                              trailing: _hint('Obligatorio'),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _code,
                              keyboardType: TextInputType.text,
                              decoration: _decoration(
                                hint: 'ej. 2022818',
                                icon: Icons.numbers,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Ingresa tu código estudiantil'
                                  : null,
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Contraseña
                          FieldLabel(
                            text: 'Contraseña',
                            trailing: _hint('Mín. 8 caracteres'),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _pass,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.newPassword],
                            onChanged: (_) => setState(() {}),
                            decoration: _decoration(
                              hint: '••••••••',
                              icon: Icons.lock_outline,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v == null || v.length < 8)
                                ? 'Mínimo 8 caracteres'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          _StrengthBar(level: strength),
                          const SizedBox(height: 16),

                          // Confirmar contraseña
                          const FieldLabel(text: 'Confirmar contraseña'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _confirm,
                            obscureText: _obscure,
                            onChanged: (_) => setState(() {}),
                            decoration: _decoration(
                              hint: '••••••••',
                              icon: Icons.lock_reset,
                              suffix: passwordsMatch
                                  ? const Icon(
                                      Icons.check_circle_outline,
                                      color: AppColors.green,
                                    )
                                  : null,
                            ),
                            validator: (v) => v != _pass.text
                                ? 'Las contraseñas no coinciden'
                                : null,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 14),

                          // Términos
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: _accepted,
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                onChanged: (v) =>
                                    setState(() => _accepted = v ?? false),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text.rich(
                                    TextSpan(
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        height: 1.4,
                                        color: AppColors.textMuted,
                                      ),
                                      children: [
                                        const TextSpan(text: 'Acepto los '),
                                        TextSpan(
                                          text: 'Términos y Condiciones',
                                          style: linkStyle,
                                          recognizer: _termsTap,
                                        ),
                                        const TextSpan(text: ' y la '),
                                        TextSpan(
                                          text: 'Política de Privacidad',
                                          style: linkStyle,
                                          recognizer: _privacyTap,
                                        ),
                                        const TextSpan(
                                          text: ' de AsistApp y de la institución educativa.',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          GradientButton(
                            label: 'Crear cuenta',
                            loading: _loading,
                            onPressed: _submit,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0E7A5F), Color(0xFF0B6B54)],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: AppColors.chipBackground,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => context.go('/login'),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '¿Ya tienes cuenta? ',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                              Text(
                                'Iniciar sesión',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: AppColors.navy,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StrengthBar extends StatelessWidget {
  const _StrengthBar({required this.level});
  final int level; // 0..3

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      1 => const Color(0xFFE5484D),
      2 => const Color(0xFFF5A623),
      3 => AppColors.green,
      _ => const Color(0xFFD6E0F0),
    };
    final label = switch (level) {
      1 => 'Seguridad: débil',
      2 => 'Seguridad: media',
      3 => 'Seguridad: alta',
      _ => 'Seguridad',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          children: List.generate(3, (i) {
            final filled = i < level;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                decoration: BoxDecoration(
                  color: filled ? color : const Color(0xFFD6E0F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
