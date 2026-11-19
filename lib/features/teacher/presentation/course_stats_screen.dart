import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/name_utils.dart';
import '../data/course_repository.dart';
import '../data/course_stats_data.dart';
import '../data/enrollment_repository.dart';
import '../../justifications/data/justification_data.dart';

const _teal = Color(0xFF066A5C);
const _mint = Color(0xFFD7F5EA);
const _mintStrong = Color(0xFF9DEBD9);
const _blueBg = Color(0xFFE3EBFA);
const _soft = Color(0xFFEFF3FC);
const _navyBtn = Color(0xFF0A2F52);
const _red = Color(0xFFD92D20);
const _redDark = Color(0xFFB3261E);
const _redBg = Color(0xFFFCE8E8);
const _redBorder = Color(0xFFF3C6C6);
const _amber = Color(0xFFF5A623);
const _amberFg = Color(0xFFB45309);
const _amberBg = Color(0xFFFFE8CC);
const _brown = Color(0xFF7A3E0B);
const _barBlue = Color(0xFF1F5A8C);

const _cardDeco = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(24)),
  boxShadow: [
    BoxShadow(color: Color(0x120B3A5E), blurRadius: 16, offset: Offset(0, 6)),
  ],
);

double _round1(double v) => (v * 10).round() / 10;

class CourseStatsScreen extends ConsumerStatefulWidget {
  const CourseStatsScreen({super.key, required this.courseId});

  final String courseId;

  @override
  ConsumerState<CourseStatsScreen> createState() => _CourseStatsScreenState();
}

class _CourseStatsScreenState extends ConsumerState<CourseStatsScreen> {
  static const _pageSize = 6;

