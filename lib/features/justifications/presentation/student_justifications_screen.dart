import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../student/data/student_courses_data.dart';
import '../../student/data/student_profile_data.dart';
import '../data/justification_data.dart';

const _teal = Color(0xFF066A5C);
const _mint = Color(0xFFD7F5EA);
const _blueBg = Color(0xFFE3EBFA);
const _soft = Color(0xFFEFF3FC);
const _red = Color(0xFFD92D20);
const _redBg = Color(0xFFFCE8E8);
const _redBorder = Color(0xFFF3C6C6);
const _amber = Color(0xFFF5A623);
const _amberFg = Color(0xFFB45309);
const _amberBg = Color(0xFFFFE8CC);

const _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(22)),
  boxShadow: [
    BoxShadow(color: Color(0x120B3A5E), blurRadius: 16, offset: Offset(0, 6)),
  ],
);

/// Abre el formulario para justificar una falta. Devuelve true si se envió.
Future<bool?> showJustifySheet(
  BuildContext context, {
  required CourseAttendance attendance,
  required ClassEntry entry,
  JustificationInfo? previous,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _JustifySheet(attendance: attendance, entry: entry, previous: previous),
  );
}

class _Eligible {
  const _Eligible(this.attendance, this.entry, this.previous, this.state);

  final CourseAttendance attendance;
  final ClassEntry entry;
  final JustificationInfo? previous;
  final JustifyState state;
}

class StudentJustificationsScreen extends ConsumerWidget {
  const StudentJustificationsScreen({super.key, this.courseId});

