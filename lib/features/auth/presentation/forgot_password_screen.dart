import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_widgets.dart';

const _mint = Color(0xFFCFF3E8);
final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  /// Correo escrito en el login, para no tener que volver a escribirlo.
  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  Timer? _timer;
  bool _loading = false;
  bool _sent = false;
  int _cooldown = 0;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    super.dispose();
  }

  String _message(String code) => switch (code) {
    'invalid-email' => 'El correo no es válido.',
    'too-many-requests' => 'Demasiados intentos. Intenta más tarde.',
    'network-request-failed' => 'Sin conexión a internet.',
    _ => 'No se pudo enviar el enlace ($code).',
  };

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cooldown = _cooldown > 0 ? _cooldown - 1 : 0);
      if (_cooldown <= 0) t.cancel();
    });
  }

  void _onSent() {
    setState(() => _sent = true);
    _startCooldown(60);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(_email.text);
      if (mounted) _onSent();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // Misma respuesta exista o no la cuenta, para no revelar qué correos están registrados.
      if (e.code == 'user-not-found') {
        _onSent();
      } else {
        _snack(_message(e.code));
      }
    } catch (_) {
      if (mounted) _snack('Ocurrió un error. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _back() => context.canPop() ? context.pop() : context.go('/login');

  @override
  Widget build(BuildContext context) {
    final label = _cooldown > 0
        ? 'Reenviar en ${_cooldown}s'
        : (_sent ? 'Reenviar enlace' : 'Enviar enlace de recuperación');

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
                  _TopBar(onBack: _back),
                  const SizedBox(height: 12),
                  const _SecureBadge(),
                  const SizedBox(height: 16),
                  _buildHero(),
                  const SizedBox(height: 16),
                  _buildForm(label),
                  const SizedBox(height: 16),
                  const _InfoCard(),
                  const SizedBox(height: 20),
                  const _Footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
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
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.navy, AppColors.green],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.lock_reset,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(
                    Icons.verified_user,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            '¿Olvidaste tu contraseña?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'No te preocupes. Ingresa el correo electrónico institucional asociado a tu cuenta de estudiante o docente y te enviaremos un enlace seguro para restablecerla.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(String buttonLabel) {
    return Container(
      width: double.infinity,
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
            FieldLabel(
              text: 'Correo electrónico institucional',
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.chipBackground,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                child: const Text(
                  'Institucional',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              onFieldSubmitted: (_) => _cooldown > 0 ? null : _submit(),
              decoration: InputDecoration(
                hintText: 'ej. matricula@universidad.edu',
                hintStyle: const TextStyle(color: Color(0xFF8A97A6)),
                prefixIcon: const Icon(
                  Icons.alternate_email,
                  color: AppColors.textMuted,
                ),
                filled: true,
                fillColor: AppColors.chipBackground,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (v) => _emailRegex.hasMatch(v?.trim() ?? '')
                  ? null
                  : 'Correo no válido',
            ),
            const SizedBox(height: 10),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 15,
                  color: AppColors.textMuted,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Enviaremos un enlace de un solo uso con validez limitada.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            if (_sent) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: _mint,
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.mark_email_read_outlined,
                      size: 20,
                      color: AppColors.green,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Si el correo está registrado, te enviamos un enlace para restablecer tu contraseña. Revisa también la carpeta de spam.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Opacity(
              opacity: _cooldown > 0 ? 0.6 : 1,
              child: GradientButton(
                label: buttonLabel,
                loading: _loading,
                onPressed: _cooldown > 0 ? null : _submit,
                gradient: const LinearGradient(
                  colors: [Color(0xFF0E7A5F), Color(0xFF0B6B54)],
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _back,
              icon: const Icon(
                Icons.arrow_back,
                size: 16,
                color: AppColors.navy,
              ),
              label: const Text(
                'Volver a Iniciar sesión',
                style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, color: AppColors.navy),
        ),
        const Spacer(),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'ASISTAPP',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: AppColors.green,
              ),
            ),
            Text(
              'Recuperar Contraseña',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: AppColors.chipBackground,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: const Icon(
            Icons.person_outline,
            size: 22,
            color: AppColors.navy,
          ),
        ),
      ],
    );
  }
}

class _SecureBadge extends StatelessWidget {
  const _SecureBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: _mint,
        borderRadius: BorderRadius.all(Radius.circular(30)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_outlined, size: 14, color: AppColors.green),
          SizedBox(width: 8),
          Text(
            'RECUPERACIÓN SEGURA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppColors.green,
            ),
          ),
          SizedBox(width: 10),
          Text(
            'TLS 1.3',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    const link = TextStyle(
      fontWeight: FontWeight.w700,
      color: AppColors.navy,
      decoration: TextDecoration.underline,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.chipBackground,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: _mint,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: const Icon(
              Icons.support_agent,
              color: AppColors.green,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Cambiaste de correo institucional?',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: AppColors.textMuted,
                    ),
                    children: [
                      TextSpan(text: 'Contacta a '),
                      TextSpan(text: 'Soporte del Campus', style: link),
                      TextSpan(text: ' o la '),
                      TextSpan(text: 'Mesa de Ayuda TI', style: link),
                      TextSpan(
                        text: ' de tu facultad para reasignar tu credencial digital.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.textMuted,
    );
    return const Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 13, color: AppColors.textMuted),
                SizedBox(width: 6),
                Text('Cifrado de extremo\na extremo', style: style),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 13,
                  color: AppColors.textMuted,
                ),
                SizedBox(width: 6),
                Text(
                  'Conexión protegida con\nServicios Escolares',
                  style: style,
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 10),
        Text(
          'Universidad Digital © Todos los derechos reservados',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
