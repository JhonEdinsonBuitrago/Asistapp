import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/name_utils.dart';
import '../data/notifications_data.dart';
import '../data/student_profile_data.dart';
import 'notifications_tab.dart';
import 'profile_tab.dart';
import 'student_home_tab.dart';

class StudentShell extends ConsumerStatefulWidget {
  const StudentShell({super.key});

  @override
  ConsumerState<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends ConsumerState<StudentShell> {
  int _index = 0;
  static const _titles = ['Inicio', 'Notificaciones', 'Perfil'];

  @override
  Widget build(BuildContext context) {
    final unread = unreadCount(ref.watch(notificationsProvider));
    final profile = ref.watch(studentProfileProvider).value;
    final authUser = FirebaseAuth.instance.currentUser;
    final fullName = displayNameOf(
      (profile?.name.isNotEmpty ?? false)
          ? profile!.name
          : authUser?.displayName,
      authUser?.email,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                _TopBar(
                  title: _titles[_index],
                  isProfile: _index == 2,
                  initials: initialsOf(fullName),
                  onProfile: () => setState(() => _index = 2),
                  onHelp: () => showSupportDialog(context),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    children: [
                      const StudentHomeTab(),
                      const NotificationsTab(),
                      ProfileTab(
                        onOpenNotifications: () => setState(() => _index = 1),
                      ),
                    ],
                  ),
                ),
                _BottomNav(
                  index: _index,
                  hasNotifications: unread > 0,
                  onChanged: (i) => setState(() => _index = i),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cabecera
// ---------------------------------------------------------------------------
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.isProfile,
    required this.initials,
    required this.onProfile,
    required this.onHelp,
  });

  final String title;
  final bool isProfile;
  final String initials;
  final VoidCallback onProfile;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 34,
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.school, color: AppColors.navy, size: 28),
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'AsistApp',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          if (isProfile) ...[
            IconButton(
              tooltip: 'Ayuda',
              onPressed: onHelp,
              icon: const Icon(Icons.help_outline, color: AppColors.navy),
            ),
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.navy,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ] else
            Material(
              color: AppColors.chipBackground,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onProfile,
                child: const Padding(
                  padding: EdgeInsets.all(9),
                  child: Icon(
                    Icons.person_outline,
                    size: 22,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Barra inferior
// ---------------------------------------------------------------------------
class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.index,
    required this.onChanged,
    required this.hasNotifications,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final bool hasNotifications;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x140B3A5E),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Inicio',
              selected: index == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.notifications_none,
              activeIcon: Icons.notifications,
              label: 'Notificaciones',
              selected: index == 1,
              badge: hasNotifications,
              onTap: () => onChanged(1),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'Perfil',
              selected: index == 2,
              onTap: () => onChanged(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final bool badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.navy : AppColors.textMuted;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(selected ? activeIcon : icon, size: 24, color: color),
                if (badge)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD92D20),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