  /// Si se indica, solo se muestran las faltas y solicitudes de ese curso.
  final String? courseId;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/student');
    }
  }

  void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _justify(BuildContext context, _Eligible item) async {
    final sent = await showJustifySheet(
      context,
      attendance: item.attendance,
      entry: item.entry,
      previous: item.previous,
    );
    if (sent == true && context.mounted) {
      _snack(context, 'Solicitud enviada. El docente la revisará.');
    }
  }

  Future<void> _withdraw(
    BuildContext context,
    WidgetRef ref,
    JustificationInfo j,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          '¿Retirar la solicitud?',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy),
        ),
        content: Text(
          'Se eliminará tu solicitud de la sesión ${j.sessionNumber}. Podrás volver a enviarla mientras siga abierto el plazo.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Retirar', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(justificationRepositoryProvider).withdraw(j.id);
      if (context.mounted) _snack(context, 'Solicitud retirada');
    } catch (_) {
      if (context.mounted)
        _snack(context, 'No se pudo retirar la solicitud. Revisa tu conexión.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(studentOverviewProvider);
    final justAsync = ref.watch(myJustificationsProvider);
    final overview = overviewAsync.value;
    final justs = justAsync.value;

    Widget body;
    if (overview == null || (justs == null && !justAsync.hasError)) {
      body = overviewAsync.hasError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No se pudieron cargar tus faltas. Revisa tu conexión.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _red, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(studentOverviewProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : const Center(child: CircularProgressIndicator());
    } else {
      body = _content(
        context,
        ref,
        overview,
        justs ?? const <JustificationInfo>[],
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _back(context),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.navy,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Justificar Faltas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Actualizar',
                        onPressed: () =>
                            ref.invalidate(studentOverviewProvider),
                        icon: const Icon(Icons.refresh, color: AppColors.navy),
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

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    StudentOverview overview,
    List<JustificationInfo> justs,
  ) {
    final now = DateTime.now();
    final map = {for (final j in justs) j.sessionId: j};

    final eligible = <_Eligible>[];
    for (final ca in overview.courses) {
      if (courseId != null && ca.course.id != courseId) continue;
      for (final e in ca.entries) {
        if (e.kind != EntryKind.absent) continue;
        final j = map[e.session.id];
        final st = justifyStateOf(e, j, now);
        if (st == JustifyState.canJustify || st == JustifyState.retry) {
          eligible.add(_Eligible(ca, e, j, st));
        }
      }
    }
    eligible.sort(
      (a, b) => b.entry.session.endsAt.compareTo(a.entry.session.endsAt),
    );

    final mine = justs
        .where((j) => courseId == null || j.courseId == courseId)
        .toList();

    final courseName = courseId == null
        ? null
        : overview.courses
              .where((c) => c.course.id == courseId)
              .firstOrNull
              ?.course
              .name;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(studentOverviewProvider);
        try {
          await ref.read(studentOverviewProvider.future);
        } catch (_) {}
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          if (courseName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                courseName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: _blueBg,
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 19, color: AppColors.navy),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Puedes pedir que se justifique una falta hasta $kJustifyHours horas después de que termine la clase. El docente revisa tu solicitud y decide. Por ahora no se adjuntan archivos: describe el motivo y, si tienes un comprobante, escribe su número de referencia y entrégalo al docente.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle('Faltas que puedes justificar', eligible.length),
          const SizedBox(height: 10),
          if (eligible.isEmpty)
            const _EmptyBox(
              icon: Icons.check_circle_outline,
              text:
                  'No tienes faltas pendientes de justificar dentro del plazo.',
            ),
          for (final item in eligible)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _EligibleCard(
                item: item,
                now: now,
                showCourse: courseId == null,
                onJustify: () => _justify(context, item),
              ),
            ),
          const SizedBox(height: 14),
          _SectionTitle('Mis solicitudes', mine.length),
          const SizedBox(height: 10),
          if (mine.isEmpty)
            const _EmptyBox(
              icon: Icons.assignment_outlined,
              text: 'Aún no has enviado solicitudes.',
            ),
          for (final j in mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RequestCard(
                j: j,
                onWithdraw: () => _withdraw(context, ref, j),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, this.count);

  final String text;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: const BoxDecoration(
            color: _blueBg,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Column(
        children: [
          Icon(icon, size: 34, color: AppColors.textMuted),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _EligibleCard extends StatelessWidget {
  const _EligibleCard({
    required this.item,
    required this.now,
    required this.showCourse,
    required this.onJustify,
  });

  final _Eligible item;
  final DateTime now;
  final bool showCourse;
  final VoidCallback onJustify;

  @override
  Widget build(BuildContext context) {
    final e = item.entry;
    final left = justifyDeadline(e.session.endsAt).difference(now);
    final urgent = left.inHours < 24;
    final retry = item.state == JustifyState.retry;
    final prev = item.previous;

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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showCourse)
                              Text(
                                item.attendance.course.name,
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy,
                                  height: 1.2,
                                ),
                              ),
                            Text(
                              'Sesión ${e.number} • ${jDateLine(e.session.startsAt)}',
                              style: TextStyle(
                                fontSize: showCourse ? 12.5 : 15,
                                fontWeight: showCourse
                                    ? FontWeight.w500
                                    : FontWeight.w800,
                                color: showCourse
                                    ? AppColors.textMuted
                                    : AppColors.navy,
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
                          color: urgent ? _redBg : _amberBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: urgent ? _red : _amberFg,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Quedan ${jLeft(left)}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: urgent ? _red : _amberFg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (retry && prev != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _redBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _redBorder),
                      ),
                      child: Text(
                        prev.decisionNote.isEmpty
                            ? 'Tu solicitud anterior fue rechazada.'
                            : 'Tu solicitud anterior fue rechazada: ${prev.decisionNote}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: _red,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onJustify,
                      icon: const Icon(Icons.edit_note, size: 20),
                      label: Text(retry ? 'Volver a solicitar' : 'Justificar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.navy,
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
                ],
              ),
            ),
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: ColoredBox(color: _red),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.j, required this.onWithdraw});

  final JustificationInfo j;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final (accent, pillBg, pillFg, pillText, pillIcon) = switch (j.status) {
      JustificationStatus.pending => (
        _amber,
        _amberBg,
        _amberFg,
        'En revisión',
        Icons.schedule,
      ),
      JustificationStatus.approved => (
        _teal,
        const Color(0xFF86EFD9),
        const Color(0xFF065F52),
        'Aprobada',
        Icons.verified_user_outlined,
      ),
      JustificationStatus.rejected => (
        _red,
        _redBg,
        _red,
        'Rechazada',
        Icons.cancel_outlined,
      ),
    };

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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              j.courseName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Sesión ${j.sessionNumber} • ${jDateLine(j.sessionDate)}',
                              style: const TextStyle(
                                fontSize: 12.5,
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
                          borderRadius: BorderRadius.circular(14),
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
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF3D4B5C),
                    ),
                  ),
                  if (j.reference.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Referencia: ${j.reference}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  if (j.status == JustificationStatus.approved) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _mint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Constancia #${j.code}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF065F52),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            j.decisionNote.isEmpty
                                ? 'Aprobada por el docente. La falta quedó justificada.'
                                : 'Aprobada por el docente: ${j.decisionNote}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: Color(0xFF0B5C47),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (j.status == JustificationStatus.rejected) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _redBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _redBorder),
                      ),
                      child: Text(
                        j.decisionNote.isEmpty
                            ? 'El docente rechazó la solicitud.'
                            : 'El docente rechazó la solicitud: ${j.decisionNote}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: _red,
                        ),
                      ),
                    ),
                  ],
                  if (j.status == JustificationStatus.pending) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Esperando la decisión del docente',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: onWithdraw,
                          child: const Text(
                            'Retirar solicitud',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _red,
                            ),
                          ),
                        ),
                      ],
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

