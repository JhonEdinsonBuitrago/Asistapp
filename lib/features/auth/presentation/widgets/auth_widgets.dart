import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Barra superior: botón de volver, insignia con texto y (opcional) un
/// elemento a la derecha. Con [trailing] la insignia queda centrada.
class AuthTopBar extends StatelessWidget {
  const AuthTopBar({
    super.key,
    required this.onBack,
    required this.label,
    this.trailing,
  });

  final VoidCallback onBack;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final back = Material(
      color: AppColors.chipBackground,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onBack,
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.arrow_back, color: AppColors.navy, size: 22),
        ),
      ),
    );

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.chipBackground,
        borderRadius: BorderRadius.all(Radius.circular(30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(radius: 4, backgroundColor: AppColors.green),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );

    if (trailing == null) {
      return Row(children: [back, const Spacer(), badge]);
    }
    return Row(
      children: [
        back,
        Expanded(child: Center(child: badge)),
        SizedBox(width: 42, child: Center(child: trailing)),
      ],
    );
  }
}

/// Tarjeta del logo, con sello verde de verificación opcional.
class AuthLogoCard extends StatelessWidget {
  const AuthLogoCard({super.key, this.size = 84, this.verified = false});

  final double size;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(size * 0.14),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1F0B3A5E),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.school, size: size * 0.48, color: AppColors.navy),
          ),
        ),
        if (verified)
          Positioned(
            right: -6,
            bottom: -6,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.check, size: 14, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

/// Selector Estudiante / Docente.
class RoleToggle extends StatelessWidget {
  const RoleToggle({super.key, required this.value, required this.onChanged});

  final String value; // 'student' | 'teacher'
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: AppColors.chipBackground,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RoleOption(
              icon: Icons.school_outlined,
              label: 'Estudiante',
              selected: value == 'student',
              onTap: () => onChanged('student'),
            ),
          ),
          Expanded(
            child: _RoleOption(
              icon: Icons.assignment_ind_outlined,
              label: 'Docente',
              selected: value == 'teacher',
              onTap: () => onChanged('teacher'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x1A0B3A5E),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? AppColors.navy : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.navy : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Etiqueta de un campo: icono opcional a la izquierda y texto/elemento a la derecha.
class FieldLabel extends StatelessWidget {
  const FieldLabel({super.key, required this.text, this.icon, this.trailing});

  final String text;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: AppColors.navy),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
