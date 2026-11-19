import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/course_repository.dart';
import '../data/course_stats_data.dart';
import '../data/enrollment_repository.dart';
import '../data/student_detail_data.dart';
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
const _amberSoft = Color(0xFFFFF3DA);

const _shadow = [
  BoxShadow(color: Color(0x120B3A5E), blurRadius: 16, offset: Offset(0, 6)),
];

const _days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _months = [
  'Ene',
  'Feb',
  'Mar',
  'Abr',
  'May',
  'Jun',
  'Jul',
  'Ago',
  'Sep',
  'Oct',
  'Nov',
  'Dic',
];

String _two(int n) => n.toString().padLeft(2, '0');

String _dateLabel(DateTime d) =>
    '${_days[d.weekday - 1]} ${_two(d.day)} ${_months[d.month - 1]} ${d.year}';

String _hm12(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${_two(h)}:${_two(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
}

String _statusText(ClassStatus s) => switch (s) {
  ClassStatus.present => 'Presente',
  ClassStatus.justified => 'Falta justificada',
  ClassStatus.absent => 'Falta injustificada',
  ClassStatus.review => 'En revisión',
  ClassStatus.pending => 'Por validar',
  ClassStatus.rejected => 'No validada',
};

String _methodText(ClassRecord r) {
  final base = r.method == ClassMethod.manual
      ? 'Validado con código manual'
      : 'Validado vía QR dinámico';
  return r.offline ? '$base (sin conexión)' : base;
}

// ---------------------------------------------------------------------------
// Colores según el riesgo del estudiante
// ---------------------------------------------------------------------------
({
  Color accent,
  Color bg,
  Color border,
  Color fg,
  IconData icon,
  String title,
  bool strong,
})
_tone(StatsRisk r) {
  switch (r) {
    case StatsRisk.exceeded:
      return (
        accent: _red,
        bg: _redBg,
        border: _redBorder,
        fg: _red,
        icon: Icons.warning_amber_rounded,
        title: 'Riesgo Crítico por Inasistencia',
        strong: true,
      );
    case StatsRisk.limit:
      return (
        accent: _red,
        bg: _redBg,
        border: _redBorder,
        fg: _red,
        icon: Icons.warning_amber_rounded,
        title: 'Al límite de inasistencias',
        strong: true,
      );
    case StatsRisk.watch:
      return (
        accent: _amber,
        bg: _amberSoft,
        border: const Color(0xFFF3D9A8),
        fg: _amberFg,
        icon: Icons.visibility_outlined,
        title: 'En observación por inasistencias',
        strong: false,
      );
    case StatsRisk.early:
      return (
        accent: _amber,
        bg: _amberSoft,
        border: const Color(0xFFF3D9A8),
        fg: _amberFg,
        icon: Icons.notification_important_outlined,
        title: 'Alerta temprana de inasistencias',
        strong: false,
      );
    case StatsRisk.regular:
      return (
        accent: const Color(0xFF1F5A8C),
        bg: const Color(0xFFEAF2FC),
        border: const Color(0xFFD3E2F7),
        fg: AppColors.navy,
        icon: Icons.info_outline,
        title: 'Seguimiento regular',
        strong: false,
      );
    case StatsRisk.optimal:
      return (
        accent: _teal,
        bg: _mint,
        border: _mintStrong,
        fg: _teal,
        icon: Icons.check_circle_outline,
        title: 'Asistencia en orden',
        strong: false,
      );
  }
}

class StudentAttendanceDetailScreen extends ConsumerStatefulWidget {
  const StudentAttendanceDetailScreen({
    super.key,
    required this.courseId,
    required this.studentId,
  });

  final String courseId;
  final String studentId;

  @override
  ConsumerState<StudentAttendanceDetailScreen> createState() =>
      _StudentAttendanceDetailScreenState();
}

class _StudentAttendanceDetailScreenState
    extends ConsumerState<StudentAttendanceDetailScreen> {
  int _filter = 0; // 0 todas, 1 presentes, 2 faltas, 3 justificadas

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _soon(String text) => _snack('$text (próximamente)');

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/teacher/course/${widget.courseId}');
    }
  }

  List<ClassRecord> _visible(StudentDetailVm vm) {
    return vm.records
        .where(
          (r) => switch (_filter) {
            1 => r.status == ClassStatus.present,
            2 =>
              r.status != ClassStatus.present &&
                  r.status != ClassStatus.justified,
            3 => r.status == ClassStatus.justified,
            _ => true,
          },
        )
        .toList();
  }

  // ------------------------------ Mensajes ------------------------------

  void _showCopyDialog({
    required String title,
    required String message,
    String? note,
    String copyLabel = 'Copiar mensaje',
    String copiedText = 'Mensaje copiado',
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
                child: Text(
                  message,
                  style: const TextStyle(height: 1.4, fontSize: 13.5),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                note ?? 'El envío automático llegará con las notificaciones. Mientras tanto, copia el mensaje y envíalo por tu medio habitual.',
                style: const TextStyle(
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
              if (mounted) _snack(copiedText);
            },
            child: Text(copyLabel),
          ),
        ],
      ),
    );
  }

  String _situation(StudentDetailVm vm) => switch (vm.risk) {
    StatsRisk.exceeded =>
      'superó el máximo de ${vm.maxAbsences} inasistencias permitido',
    StatsRisk.limit =>
      'alcanzó el máximo de ${vm.maxAbsences} inasistencias permitido',
    StatsRisk.watch || StatsRisk.early =>
      'está cerca del máximo de ${vm.maxAbsences} inasistencias permitido',
    _ =>
      'se mantiene dentro del máximo de ${vm.maxAbsences} inasistencias permitido',
  };

  void _alert(StudentDetailVm vm) {
    final extra = vm.isCritical
        ? 'Una falta más puede afectar tu derecho a presentar la evaluación final. '
        : '';
    _showCopyDialog(
      title: 'Alerta para ${vm.firstName}',
      message:
          'Hola ${vm.firstName}, en ${vm.courseName} llevas ${vm.absences} inasistencias de ${vm.held} clases dictadas y el máximo permitido es ${vm.maxAbsences}. '
          '$extra'
          'Habla con tu docente y, si tienes soportes de justificación, radícalos cuanto antes.',
    );
  }

  void _tutoring(StudentDetailVm vm) {
    _showCopyDialog(
      title: 'Citar a tutoría',
      message:
          'Hola ${vm.firstName}, te invito a una tutoría para revisar tu asistencia en ${vm.courseName}. '
          'Llevas ${vm.absences} inasistencias (${vm.justified} justificadas) de ${vm.held} clases dictadas, y el máximo permitido es ${vm.maxAbsences}. '
          'Indícame qué horario te conviene para reunirnos.',
    );
  }

  void _formal(StudentDetailVm vm) {
    final course = vm.courseCode.isEmpty
        ? vm.courseName
        : '${vm.courseName} (${vm.courseCode})';
    _showCopyDialog(
      title: 'Notificación formal de riesgo',
      message:
          'NOTIFICACIÓN FORMAL DE RIESGO ACADÉMICO\n\n'
          'Curso: $course • Ciclo ${vm.cycle}\n'
          'Estudiante: ${vm.studentName} • Matrícula ${vm.studentCode}\n\n'
          'Clases dictadas: ${vm.held}\n'
          'Asistencias: ${vm.present} (${vm.attendancePercent.toStringAsFixed(1)}%)\n'
          'Inasistencias: ${vm.absences} (${vm.faultPercent.toStringAsFixed(1)}%): ${vm.justified} justificadas y ${vm.unjustified} injustificadas\n'
          'Máximo permitido: ${vm.maxAbsences} inasistencias (20% de las clases del curso)\n\n'
          'Situación: el estudiante ${_situation(vm)}. '
          'Se le solicita acercarse al docente para revisar su caso y presentar, si los tiene, los soportes de justificación.',
      copiedText: 'Notificación copiada',
      copyLabel: 'Copiar notificación',
    );
  }

  String _summary(StudentDetailVm vm) {
    final b = StringBuffer()
      ..writeln('CONSTANCIA DE ASISTENCIA')
      ..writeln(
        'Curso: ${vm.courseName}${vm.courseCode.isEmpty ? '' : ' (${vm.courseCode})'} • Ciclo ${vm.cycle}',
      )
      ..writeln('Estudiante: ${vm.studentName} • Matrícula ${vm.studentCode}')
      ..writeln('Clases dictadas: ${vm.held}')
      ..writeln(
        'Asistencias: ${vm.present} (${vm.attendancePercent.toStringAsFixed(1)}%)',
      )
      ..writeln(
        'Inasistencias: ${vm.absences} (${vm.justified} justificadas, ${vm.unjustified} injustificadas)',
      )
      ..writeln('Máximo permitido: ${vm.maxAbsences}')
      ..writeln()
      ..writeln('Detalle por clase:');
    for (final r in vm.records.reversed) {
      b.writeln(
        '#${r.number}\t${_dateLabel(r.date)}\t${r.title}\t${_statusText(r.status)}',
      );
    }
    b
      ..writeln()
      ..writeln(
        'Resumen informativo generado por AsistApp. No es un certificado oficial.',
      );
    return b.toString();
  }

  void _certificate(StudentDetailVm vm) {
    _showCopyDialog(
      title: 'Certificado individual',
      message: _summary(vm),
      note: 'La descarga en PDF llegará más adelante. Mientras tanto puedes copiar este resumen. No es un certificado oficial.',
      copyLabel: 'Copiar resumen',
      copiedText: 'Resumen copiado',
    );
  }

  // ------------------------------ Detalles ------------------------------

  void _showDetail(ClassRecord r) {
    final rows = <(String, String)>[
      ('Clase', '#${r.number} • ${r.title}'),
      ('Fecha', _dateLabel(r.date)),
      ('Horario', r.room.isEmpty ? r.timeLabel : '${r.timeLabel} • ${r.room}'),
      ('Estado', _statusText(r.status)),
      if (r.markedAt != null)
        (
          'Registro',
          '${r.method == ClassMethod.manual ? 'Código manual' : 'QR dinámico'}${r.offline ? ' (sin conexión)' : ''} • ${_hm12(r.markedAt!)}',
        ),
      if (r.note != null && r.note!.isNotEmpty) ('Observación', r.note!),
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Detalle del registro',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.$1,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        row.$2,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
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
        ],
      ),
    );
  }

  void _showProof(ClassRecord r) {
    final j = r.justification;
    if (j == null) return;

    final rows = <(String, String)>[
      ('Constancia', '#${j.code}'),
      ('Clase justificada', '#${r.number} • ${r.title}'),
      ('Fecha', _dateLabel(r.date)),
      ('Aprobado por', j.approvedBy),
      ('Motivo', j.reason),
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Falta justificada',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.$1,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        row.$2,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                          height: 1.3,
                        ),
                      ),
                    ],
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
        ],
      ),
    );
  }

  // ------------------------------ Interfaz ------------------------------

  Widget _scaffold(Widget body) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _back,
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.navy,
                        ),
                      ),
                      const Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Detalle de Asistencia Estudiantil',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Historial de cambios',
                        onPressed: () => _soon('Historial de cambios'),
                        icon: const Icon(Icons.history, color: AppColors.navy),
                      ),
                    ],
                  ),
                ),
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
    final enrolledAsync = ref.watch(enrolledStudentsProvider(widget.courseId));
    final student = enrolledAsync.value
        ?.where((e) => e.id == widget.studentId)
        .firstOrNull;

    if (course == null || student == null) {
      final loading = coursesAsync.isLoading || enrolledAsync.isLoading;
      return _scaffold(
        Center(
          child: loading
              ? const CircularProgressIndicator()
              : const Text('Estudiante no encontrado'),
        ),
      );
    }

    final justs =
        ref.watch(teacherJustificationsProvider).value ??
        const <JustificationInfo>[];
    final justMap = {
      for (final j in justs)
        if (j.courseId == widget.courseId && j.studentId == widget.studentId)
          j.sessionId: j,
    };

    final key = (courseId: widget.courseId, studentId: widget.studentId);
    return ref
        .watch(studentRecordsProvider(key))
        .when(
          loading: () =>
              _scaffold(const Center(child: CircularProgressIndicator())),
          error: (_, __) => _scaffold(
            Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No se pudo cargar el historial. Revisa tu conexión.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _red, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.invalidate(studentRecordsProvider(key)),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          data: (list) => _scaffold(
            _content(
              buildRealStudentDetail(
                course: course,
                student: student,
                sessions: list,
                justifications: justMap,
              ),
            ),
          ),
        );
  }

  Widget _content(StudentDetailVm vm) {
    final visible = _visible(vm);
    final presentCount = vm.present;
    final absentCount = vm.unjustified;
    final justifiedCount = vm.justified;
    final now = DateTime.now();

    final chip = vm.courseCode.isEmpty
        ? null
        : (vm.section == null
              ? vm.courseCode
              : '${vm.courseCode} • SEC. ${vm.section}');

    Widget filterChip(int i, String label, int count, {Color? dot}) {
      final selected = _filter == i;
      return GestureDetector(
        onTap: () => setState(() => _filter = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
              if (dot != null && !selected) ...[
                CircleAvatar(radius: 4, backgroundColor: dot),
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
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.18)
                      : _blueBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        Row(
          children: [
            if (chip != null)
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
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
                      Flexible(
                        child: Text(
                          chip,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => _alert(vm),
              icon: const Icon(Icons.chat_bubble_outline, size: 17),
              label: const Text('Alertar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.navy,
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFD3DDF0)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFD3DDF0)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _soon('Descarga del informe del estudiante'),
                child: const SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons.download_outlined,
                    size: 20,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _StudentCard(vm: vm),
        const SizedBox(height: 14),
        _BalanceCard(vm: vm),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.note_add_outlined,
                label: 'Justificar Falta',
                onTap: () => _soon('Justificación de faltas'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionTile(
                icon: Icons.mail_outline,
                label: 'Citar a Tutoría',
                onTap: () => _tutoring(vm),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Historial de Clases',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ),
            Text(
              '${vm.held} ${vm.held == 1 ? 'registro' : 'registros'}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              filterChip(0, 'Todas', vm.held),
              const SizedBox(width: 8),
              filterChip(1, 'Presentes', presentCount, dot: _teal),
              const SizedBox(width: 8),
              filterChip(2, 'Faltas', absentCount, dot: _red),
              const SizedBox(width: 8),
              filterChip(3, 'Justificadas', justifiedCount, dot: _amber),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30, horizontal: 12),
            child: Center(
              child: Text(
                'No hay clases en esta categoría.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
            ),
          ),
        for (final r in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ClassCard(
              record: r,
              onMenu: (action) {
                if (action == 'detail') {
                  _showDetail(r);
                } else {
                  _soon('Justificación de faltas');
                }
              },
              onProof: () => _showProof(r),
            ),
          ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () => _formal(vm),
          icon: const Icon(Icons.gavel_outlined, size: 20),
          label: const Text('Emitir Notificación Formal de Riesgo'),
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
          onPressed: () => _certificate(vm),
          icon: const Icon(Icons.description_outlined, size: 20),
          label: const Text('Generar Certificado Individual (PDF)'),
          style: FilledButton.styleFrom(
            backgroundColor: _blueBg,
            foregroundColor: AppColors.navy,
            minimumSize: const Size.fromHeight(54),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sync, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                vm.isSample
                    ? 'Datos de ejemplo • actualizado hoy ${_hm12(now)}'
                    : 'Calculado con las sesiones del curso • actualizado hoy ${_hm12(now)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta del estudiante
// ---------------------------------------------------------------------------
class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.vm});

  final StudentDetailVm vm;

  @override
  Widget build(BuildContext context) {
    final t = _tone(vm.risk);
    final subtitle = vm.held == 0
        ? 'Aún sin sesiones registradas'
        : '${vm.faultPercent.toStringAsFixed(1)}% de inasistencias acumuladas';

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(24)),
        boxShadow: _shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: t.strong
                                ? const Color(0xFFFCE0E0)
                                : _blueBg,
                            child: Text(
                              vm.initials,
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: t.strong ? _red : AppColors.navy,
                              ),
                            ),
                          ),
                          if (t.strong)
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: _red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vm.studentName,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'Matrícula: ',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  TextSpan(
                                    text: vm.studentCode.isEmpty
                                        ? '—'
                                        : vm.studentCode,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                ],
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                            if (vm.program != null)
                              Text(
                                vm.program!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            if (vm.email != null)
                              Text(
                                vm.email!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.menu_book_outlined,
                                  size: 16,
                                  color: AppColors.navy,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${vm.courseName} (${vm.cycle})',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.navy,
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
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                    decoration: BoxDecoration(
                      color: t.bg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: t.border),
                    ),
                    child: Row(
                      children: [
                        Icon(t.icon, size: 22, color: t.fg),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.title,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: t.fg,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(fontSize: 12.5, color: t.fg),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: t.strong ? _redDark : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: t.strong
                                ? null
                                : Border.all(color: t.border),
                          ),
                          child: Text(
                            'Máx. ${vm.maxAbsences} faltas',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: t.strong ? Colors.white : t.fg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: ColoredBox(color: t.accent),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Balance del semestre
// ---------------------------------------------------------------------------
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.vm});

  final StudentDetailVm vm;

  @override
  Widget build(BuildContext context) {
    final t = _tone(vm.risk);
    final exceeded = vm.absences > vm.maxAbsences;
    final atLimit =
        !exceeded && vm.absences > 0 && vm.absences == vm.maxAbsences;
    final critical = exceeded || atLimit;

    final String caption;
    if (exceeded) {
      caption = 'Límite reglamentario excedido';
    } else if (atLimit) {
      caption = 'Límite reglamentario alcanzado';
    } else {
      final r = vm.remaining;
      caption =
          'Dentro del límite ($r ${r == 1 ? 'falta restante' : 'faltas restantes'})';
    }

    // Barra: cuánto del límite de faltas se ha consumido.
    final cap = vm.maxAbsences < 1 ? 1 : vm.maxAbsences;
    final used = vm.absences;
    int redFlex;
    int amberFlex;
    int mintFlex;
    if (used >= cap) {
      redFlex = (vm.unjustified * 1000 / used).round();
      amberFlex = 1000 - redFlex;
      mintFlex = 0;
    } else {
      redFlex = (vm.unjustified * 1000 / cap).round();
      amberFlex = (vm.justified * 1000 / cap).round();
      mintFlex = 1000 - redFlex - amberFlex;
      if (mintFlex < 0) mintFlex = 0;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(24)),
        boxShadow: _shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, size: 26, color: AppColors.navy),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Balance del Semestre',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                    height: 1.15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: const BoxDecoration(
                  color: _blueBg,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Text(
                  '${vm.held} Sesiones dictadas',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _BalanceTile(
                    title: 'Asistencias',
                    icon: Icons.check_circle_outline,
                    iconColor: _teal,
                    bg: const Color(0xFFEAF2FC),
                    border: const Color(0xFFD3E2F7),
                    percent: '${vm.attendancePercent.toStringAsFixed(1)}%',
                    percentColor: AppColors.navy,
                    suffix: '(${vm.present})',
                    caption: 'Clases presenciales válidas',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BalanceTile(
                    title: 'Total Faltas',
                    icon: Icons.cancel_outlined,
                    iconColor: critical ? _red : t.fg,
                    bg: critical ? _redBg : t.bg,
                    border: critical ? _redBorder : t.border,
                    percent: '${vm.faultPercent.toStringAsFixed(1)}%',
                    percentColor: critical ? _red : AppColors.navy,
                    suffix: '(${vm.absences}/${vm.maxAbsences} máx)',
                    caption: caption,
                    captionColor: critical ? _red : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: critical ? _red : _teal,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Faltas computadas vs. Límite máximo',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
              Text(
                '${vm.absences} / ${vm.maxAbsences} Faltas',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: critical ? _red : AppColors.navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 11,
              child: Row(
                children: [
                  if (redFlex > 0)
                    Expanded(
                      flex: redFlex,
                      child: const ColoredBox(color: _redDark),
                    ),
                  if (amberFlex > 0)
                    Expanded(
                      flex: amberFlex,
                      child: const ColoredBox(color: _amber),
                    ),
                  if (mintFlex > 0)
                    Expanded(
                      flex: mintFlex,
                      child: const ColoredBox(color: _mintStrong),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Límite de inhabilitación: 20% de las clases (máx. ${vm.maxAbsences} faltas)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                exceeded
                    ? 'EXCEDIDO'
                    : (atLimit ? 'AL LÍMITE' : 'DENTRO DEL LÍMITE'),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: critical ? _red : _teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _CountTile(
                    value: vm.present,
                    label: 'Efectivas',
                    bg: _mint,
                    fg: _teal,
                    border: _mintStrong,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CountTile(
                    value: vm.unjustified,
                    label: 'Injustificadas',
                    bg: _redBg,
                    fg: _red,
                    border: _redBorder,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CountTile(
                    value: vm.justified,
                    label: 'Justificadas',
                    bg: const Color(0xFFEAF2FC),
                    fg: AppColors.navy,
                    border: const Color(0xFFD3E2F7),
                  ),
                ),
              ],
            ),
          ),
          if (vm.inReview > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _amberSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.rate_review_outlined,
                    size: 18,
                    color: _amberFg,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${vm.inReview} ${vm.inReview == 1 ? 'registro' : 'registros'} en revisión o por validar: no cuentan como asistencia hasta que los apruebes.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: Color(0xFF7A4A12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.bg,
    required this.border,
    required this.percent,
    required this.percentColor,
    required this.suffix,
    required this.caption,
    this.captionColor = AppColors.textMuted,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Color bg;
  final Color border;
  final String percent;
  final Color percentColor;
  final String suffix;
  final String caption;
  final Color captionColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Icon(icon, size: 19, color: iconColor),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 6,
            children: [
              Text(
                percent,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: percentColor,
                  height: 1.1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  suffix,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            style: TextStyle(fontSize: 12.5, height: 1.3, color: captionColor),
          ),
        ],
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.value,
    required this.label,
    required this.bg,
    required this.fg,
    required this.border,
  });

  final int value;
  final String label;
  final Color bg;
  final Color fg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: fg,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 1.5,
      shadowColor: const Color(0x1A0B3A5E),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: AppColors.navy),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta de una clase
// ---------------------------------------------------------------------------
({
  Color accent,
  Color label,
  Color pillBg,
  Color pillFg,
  Color noteColor,
  String pill,
  IconData pillIcon,
})
_classStyle(ClassRecord r) {
  switch (r.status) {
    case ClassStatus.present:
      final icon = r.offline
          ? Icons.cloud_done_outlined
          : (r.method == ClassMethod.manual ? Icons.dialpad : Icons.qr_code_2);
      return (
        accent: _teal,
        label: _teal,
        pillBg: _mintStrong,
        pillFg: const Color(0xFF065F52),
        noteColor: AppColors.textMuted,
        pill: 'Presente',
        pillIcon: icon,
      );
    case ClassStatus.justified:
      return (
        accent: _amber,
        label: _amberFg,
        pillBg: _amberBg,
        pillFg: _amberFg,
        noteColor: AppColors.textMuted,
        pill: 'Falta Justificada',
        pillIcon: Icons.verified_user_outlined,
      );
    case ClassStatus.absent:
      return (
        accent: _red,
        label: _red,
        pillBg: _redBg,
        pillFg: _red,
        noteColor: _red,
        pill: 'Falta Injustificada',
        pillIcon: Icons.cancel_outlined,
      );
    case ClassStatus.review:
      return (
        accent: _amber,
        label: _amberFg,
        pillBg: _amberBg,
        pillFg: _amberFg,
        noteColor: _amberFg,
        pill: 'En revisión',
        pillIcon: Icons.rate_review_outlined,
      );
    case ClassStatus.pending:
      return (
        accent: const Color(0xFF1F5A8C),
        label: AppColors.navy,
        pillBg: _blueBg,
        pillFg: AppColors.navy,
        noteColor: AppColors.textMuted,
        pill: 'Por validar',
        pillIcon: Icons.schedule,
      );
    case ClassStatus.rejected:
      return (
        accent: _red,
        label: _red,
        pillBg: _redBg,
        pillFg: _red,
        noteColor: _red,
        pill: 'No validada',
        pillIcon: Icons.error_outline,
      );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.record,
    required this.onMenu,
    required this.onProof,
  });

  final ClassRecord record;
  final ValueChanged<String> onMenu;
  final VoidCallback onProof;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final st = _classStyle(r);
    final justified = r.status == ClassStatus.justified;

    final String? note;
    if (r.status == ClassStatus.present && r.markedAt != null) {
      note = '${_methodText(r)} • ${_hm12(r.markedAt!)}';
    } else {
      note = r.note;
    }

    final schedule = r.room.isEmpty
        ? r.timeLabel
        : '${r.timeLabel} • ${r.room}';

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(22)),
        boxShadow: _shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'CLASE #${r.number}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: st.label,
                                ),
                              ),
                              TextSpan(
                                text: '  •  ${_dateLabel(r.date)}',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          style: const TextStyle(
                            fontSize: 11.5,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      if (justified)
                        IconButton(
                          tooltip: 'Ver constancia',
                          visualDensity: VisualDensity.compact,
                          onPressed: onProof,
                          icon: const Icon(
                            Icons.visibility_outlined,
                            size: 21,
                            color: AppColors.navy,
                          ),
                        )
                      else
                        PopupMenuButton<String>(
                          tooltip: 'Más opciones',
                          icon: const Icon(
                            Icons.more_vert,
                            size: 21,
                            color: AppColors.navy,
                          ),
                          onSelected: onMenu,
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'detail',
                              child: Text('Ver detalle del registro'),
                            ),
                            if (r.status == ClassStatus.absent ||
                                r.status == ClassStatus.rejected)
                              const PopupMenuItem(
                                value: 'justify',
                                child: Text('Justificar falta'),
                              ),
                          ],
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      r.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.schedule,
                            size: 15,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            schedule,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: st.pillBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(st.pillIcon, size: 15, color: st.pillFg),
                            const SizedBox(width: 6),
                            Text(
                              st.pill,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: st.pillFg,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (justified && r.justification != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.attach_file,
                              size: 16,
                              color: AppColors.navy,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Constancia #${r.justification!.code}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        note,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: st.noteColor,
                          fontWeight: st.noteColor == AppColors.textMuted
                              ? FontWeight.w500
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
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
}
