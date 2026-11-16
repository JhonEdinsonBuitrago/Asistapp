import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/name_utils.dart';
import '../data/justification_data.dart';

const _teal = Color(0xFF066A5C);
const _mint = Color(0xFFD7F5EA);
const _mintStrong = Color(0xFF86EFD9);
const _blueBg = Color(0xFFE3EBFA);
const _soft = Color(0xFFEFF3FC);
const _navyBtn = Color(0xFF0A2F52);
const _red = Color(0xFFD92D20);
const _redBg = Color(0xFFFCE8E8);
const _redBorder = Color(0xFFF3C6C6);
const _amber = Color(0xFFF5A623);
const _amberFg = Color(0xFFB45309);
const _amberBg = Color(0xFFFFE8CC);

class TeacherJustificationsScreen extends ConsumerStatefulWidget {
  const TeacherJustificationsScreen({super.key, this.courseId});

  /// Si se indica, solo se muestran las solicitudes de ese curso.
  final String? courseId;

  @override
  ConsumerState<TeacherJustificationsScreen> createState() =>
      _TeacherJustificationsScreenState();
}

class _TeacherJustificationsScreenState
    extends ConsumerState<TeacherJustificationsScreen> {
  int _filter = 0; // 0 pendientes, 1 aprobadas, 2 rechazadas, 3 todas

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/teacher');
    }
  }

  bool _matches(JustificationInfo j) => switch (_filter) {
    0 => j.status == JustificationStatus.pending,
    1 => j.status == JustificationStatus.approved,
    2 => j.status == JustificationStatus.rejected,
    _ => true,
  };

  Future<void> _decide(JustificationInfo j, bool approve) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _DecisionDialog(j: j, approve: approve),
    );
    if (note == null || !mounted) return;

    try {
      await ref
          .read(justificationRepositoryProvider)
          .decide(j.id, approve: approve, note: note);
      if (mounted)
        _snack(approve ? 'Justificación aprobada' : 'Justificación rechazada');
    } catch (_) {
      if (mounted)
        _snack('No se pudo guardar la decisión. Revisa tu conexión.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final initials = initialsOf(displayNameOf(user?.displayName, user?.email));
    final async = ref.watch(teacherJustificationsProvider);

    final Widget body = async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No se pudieron cargar las solicitudes. Revisa tu conexión.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _red, height: 1.4),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(teacherJustificationsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
      data: _content,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 16, 4),
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
                        child: Text(
                          'Justificaciones',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
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

  Widget _content(List<JustificationInfo> all) {
    final scoped = all
        .where((j) => widget.courseId == null || j.courseId == widget.courseId)
        .toList();
    final pending = scoped
        .where((j) => j.status == JustificationStatus.pending)
        .length;
    final approved = scoped
        .where((j) => j.status == JustificationStatus.approved)
        .length;
    final rejected = scoped
        .where((j) => j.status == JustificationStatus.rejected)
        .length;
    final list = scoped.where(_matches).toList();

    final courseName = widget.courseId == null || scoped.isEmpty
        ? null
        : scoped.first.courseName;

    final labels = [
      'Pendientes ($pending)',
      'Aprobadas ($approved)',
      'Rechazadas ($rejected)',
      'Todas (${scoped.length})',
    ];

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(teacherJustificationsProvider),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          if (widget.courseId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: const BoxDecoration(
                        color: _blueBg,
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                      child: Text(
                        courseName ?? 'Este curso',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        context.pushReplacement('/teacher/justifications'),
                    child: const Text(
                      'Ver todos los cursos',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < labels.length; i++) ...[
                  GestureDetector(
                    onTap: () => setState(() => _filter = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: _filter == i ? _navyBtn : _blueBg,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _filter == i ? Colors.white : AppColors.navy,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
              child: Column(
                children: [
                  const Icon(
                    Icons.assignment_turned_in_outlined,
                    size: 46,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    scoped.isEmpty
                        ? 'Aún no hay solicitudes de justificación.'
                        : 'No hay solicitudes en esta categoría.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Las solicitudes de tus estudiantes aparecerán aquí. Los avisos de ejemplo del home no corresponden a solicitudes reales.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          for (final j in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RequestCard(
                j: j,
                onApprove: () => _decide(j, true),
                onReject: () => _decide(j, false),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta de solicitud
// ---------------------------------------------------------------------------
class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.j,
    required this.onApprove,
    required this.onReject,
  });

  final JustificationInfo j;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final (accent, pillBg, pillFg, pillText) = switch (j.status) {
      JustificationStatus.pending => (_amber, _amberBg, _amberFg, 'Pendiente'),
      JustificationStatus.approved => (
        _teal,
        _mintStrong,
        const Color(0xFF065F52),
        'Aprobada',
      ),
      JustificationStatus.rejected => (_red, _redBg, _red, 'Rechazada'),
    };

    final initials = initialsOf(j.studentName);

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: _blueBg,
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              j.studentName.isEmpty
                                  ? 'Estudiante'
                                  : j.studentName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                                height: 1.2,
                              ),
                            ),
                            if (j.studentCode.isNotEmpty)
                              Text(
                                'Mat. ${j.studentCode}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          pillText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: pillFg,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: _soft,
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          j.courseName,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Falta de la sesión ${j.sessionNumber} • ${jDateLine(j.sessionDate)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(j.category.icon, size: 16, color: AppColors.navy),
                      const SizedBox(width: 6),
                      Text(
                        'Justificación ${j.category.label.toLowerCase()}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Enviada ${jAgo(j.createdAt)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    j.description,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: Color(0xFF3D4B5C),
                    ),
                  ),
                  if (j.reference.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.attach_file,
                          size: 16,
                          color: AppColors.navy,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Referencia del comprobante: ${j.reference}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (j.status == JustificationStatus.pending)
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: onApprove,
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 19,
                            ),
                            label: const Text('Aprobar'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _teal,
                              minimumSize: const Size.fromHeight(46),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onReject,
                            icon: const Icon(
                              Icons.cancel_outlined,
                              size: 19,
                              color: _red,
                            ),
                            label: const Text(
                              'Rechazar',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _red,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              side: const BorderSide(color: _redBorder),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: j.status == JustificationStatus.approved
                            ? _mint
                            : _redBg,
                        borderRadius: BorderRadius.circular(12),
                        border: j.status == JustificationStatus.approved
                            ? null
                            : Border.all(color: _redBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            j.status == JustificationStatus.approved
                                ? 'Aprobada • Constancia #${j.code}'
                                : 'Rechazada',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: j.status == JustificationStatus.approved
                                  ? const Color(0xFF065F52)
                                  : _red,
                            ),
                          ),
                          if (j.decisionNote.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              j.decisionNote,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                color: j.status == JustificationStatus.approved
                                    ? const Color(0xFF0B5C47)
                                    : _red,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: j.status == JustificationStatus.approved
                            ? onReject
                            : onApprove,
                        child: Text(
                          j.status == JustificationStatus.approved
                              ? 'Cambiar a rechazada'
                              : 'Cambiar a aprobada',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
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
              child: ColoredBox(color: accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionDialog extends StatefulWidget {
  const _DecisionDialog({required this.j, required this.approve});

  final JustificationInfo j;
  final bool approve;

  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final approve = widget.approve;
    final j = widget.j;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        approve ? 'Aprobar justificación' : 'Rechazar justificación',
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
            Text(
              '${j.studentName} • Sesión ${j.sessionNumber} (${jDateLine(j.sessionDate)})',
              style: const TextStyle(fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLength: 240,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: approve
                    ? 'Nota para el estudiante (opcional)'
                    : 'Motivo del rechazo (recomendado)',
              ),
            ),
            if (approve)
              const Text(
                'La falta quedará marcada como justificada y se generará una constancia.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_note.text),
          child: Text(
            approve ? 'Aprobar' : 'Rechazar',
            style: TextStyle(
              color: approve ? _teal : _red,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
