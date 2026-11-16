import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../features/teacher/presentation/student_attendance_detail_screen.dart';
import '../features/teacher/presentation/course_stats_screen.dart';
import '../features/teacher/presentation/session_setup_screen.dart';
import '../features/teacher/presentation/add_students_screen.dart';
import '../features/teacher/presentation/teacher_course_detail_screen.dart';
import '../features/teacher/presentation/create_course_screen.dart';
import '../features/teacher/presentation/teacher_shell.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/student/presentation/student_shell.dart';
import '../features/student/presentation/course_detail_screen.dart';
import '../features/attendance/presentation/attendance_saved_screen.dart';
import '../features/student/presentation/attendance_history_screen.dart';
import '../features/attendance/presentation/scan_qr_screen.dart';
import '../features/attendance/presentation/teacher_qr_screen.dart';
import '../features/student/data/attendance_history_data.dart';
import '../features/student/data/student_mock_data.dart';
import '../features/student/presentation/real_course_detail_screen.dart';
import '../features/student/presentation/real_history_screen.dart';
import '../features/justifications/presentation/student_justifications_screen.dart';
import '../features/justifications/presentation/teacher_justifications_screen.dart';

final _repo = AuthRepository(FirebaseAuth.instance, FirebaseFirestore.instance);

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final isPublic = const [
      '/',
      '/login',
      '/register',
      '/forgot-password',
    ].contains(state.matchedLocation);

    if (user == null) return isPublic ? null : '/';

    if (isPublic) {
      try {
        final role = await _repo.fetchRole(user.uid);
        if (role == null) return null;
        return role == 'teacher' ? '/teacher' : '/student';
      } catch (_) {
        return null;
      }
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/teacher/course/:id/student/:studentId',
      builder: (context, state) => StudentAttendanceDetailScreen(
        courseId: state.pathParameters['id']!,
        studentId: state.pathParameters['studentId']!,
      ),
    ),
    GoRoute(
      path: '/teacher/course/:id/stats',
      builder: (context, state) =>
          CourseStatsScreen(courseId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/teacher/course/:id/session',
      builder: (context, state) =>
          SessionSetupScreen(courseId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/teacher/course/:id/students',
      builder: (context, state) =>
          AddStudentsScreen(courseId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/teacher/course/:id',
      builder: (context, state) =>
          TeacherCourseDetailScreen(courseId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/teacher/courses/new',
      builder: (context, state) => const CreateCourseScreen(),
    ),
    GoRoute(
      path: '/student/course/:id/scan',
      builder: (context, state) =>
          ScanQrScreen(courseId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/teacher/session',
      builder: (context, state) => const TeacherQrScreen(),
    ),

    GoRoute(
      path: '/student/course/:id/history',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return historyFor(id) != null
            ? AttendanceHistoryScreen(courseId: id)
            : RealHistoryScreen(courseId: id);
      },
    ),
    GoRoute(
      path: '/student/course/:id/saved',
      builder: (context, state) => AttendanceSavedScreen(
        courseId: state.pathParameters['id']!,
        sessionId: state.uri.queryParameters['s'] ?? '',
        room: state.uri.queryParameters['room'],
        courseName: state.uri.queryParameters['name'],
      ),
    ),
    GoRoute(path: '/', builder: (context, state) => const WelcomeScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) =>
          ForgotPasswordScreen(initialEmail: state.extra as String?),
    ),
    GoRoute(
      path: '/student',
      builder: (context, state) => const StudentShell(),
    ),
    GoRoute(
      path: '/student/course/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        // Los cursos de ejemplo usan la pantalla de ejemplo; los reales, la real.
        return courseDetailById(id) != null
            ? CourseDetailScreen(courseId: id)
            : RealCourseDetailScreen(courseId: id);
      },
    ),
    GoRoute(
      path: '/teacher',
      builder: (context, state) => const TeacherShell(),
    ),
    GoRoute(
      path: '/student/justifications',
      builder: (context, state) => const StudentJustificationsScreen(),
    ),
    GoRoute(
      path: '/student/course/:id/justify',
      builder: (context, state) =>
          StudentJustificationsScreen(courseId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/teacher/justifications',
      builder: (context, state) => TeacherJustificationsScreen(
        courseId: state.uri.queryParameters['course'],
      ),
    ),
  ],
);
