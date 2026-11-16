import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/student_mock_data.dart';
import 'widgets/course_detail_widgets.dart';

class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  static const _demoSeconds = 14 * 60 + 28;

  CourseDetail? _detail;
  Timer? _timer;
  bool _active = false;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _detail = courseDetailById(widget.courseId);
    final session = _detail?.active;
    if (session != null) _beginSession(session.secondsLeft);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Inicia la cuenta regresiva de la clase en progreso.
  void _beginSession(int seconds) {
    _timer?.cancel();
    _active = true;
    _secondsLeft = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() {
          _active = false;
          _secondsLeft = 0;
        });
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  void _endSession() {
    _timer?.cancel();
    _active = false;
    _secondsLeft = 0;
  }

  void _toggleSimulation() {
    setState(() {
      if (_active) {
        _endSession();
      } else {
        _beginSession(_demoSeconds);
      }
    });
  }

  void _back() => context.canPop() ? context.pop() : context.go('/student');

  void _soon(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$text (próximamente)')));
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    if (d == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Curso no encontrado')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                _DetailTopBar(onBack: _back, onProfile: () => _soon('Perfil')),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    children: [
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: _back,
                            icon: const Icon(
                              Icons.chevron_left,
                              size: 20,
                              color: AppColors.navy,
                            ),
                            label: const Text(
                              'Mis cursos',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE3EBFA),
                              borderRadius: BorderRadius.all(
                                Radius.circular(20),
                              ),
                            ),
                            child: Text(
                              '${d.code} • ${d.group}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.menu_book_outlined,
                            size: 22,
                            color: AppColors.navy,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      CourseHeaderCard(
                        detail: d,
                        onMail: () => _soon('Contactar al docente'),
                      ),
                      const SizedBox(height: 16),
                      AttendanceBalanceCard(detail: d),
                      const SizedBox(height: 16),
                      ActiveClassCard(
                        active: _active,
                        classNumber: d.active?.number ?? d.nextClassNumber,
                        secondsLeft: _secondsLeft,
                        detectedRoom: d.active?.detectedRoom ?? d.room,
                        nextSession: d.nextSession,
                        onRegister: () =>
                            context.push('/student/course/${d.id}/scan'),
                        onToggleSimulation: _toggleSimulation,
                      ),
                      const SizedBox(height: 16),
                      DetailOptionTile(
                        icon: Icons.history,
                        title: 'Historial Completo de Asistencia',
                        subtitle: 'Marcas de tiempo, justificaciones y firmas',
                        onTap: () =>
                            context.push('/student/course/${d.id}/history'),
                      ),
                      const SizedBox(height: 12),
                      DetailOptionTile(
                        icon: Icons.assignment_outlined,
                        title: 'Justificar Falta Reciente',
                        subtitle: 'Adjunta comprobante médico o institucional',
                        chip: 'Plazo: ${d.justifyHours}h',
                        onTap: () => _soon('Justificación de faltas'),
                      ),
                      const SizedBox(height: 26),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Text(
                              'Próximas Sesiones Programadas',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Semana ${d.week} de ${d.totalWeeks}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (final s in d.upcoming)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: UpcomingSessionTile(session: s),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailTopBar extends StatelessWidget {
  const _DetailTopBar({required this.onBack, required this.onProfile});

  final VoidCallback onBack;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 20, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: AppColors.navy),
          ),
          SizedBox(
            width: 36,
            height: 30,
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.school, color: AppColors.navy, size: 26),
            ),
          ),
          const Spacer(),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'AsistApp',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                'Detalle del Curso',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
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