// ---------------------------------------------------------------------------
// Formulario
// ---------------------------------------------------------------------------
class _JustifySheet extends ConsumerStatefulWidget {
  const _JustifySheet({
    required this.attendance,
    required this.entry,
    this.previous,
  });

  final CourseAttendance attendance;
  final ClassEntry entry;
  final JustificationInfo? previous;

  @override
  ConsumerState<_JustifySheet> createState() => _JustifySheetState();
}

class _JustifySheetState extends ConsumerState<_JustifySheet> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _reference = TextEditingController();
  JustificationCategory _category = JustificationCategory.medico;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    _reference.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF8A97A6)),
    filled: true,
    fillColor: AppColors.chipBackground,
    counterText: '',
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide.none,
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final profile = ref.read(studentProfileProvider).value;
      final e = widget.entry;
      final name = (profile?.name.isNotEmpty ?? false)
          ? profile!.name
          : (user?.displayName ?? user?.email ?? '');

      await ref
          .read(justificationRepositoryProvider)
          .submit(
            courseId: widget.attendance.course.id,
            courseName: widget.attendance.course.name,
            sessionId: e.session.id,
            sessionNumber: e.number,
            sessionDate: e.session.startsAt,
            teacherId: e.session.teacherId,
            studentName: name,
            studentCode: profile?.studentCode ?? '',
            category: _category,
            description: _description.text,
            reference: _reference.text,
            replace: widget.previous != null,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on TimeoutException {
      if (mounted) {
        setState(
          () => _error = 'Sin conexión. Revisa tu internet e intenta de nuevo.',
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.code == 'permission-denied'
              ? 'No se pudo enviar: el plazo venció o no estás matriculado en el curso.'
              : 'No se pudo enviar la solicitud (${e.code}).',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo enviar la solicitud.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final left = justifyDeadline(e.session.endsAt).difference(DateTime.now());

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6E0F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Justificar falta',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.attendance.course.name} • Sesión ${e.number} • ${jDateLine(e.session.startsAt)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Te quedan ${jLeft(left)} para enviar esta solicitud.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _amberFg,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Motivo',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in JustificationCategory.values)
                      ChoiceChip(
                        avatar: Icon(
                          c.icon,
                          size: 17,
                          color: _category == c ? Colors.white : AppColors.navy,
                        ),
                        label: Text(c.label),
                        selected: _category == c,
                        selectedColor: AppColors.navy,
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _category == c ? Colors.white : AppColors.navy,
                        ),
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _category.hint,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Descripción',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _description,
                  maxLength: 500,
                  minLines: 4,
                  maxLines: 7,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _decoration('Cuéntale al docente qué ocurrió…'),
                  validator: (v) => (v == null || v.trim().length < 10)
                      ? 'Describe el motivo (mínimo 10 caracteres)'
                      : null,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Referencia del comprobante (opcional)',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _reference,
                  maxLength: 60,
                  decoration: _decoration(
                    'Ej. número del certificado o incapacidad',
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Entrega el comprobante al docente. Aquí solo se registra su número.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.textMuted,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(color: _red, fontSize: 12.5),
                  ),
                ],
                const SizedBox(height: 18),
                GradientButton(
                  label: widget.previous != null
                      ? 'Volver a enviar'
                      : 'Enviar solicitud',
                  icon: Icons.send,
                  loading: _saving,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
