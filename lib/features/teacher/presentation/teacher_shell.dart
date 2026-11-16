import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/name_utils.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../data/teacher_notifications_data.dart';
import 'teacher_home_tab.dart';
import 'teacher_notifications_tab.dart';
import 'teacher_profile_tab.dart';

class TeacherShell extends ConsumerStatefulWidget {
  const TeacherShell({super.key});

  @override
  ConsumerState<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends ConsumerState<TeacherShell> {
  int _index = 0;
  static const _titles = [null, 'Notificaciones', 'Perfil'];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final fullName = displayNameOf(user?.displayName, user?.email);
    final unread = teacherUnreadCount(ref.watch(teacherNotificationsProvider));

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
                  initials: initialsOf(fullName),
                  onProfile: () => setState(() => _index = 2),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    children: [
                      const TeacherHomeTab(),
                      const TeacherNotificationsTab(),
                      TeacherProfileTab(
                        hasNotifications: unread > 0,
                        onOpenNotifications: () => setState(() => _index = 1),
                      ),
                    ],
                  ),
                ),
                AppBottomNav(
                  index: _index,
                  notificationsBadge: unread > 0,
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

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.initials,
    required this.onProfile,
  });

  final String? title;
  final String initials;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
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
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(width: 12),
          ],
          GestureDetector(
            onTap: onProfile,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.navy,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
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