  int _filter = 0; // 0 todos (orden), 1 críticos, 2 atención, 3 en regla
  bool _desc = true;
  bool _expanded = false;

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/teacher/course/${widget.courseId}');
    }
  }

  // ------------------------------ Datos ------------------------------

  List<StatsStudent> _visible(CourseStatsVm vm) {
    final list = vm.students.where((s) {
      return switch (_filter) {
        1 => s.isCritical,
        2 => s.isAttention,
        3 => s.isInOrder,
        _ => true,
      };
    }).toList();

    list.sort((a, b) {
      final c = a.faultPercent.compareTo(b.faultPercent);
      if (c != 0) return _desc ? -c : c;
      return normalizeText(a.name).compareTo(normalizeText(b.name));
    });
    return list;
  }

  // ------------------------------ Acciones ------------------------------

  void _showCopyDialog({
    required String title,
    required String message,
    List<String> recipients = const [],
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: _soft,
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
                child: Text(message, style: const TextStyle(height: 1.4)),
              ),
              if (recipients.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Destinatarios (${recipients.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final r in recipients)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _redBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          r,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _red,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'El envío automático llegará con las notificaciones. Mientras tanto, copia el mensaje y envíalo por tu medio habitual.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: message));
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) _snack('Mensaje copiado');
            },
            child: const Text('Copiar mensaje'),
          ),
        ],
      ),
    );
  }

  void _cite(StatsStudent s, CourseStatsVm vm) {
    _showCopyDialog(
      title: 'Citar a ${s.firstName}',
      message:
          'Hola ${s.firstName}, en ${vm.name} superaste el máximo de ${vm.maxAbsences} inasistencias (llevas ${s.absences} de ${s.held} clases dictadas). '
          'Te pido acercarte para revisar tu situación académica y, si tienes soportes de justificación, traerlos.',
    );
  }

  void _alert(StatsStudent s, CourseStatsVm vm) {
    _showCopyDialog(
      title: 'Alerta para ${s.firstName}',
      message:
          'Hola ${s.firstName}, en ${vm.name} llevas ${s.absences} inasistencias y el máximo permitido es ${vm.maxAbsences}. '
          'Una falta más puede afectar tu derecho a presentar la evaluación final. Habla con tu docente y, si tienes soportes, radícalos cuanto antes.',
    );
  }

  void _massAlert(CourseStatsVm vm) {
    final names = [
      for (final s in vm.students)
        if (s.isCritical) s.name,
    ];
    _showCopyDialog(
      title: 'Alerta masiva',
      message:
          'Hola, en ${vm.name} alcanzaste o superaste el máximo de ${vm.maxAbsences} inasistencias permitido. '
          'Esto puede afectar tu derecho a presentar la evaluación final. Acércate al docente y, si tienes soportes de justificación, radícalos cuanto antes.',
      recipients: names,
    );
  }

  String _report(CourseStatsVm vm) {
    final rows = [...vm.students]
      ..sort((a, b) => b.faultPercent.compareTo(a.faultPercent));
    final buf = StringBuffer()
      ..writeln('Curso\t${vm.name}')
      ..writeln('Código\t${vm.code}')
      ..writeln('Clases dictadas\t${vm.held} de ${vm.total}')
      ..writeln('Máximo de faltas\t${vm.maxAbsences}')
      ..writeln()
      ..writeln('Matrícula\tNombre\tFaltas\tClases dictadas\t% Faltas\tEstado');
    for (final s in rows) {
      buf.writeln(
        '${s.code}\t${s.name}\t${s.absences}\t${s.held}\t${s.faultPercent.toStringAsFixed(1)}%\t${riskLabel(s.risk)}',
      );
    }
    return buf.toString();
  }

  void _export(CourseStatsVm vm) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Exportar informe',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy),
        ),
        content: const Text(
          'La descarga en PDF o Excel llegará más adelante. Mientras tanto puedes copiar el informe como tabla y pegarlo en Excel o Google Sheets.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _report(vm)));
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) _snack('Informe copiado. Pégalo en Excel.');
            },
            child: const Text('Copiar tabla'),
          ),
        ],
      ),
    );
  }

  // ------------------------------ Interfaz ------------------------------

  Widget _scaffold(Widget body) {
    final user = FirebaseAuth.instance.currentUser;
    final initials = initialsOf(displayNameOf(user?.displayName, user?.email));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                _TopBar(onBack: _back, initials: initials),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(myCoursesProvider);
    final course = coursesAsync.value
        ?.where((c) => c.id == widget.courseId)
        .firstOrNull;
    if (course == null) {
      return _scaffold(
        Center(
          child: coursesAsync.isLoading
              ? const CircularProgressIndicator()
              : const Text('Curso no encontrado'),
        ),
      );
    }

    final attendance = ref.watch(courseAttendanceProvider(widget.courseId));
    return attendance.when(
      loading: () =>
          _scaffold(const Center(child: CircularProgressIndicator())),
      error: (e, _) => _scaffold(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No se pudieron cargar las estadísticas. Revisa tu conexión.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _red, height: 1.4),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.invalidate(courseAttendanceProvider(widget.courseId)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (sessions) {
        final enrolled =
            ref.watch(enrolledStudentsProvider(widget.courseId)).value ??
            const <EnrolledStudent>[];
        final enrolledIds = {for (final e in enrolled) e.id};
        final justifiedMarks =
            (ref.watch(teacherJustificationsProvider).value ??
                    const <JustificationInfo>[])
                .where(
                  (j) =>
                      j.courseId == widget.courseId &&
                      j.status == JustificationStatus.approved &&
                      enrolledIds.contains(j.studentId),
                )
                .length;
        final vm = buildRealStats(
          course: course,
          enrolled: enrolled,
          sessions: sessions,
          now: DateTime.now(),
          justifiedMarks: justifiedMarks,
        );
        return _scaffold(_content(vm));
      },
    );
  }

  Widget _content(CourseStatsVm vm) {
    final visible = _visible(vm);
    final shown = _expanded ? visible : visible.take(_pageSize).toList();
    final hasData = vm.marks > 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        _HeaderCard(vm: vm),
        const SizedBox(height: 14),
        _StatsGrid(vm: vm),
        const SizedBox(height: 14),
        if (!hasData)
          _EmptyCard(
            noStudents: vm.students.isEmpty,
            onStudents: () => context.push('/teacher/course/${vm.id}/students'),
            onSession: () => context.push('/teacher/course/${vm.id}/session'),
          )
        else ...[
          _DistributionCard(vm: vm),
          const SizedBox(height: 14),
          _TrendCard(vm: vm),
          const SizedBox(height: 14),
          _LimitCard(maxAbsences: vm.maxAbsences),
          const SizedBox(height: 22),
          _monitoring(vm, visible, shown),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _export(vm),
            icon: const Icon(Icons.download_outlined, size: 20),
            label: const Text('Exportar Informe de Inasistencias'),
            style: FilledButton.styleFrom(
              backgroundColor: _navyBtn,
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: vm.criticalCount == 0 ? null : () => _massAlert(vm),
            icon: const Icon(Icons.campaign_outlined, size: 20),
            label: Text(
              'Enviar Alerta Masiva a Estudiantes en Riesgo (${vm.criticalCount})',
              textAlign: TextAlign.center,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _blueBg,
              foregroundColor: AppColors.navy,
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: _blueBg,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppColors.navy),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  vm.isSample
                      ? 'Datos de ejemplo: en tus cursos se calcularán con las sesiones que tomes.'
                      : 'Calculado con las sesiones que has iniciado y los registros confirmados. Los registros en revisión cuentan cuando los apruebes.',
                  style: const TextStyle(
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
    );
  }

  Widget _monitoring(
    CourseStatsVm vm,
    List<StatsStudent> visible,
    List<StatsStudent> shown,
  ) {
    Widget chip(
      String label,
      bool selected,
      VoidCallback onTap, {
      IconData? icon,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? _navyBtn : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? _navyBtn : const Color(0xFFE1E8F4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.navy,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.navy,
                ),
              ),
            ],
          ),
        ),
      );
    }

    void setFilter(int f) => setState(() {
      _filter = f;
      _expanded = false;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monitoreo de Estudiantes',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Priorizados por riesgo de inasistencia',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: const BoxDecoration(
                color: _blueBg,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Text(
                '${shown.length} de ${visible.length} listados',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              chip(
                _desc ? 'Mayor a menor %' : 'Menor a mayor %',
                _filter == 0,
                () => setState(() {
                  if (_filter == 0) {
                    _desc = !_desc;
                  } else {
                    _filter = 0;
                  }
                  _expanded = false;
                }),
                icon: _desc ? Icons.arrow_downward : Icons.arrow_upward,
              ),
              const SizedBox(width: 8),
              chip(
                'Críticos (${vm.criticalCount})',
                _filter == 1,
                () => setFilter(1),
              ),
              const SizedBox(width: 8),
              chip(
                'Atención (${vm.attentionCount})',
                _filter == 2,
                () => setFilter(2),
              ),
              const SizedBox(width: 8),
              chip(
                'En regla (${vm.inOrderCount})',
                _filter == 3,
                () => setFilter(3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                'No hay estudiantes en esta categoría.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ),
        for (final s in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  context.push('/teacher/course/${vm.id}/student/${s.id}'),
              child: _StudentCard(
                student: s,
                onCite: () => _cite(s, vm),
                onAlert: () => _alert(s, vm),
              ),
            ),
          ),
        if (visible.length > _pageSize)
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: AppColors.navy,
              ),
              label: Text(
                _expanded
                    ? 'Mostrar menos'
                    : 'Ver todos los estudiantes (${visible.length})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Barra superior y encabezado
// ---------------------------------------------------------------------------
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.initials});

  final VoidCallback onBack;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 8),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onBack,
                icon: const Icon(
                  Icons.arrow_back,
                  size: 20,
                  color: AppColors.navy,
                ),
                label: const Text(
                  'Volver',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ),
          ),
          const Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Estadísticas de Asistencia',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
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
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.vm});

  final CourseStatsVm vm;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (vm.code.isNotEmpty) vm.code,
      if (vm.section != null) 'Sec. ${vm.section}',
      if (vm.faculty.isNotEmpty) vm.faculty,
    ].join(' • ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: const BoxDecoration(
                  color: _blueBg,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.school_outlined,
                      size: 15,
                      color: AppColors.navy,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ciclo ${vm.cycle}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: const BoxDecoration(
                  color: _mint,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(radius: 4, backgroundColor: _teal),
                    const SizedBox(width: 7),
                    Text(
                      vm.weekActive
                          ? 'Semana ${vm.week} Activa'
                          : 'Semana ${vm.week}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _teal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            vm.name,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
              height: 1.15,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjetas de resumen
// ---------------------------------------------------------------------------
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.vm});

  final CourseStatsVm vm;

  @override
  Widget build(BuildContext context) {
    final rate = vm.rate;
    final delta = vm.facultyDelta;
    final critical = vm.criticalCount;
    final n = vm.students.length;
    final progressPct = (vm.progress * 100).round();

    final rateCard = _StatCard(
      title: 'Tasa General',
      icon: Icons.check_circle_outline,
      iconBg: _mint,
      iconColor: _teal,
      value: rate == null ? '—' : '${rate.toStringAsFixed(1)}%',
      valueColor: AppColors.navy,
      progress: rate == null ? 0 : (rate / 100).clamp(0.0, 1.0).toDouble(),
      progressColor: _teal,
      sub: delta == null
          ? const Text(
              'Sin comparativo de facultad',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            )
          : Row(
              children: [
                const Icon(Icons.trending_up, size: 15, color: _teal),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}% vs facultad',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _teal,
                    ),
                  ),
                ),
              ],
            ),
    );

    final heldCard = _StatCard(
      title: 'Clases Dictadas',
      icon: Icons.calendar_month_outlined,
      iconBg: _blueBg,
      iconColor: AppColors.navy,
      value: '${vm.held}',
      suffix: '/ ${vm.total}',
      valueColor: AppColors.navy,
      progress: vm.progress,
      progressColor: const Color(0xFF0E4A78),
      sub: Text(
        '$progressPct% avance de semestre',
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
    );

    final riskCard = _StatCard(
      title: 'Riesgo Crítico',
      danger: true,
      icon: Icons.warning_amber_rounded,
      iconBg: _redBg,
      iconColor: _red,
      value: '$critical',
      suffix: critical == 1 ? 'alumno' : 'alumnos',
      valueColor: critical > 0 ? _red : AppColors.navy,
      sub: Text(
        'En o sobre el límite de faltas',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: critical > 0 ? _red : AppColors.textMuted,
        ),
      ),
    );

    final enrolledCard = _StatCard(
      title: 'Matriculados',
      icon: Icons.groups_outlined,
      iconBg: _blueBg,
      iconColor: AppColors.navy,
      value: '$n',
      suffix: n == 1 ? 'estudiante' : 'estudiantes',
      valueColor: AppColors.navy,
      sub: n == 0
          ? const Text(
              'Aún sin matricular',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            )
          : Row(
              children: [
                const CircleAvatar(radius: 4, backgroundColor: _teal),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${n - critical} en regla normal',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
    );

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: rateCard),
              const SizedBox(width: 12),
              Expanded(child: heldCard),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: riskCard),
              const SizedBox(width: 12),
              Expanded(child: enrolledCard),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.valueColor,
    required this.sub,
    this.suffix,
    this.danger = false,
    this.progress,
    this.progressColor = _teal,
  });

  final String title;
  final bool danger;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String? suffix;
  final Color valueColor;
  final Widget sub;
  final double? progress;
  final Color progressColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco.copyWith(
        borderRadius: const BorderRadius.all(Radius.circular(22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: danger ? _red : AppColors.textMuted,
                  ),
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                  height: 1.1,
                ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    suffix!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (progress != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: progressColor,
                backgroundColor: const Color(0xFFD5E0F2),
              ),
            ),
            const SizedBox(height: 8),
          ],
          sub,
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.noStudents,
    required this.onStudents,
    required this.onSession,
  });

  final bool noStudents;
  final VoidCallback onStudents;
  final VoidCallback onSession;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDeco,
      child: Column(
        children: [
          const Icon(
            Icons.insights_outlined,
            size: 46,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          const Text(
            'Todavía no hay datos de asistencia',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            noStudents
                ? 'Matricula estudiantes e inicia una sesión de asistencia. Cuando confirmes registros, aquí verás la distribución de faltas, la tendencia semanal y los alumnos en riesgo.'
                : 'Inicia una sesión de asistencia y confirma los registros. Aquí verás la distribución de faltas, la tendencia semanal y los alumnos en riesgo.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          if (noStudents)
            FilledButton.icon(
              onPressed: onStudents,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Añadir estudiantes'),
              style: FilledButton.styleFrom(
                backgroundColor: _navyBtn,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          if (noStudents) const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onSession,
            icon: const Icon(Icons.sensors),
            label: const Text('Activar Toma de Asistencia'),
            style: FilledButton.styleFrom(
              backgroundColor: noStudents ? _blueBg : _navyBtn,
              foregroundColor: noStudents ? AppColors.navy : Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Distribución de faltas (dona)
// ---------------------------------------------------------------------------
class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.vm});

  final CourseStatsVm vm;

  @override
  Widget build(BuildContext context) {
    final marks = vm.marks;
    final aPct = _round1(vm.attendedMarks * 100 / marks);
    final jPct = _round1(vm.justified * 100 / marks);
    final uPct = math.max(0.0, _round1(100 - aPct - jPct));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Distribución de Faltas',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Acumulado de $marks registros totales',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.pie_chart_outline,
                size: 26,
                color: AppColors.navy,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(200, 200),
                    painter: _DonutPainter(
                      values: [
                        vm.attendedMarks.toDouble(),
                        vm.justified.toDouble(),
                        vm.unjustified.toDouble(),
                      ],
                      colors: const [_teal, _amber, _red],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'EFECTIVA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        '${aPct.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        '${vm.attendedMarks} marcas',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _LegendCard(
                  label: 'Asistencia',
                  dot: _teal,
                  bg: const Color(0xFFEAF2FC),
                  percent: '${aPct.toStringAsFixed(1)}%',
                  percentColor: _teal,
                  detail: '${vm.attendedMarks} asist.',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LegendCard(
                  label: 'Justificada',
                  dot: _amber,
                  bg: const Color(0xFFFFF3DA),
                  percent: '${jPct.toStringAsFixed(1)}%',
                  percentColor: _amberFg,
                  detail: '${vm.justified} faltas',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LegendCard(
                  label: 'Injustificada',
                  dot: _red,
                  bg: _redBg,
                  percent: '${uPct.toStringAsFixed(1)}%',
                  percentColor: _red,
                  detail: '${vm.unjustified} faltas',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendCard extends StatelessWidget {
  const _LegendCard({
    required this.label,
    required this.dot,
    required this.bg,
    required this.percent,
    required this.percentColor,
    required this.detail,
  });

  final String label;
  final Color dot;
  final Color bg;
  final String percent;
  final Color percentColor;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 4.5, backgroundColor: dot),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            percent,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: percentColor,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.values, required this.colors});

  final List<double> values;
  final List<Color> colors;

  static const _stroke = 24.0;
  static const _gap = 0.05; // radianes entre segmentos

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);

    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = const Color(0xFFE1E8F4),
    );

    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;

    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final sweep = values[i] / total * 2 * math.pi;
      final visible = math.max(0.03, sweep - _gap);
      canvas.drawArc(
        rect,
        start + _gap / 2,
        visible,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..color = colors[i],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.values != values || old.colors != colors;
}

// ---------------------------------------------------------------------------
// Tendencia semanal
// ---------------------------------------------------------------------------
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.vm});

  final CourseStatsVm vm;

  @override
  Widget build(BuildContext context) {
    final values = vm.weekly;
    final present = values.whereType<double>().toList();
    final avg = present.isEmpty
        ? null
        : (present.reduce((a, b) => a + b) / present.length).round();
    final first = vm.weeklyStart;
    final currentIndex = vm.week - first;
    final last = first + values.length - 1;

    double height(double v) =>
        (((v - 50) / 50).clamp(0.08, 1.0)).toDouble() * 100;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  values.isEmpty
                      ? 'Tendencia Semanal'
                      : 'Tendencia Semanal (Sem $first a Sem $last)',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
              if (avg != null)
                Text(
                  'Promedio: $avg%',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (present.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Aún no hay datos semanales.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
              decoration: const BoxDecoration(
                color: Color(0xFFEAF2FC),
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 110,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < values.length; i++)
                          Expanded(
                            child: values[i] == null
                                ? const SizedBox.shrink()
                                : Center(
                                    child: Container(
                                      width: 20,
                                      height: height(values[i]!),
                                      decoration: BoxDecoration(
                                        color: i == currentIndex
                                            ? _teal
                                            : (values[i]! < 85
                                                  ? _amber
                                                  : _barBlue),
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(6),
                                            ),
                                      ),
                                    ),
                                  ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var i = 0; i < values.length; i++)
                        Expanded(
                          child: Text(
                            'S${first + i}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: i == currentIndex
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: i == currentIndex
                                  ? _teal
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Límite de inasistencias
// ---------------------------------------------------------------------------
class _LimitCard extends StatelessWidget {
  const _LimitCard({required this.maxAbsences});

  final int maxAbsences;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _redBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _redBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _redDark,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.rule, size: 25, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Límite del 20% de Inasistencias',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _redDark,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Estudiantes que excedan este umbral pierden el derecho a la evaluación final según el reglamento académico de la institución.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xFF7A2A2A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _redDark,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Máx. $maxAbsences\nFaltas',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta de estudiante
// ---------------------------------------------------------------------------
({
  Color accent,
  Color avatarBg,
  Color avatarFg,
  Color badgeBg,
  Color badgeFg,
  Color count,
  Color label,
})
_riskStyle(StatsRisk r) {
  switch (r) {
    case StatsRisk.exceeded:
      return (
        accent: _red,
        avatarBg: const Color(0xFFFCE0E0),
        avatarFg: _red,
        badgeBg: _redDark,
        badgeFg: Colors.white,
        count: _red,
        label: _red,
      );
    case StatsRisk.limit:
      return (
        accent: _red,
        avatarBg: const Color(0xFFFCE0E0),
        avatarFg: _red,
        badgeBg: _red,
        badgeFg: Colors.white,
        count: _red,
        label: _red,
      );
    case StatsRisk.watch:
      return (
        accent: _amber,
        avatarBg: _amberBg,
        avatarFg: _amberFg,
        badgeBg: _brown,
        badgeFg: Colors.white,
        count: _amberFg,
        label: _amberFg,
      );
    case StatsRisk.early:
      return (
        accent: _amber,
        avatarBg: _blueBg,
        avatarFg: AppColors.navy,
        badgeBg: const Color(0xFFFFE0B8),
        badgeFg: _amberFg,
        count: _amberFg,
        label: _amberFg,
      );
    case StatsRisk.regular:
      return (
        accent: _barBlue,
        avatarBg: _mint,
        avatarFg: const Color(0xFF065F52),
        badgeBg: _blueBg,
        badgeFg: AppColors.navy,
        count: AppColors.textMuted,
        label: AppColors.textMuted,
      );
    case StatsRisk.optimal:
      return (
        accent: _teal,
        avatarBg: _mint,
        avatarFg: const Color(0xFF065F52),
        badgeBg: _mintStrong,
        badgeFg: const Color(0xFF065F52),
        count: AppColors.textMuted,
        label: _teal,
      );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.student,
    required this.onCite,
    required this.onAlert,
  });

  final StatsStudent student;
  final VoidCallback onCite;
  final VoidCallback onAlert;

  @override
  Widget build(BuildContext context) {
    final s = student;
    final r = s.risk;
    final st = _riskStyle(r);
    final pct = s.faultPercent.toStringAsFixed(1);
    final filled =
        r == StatsRisk.exceeded || r == StatsRisk.limit || r == StatsRisk.watch;

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Color(0x120B3A5E),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: st.avatarBg,
                        child: Text(
                          s.initials,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: st.avatarFg,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text.rich(
                              TextSpan(
                                children: [
                                  if (s.code.isNotEmpty)
                                    TextSpan(
                                      text: 'Mat. ${s.code}  •  ',
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  TextSpan(
                                    text: '${s.absences} de ${s.held} clases',
                                    style: TextStyle(
                                      color: st.count,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: st.badgeBg,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              filled ? '$pct% FALTAS' : '$pct% Faltas',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: st.badgeFg,
                              ),
                            ),
                          ),
                          if (!filled) ...[
                            const SizedBox(height: 4),
                            Text(
                              riskLabel(r),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: st.label,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  ..._strip(),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: ColoredBox(color: st.accent),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _strip() {
    final s = student;

    switch (s.risk) {
      case StatsRisk.exceeded:
        return [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              color: _redBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _redBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.error, size: 18, color: _red),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'LÍMITE EXCEDIDO • Riesgo pérdida',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _red,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onCite,
                  icon: const Icon(Icons.mail_outline, size: 16),
                  label: const Text('Citar alumno'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _redDark,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];
      case StatsRisk.limit:
        return [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              color: _redBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _redBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 19, color: _red),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Al límite crítico (1 falta más = pierde)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _red,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: _blueBg,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onAlert,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      child: Text(
                        'Alerta',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];
      case StatsRisk.watch:
        final pending = s.pendingJustifications;
        return [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.pending_actions,
                  size: 19,
                  color: AppColors.navy,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pending > 0
                        ? 'En observación: $pending ${pending == 1 ? 'justificante pendiente' : 'justificantes pendientes'} de revisión'
                        : 'En observación: a 1 falta del límite',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];
      default:
        return const [];
    }
  }
}
