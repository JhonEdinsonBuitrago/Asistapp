import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/attendance_history_data.dart';
import '../data/student_mock_data.dart';

const _teal = Color(0xFF066A5C);
const _red = Color(0xFFD92D20);
const _redBg = Color(0xFFFCE8E8);
const _redBorder = Color(0xFFF3C6C6);
const _soft = Color(0xFFEFF3FC);
const _chipBlue = Color(0xFFE3EBFA);

const _dayNames = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const _monthNames = [
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

String _dateLine(DateTime d) =>
    '${_dayNames[d.weekday - 1]}, ${_two(d.day)} ${_monthNames[d.month - 1]} ${d.year}';

String _hm(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${_two(h)}:${_two(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
}

const _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(22)),
  boxShadow: [
    BoxShadow(color: Color(0x120B3A5E), blurRadius: 16, offset: Offset(0, 6)),
  ],
);

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key, required this.courseId});

  final String courseId;

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  int _filter = 0; // 0 todas, 1 presentes, 2 faltas, 3 justificadas

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/student/course/${widget.courseId}');
    }
  }

  void _soon(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$text (próximamente)')));
  }

  List<HistoryRecord> _filtered(CourseHistory h) => switch (_filter) {
    1 => h.records.where((r) => r.kind == AttendanceKind.present).toList(),
    2 => h.records.where((r) => r.kind != AttendanceKind.present).toList(),
    3 => h.records.where((r) => r.kind == AttendanceKind.justified).toList(),
    _ => h.records,
  };

  void _showInfo(CourseDetail d) {
    Widget line(Color color, String title, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$title: ',
              style: TextStyle(fontWeight: FontWeight.w800, color: color),
            ),
            TextSpan(text: text),
          ],
        ),
        style: const TextStyle(height: 1.4, color: AppColors.navy),
      ),
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          '¿Cómo leer este historial?',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              line(
                _teal,
                'Presente',
                'tu asistencia fue registrada y validada.',
              ),
              line(
                _red,
                'Falta',
                'no hay registro de asistencia en esa sesión.',
              ),
              line(
                AppColors.navy,
                'Justificada',
                'la falta fue aprobada con un soporte.',
              ),
              Text(
                'Límite: ${d.limitPercent}% de las clases (${d.maxAbsences} faltas). '
                'Plazo para justificar: ${d.justifyHours} horas.',
                style: const TextStyle(height: 1.4, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = historyFor(widget.courseId);
    if (h == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Curso no encontrado')),
      );
    }
    final d = h.detail;
    final list = _filtered(h);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                _TopBar(
                  onBack: _back,
                  onFilters: () => _soon('Filtros avanzados'),
                  onInfo: () => _showInfo(d),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
                    children: [
                      _HeaderCard(detail: d),
                      const SizedBox(height: 14),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _AttendanceStat(detail: d)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _AbsenceStat(
                                detail: d,
                                justified: h.justifiedCount,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _LimitBox(detail: d),
                      const SizedBox(height: 18),
                      _FilterChips(
                        index: _filter,
                        counts: [
                          h.records.length,
                          h.presentCount,
                          h.absentCount,
                          h.justifiedCount,
                        ],
                        onChanged: (i) => setState(() => _filter = i),
                      ),
                      const SizedBox(height: 14),
                      if (list.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              'No hay sesiones en esta categoría.',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ),
                        ),
                      for (final r in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _RecordCard(
                            record: r,
                            onJustify: () => _soon('Justificación de faltas'),
                          ),
                        ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () =>
                            _soon('Descarga del comprobante en PDF'),
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Descargar comprobante en PDF'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0A2F52),
                          minimumSize: const Size.fromHeight(56),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
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

// ---------------------------------------------------------------------------
// Cabecera
// ---------------------------------------------------------------------------
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onBack,
    required this.onFilters,
    required this.onInfo,
  });

  final VoidCallback onBack;
  final VoidCallback onFilters;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: AppColors.navy),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onBack,
                  child: const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'ASISTAPP',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        TextSpan(text: '  •  Volver al curso'),
                      ],
                    ),
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ),
                const Text(
                  'Historial de Asistencia',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Filtros',
            onPressed: onFilters,
            icon: const Icon(Icons.tune, color: AppColors.navy),
          ),
          IconButton(
            tooltip: 'Ayuda',
            onPressed: onInfo,
            icon: const Icon(Icons.info_outline, color: AppColors.navy),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.detail});

  final CourseDetail detail;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final cycle = d.period.replaceFirst('-II', '-2').replaceFirst('-I', '-1');

    return Container(
      decoration: _cardDecoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned(
              right: -36,
              top: -36,
              child: Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(
                  color: _chipBlue,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: const BoxDecoration(
                      color: _chipBlue,
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.school_outlined,
                          size: 14,
                          color: AppColors.navy,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'CICLO $cycle',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.only(right: 56),
                    child: Text(
                      d.name,
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${d.code} • Grupo ${d.group}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                        decoration: const BoxDecoration(
                          color: _soft,
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(
                                color: _chipBlue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_outline,
                                size: 16,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              d.teacherName,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _soft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFDDE6F5)),
                        ),
                        child: Text(
                          d.room,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              right: 16,
              top: 16,
              child: Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: Color(0xFFD3DFF6),
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                ),
                child: const Icon(
                  Icons.laptop_mac,
                  size: 26,
                  color: AppColors.navy,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Estadísticas y límite
// ---------------------------------------------------------------------------
class _AttendanceStat extends StatelessWidget {
  const _AttendanceStat({required this.detail});

  final CourseDetail detail;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Asistencias',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: Color(0xFFD7F5EA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 16, color: _teal),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${d.attended}',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: _teal,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '/ ${d.scheduled} clases',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: d.scheduled == 0 ? 0 : d.attended / d.scheduled,
                    minHeight: 7,
                    color: _teal,
                    backgroundColor: const Color(0xFFD5E0F2),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${d.percentage}%',
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
    );
  }
}

class _AbsenceStat extends StatelessWidget {
  const _AbsenceStat({required this.detail, required this.justified});

  final CourseDetail detail;
  final int justified;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Inasistencias',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _red,
                  ),
                ),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: _redBg,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: const Icon(Icons.close, size: 16, color: _red),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _two(d.absences),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: _red,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'total',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${d.unjustified} sin just.',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _red,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '• $justified just.',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.green,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LimitBox extends StatelessWidget {
  const _LimitBox({required this.detail});

  final CourseDetail detail;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final r = d.remainingAbsences;
    final max = d.maxAbsences;
    final comfortable = r >= 3;

    final String pill;
    final String body;
    if (r >= 3) {
      pill = '$r RESTANTES';
      body =
          'Máximo $max faltas según reglamento. Aún puedes faltar a $r clases.';
    } else if (r >= 1) {
      pill = r == 1 ? '1 RESTANTE' : '$r RESTANTES';
      body =
          'Máximo $max faltas según reglamento. Superarlo causará pérdida por límite.';
    } else if (r == 0) {
      pill = 'LÍMITE ALCANZADO';
      body =
          'Ya usaste las $max faltas permitidas. Una más causará pérdida por límite.';
    } else {
      pill = 'SUPERADO';
      body = 'Superaste el máximo de $max faltas según reglamento.';
    }

    final fg = comfortable ? AppColors.navy : _red;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: comfortable ? _soft : _redBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: comfortable ? const Color(0xFFDDE6F5) : _redBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: comfortable ? _chipBlue : const Color(0xFFF9D3D3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              comfortable ? Icons.info_outline : Icons.warning_amber_rounded,
              size: 22,
              color: comfortable ? AppColors.green : _red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Límite de Inasistencias',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: fg,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: comfortable
                              ? const Color(0xFFD3DDF0)
                              : _redBorder,
                        ),
                      ),
                      child: Text(
                        pill,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: fg,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: comfortable
                        ? AppColors.textMuted
                        : const Color(0xFF7A2A2A),
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

// ---------------------------------------------------------------------------
// Filtros
// ---------------------------------------------------------------------------
class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.index,
    required this.counts,
    required this.onChanged,
  });

  final int index;
  final List<int> counts;
  final ValueChanged<int> onChanged;

  static const _labels = ['Todas', 'Presentes', 'Faltas', 'Justificadas'];
  static const _countColors = [AppColors.navy, _teal, _red, AppColors.navy];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            _chip(i),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _chip(int i) {
    final selected = index == i;
    return GestureDetector(
      onTap: () => onChanged(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0A2F52) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? const Color(0xFF0A2F52) : const Color(0xFFE1E8F4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _labels[i],
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.18)
                    : _countColors[i].withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${counts[i]}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : _countColors[i],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta de una sesión
// ---------------------------------------------------------------------------
class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.onJustify});

  final HistoryRecord record;
  final VoidCallback onJustify;

  @override
  Widget build(BuildContext context) {
    final r = record;

    final (labelColor, pillBg, pillFg, pillText, pillIcon) = switch (r.kind) {
      AttendanceKind.present => (
        _teal,
        const Color(0xFF86EFD9),
        const Color(0xFF065F52),
        'Presente',
        Icons.check_circle,
      ),
      AttendanceKind.absent => (
        _red,
        _redBg,
        _red,
        'Falta',
        Icons.cancel_outlined,
      ),
      AttendanceKind.justified => (
        AppColors.navy,
        _chipBlue,
        AppColors.navy,
        'Justificada',
        Icons.check_circle_outline,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
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
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'SESIÓN ${r.number}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: labelColor,
                            ),
                          ),
                          TextSpan(
                            text: '  •  ${_dateLine(r.date)}',
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      style: const TextStyle(
                        fontSize: 11.5,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      r.title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(14),
                  border: r.kind == AttendanceKind.absent
                      ? Border.all(color: _redBorder)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(pillIcon, size: 14, color: pillFg),
                    const SizedBox(width: 4),
                    Text(
                      pillText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: pillFg,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _footer(),
        ],
      ),
    );
  }

  Widget _footer() {
    final r = record;

    switch (r.kind) {
      case AttendanceKind.present:
        final (icon, label) = switch (r.method) {
          RecordMethod.qr => (Icons.qr_code_2, 'QR Dinámico Proyectado'),
          RecordMethod.manual => (Icons.dialpad, 'Código manual'),
          RecordMethod.synced => (
            Icons.cloud_done_outlined,
            'Caché Sincronizado',
          ),
          null => (Icons.check, 'Registrada'),
        };
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFFF3F6FC),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: AppColors.navy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const Icon(Icons.schedule, size: 15, color: AppColors.textMuted),
              const SizedBox(width: 5),
              Text(
                _hm(r.date),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        );

      case AttendanceKind.absent:
        return Row(
          children: [
            Icon(
              r.deadlinePassed
                  ? Icons.error_outline
                  : Icons.warning_amber_rounded,
              size: 17,
              color: _red,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                r.deadlinePassed
                    ? 'Plazo vencido (Sin Justificar)'
                    : 'Sin Justificar',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: _red,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (r.deadlinePassed)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF1F8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Inapelable',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8A97A6),
                  ),
                ),
              )
            else
              Material(
                color: _chipBlue,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onJustify,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Justificar',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: AppColors.navy,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );

      case AttendanceKind.justified:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFFF3F6FC),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Aprobado: ${r.approvedBy ?? ''}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Exp. ${r.expediente ?? ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                r.reason ?? '',
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        );
    }
  }
}
