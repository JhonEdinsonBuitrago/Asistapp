import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/name_utils.dart';
import '../data/course_repository.dart';

const _teal = Color(0xFF066A5C);
const _mint = Color(0xFF9DEBD9);
const _blueBg = Color(0xFFE3EBFA);
const _soft = Color(0xFFEFF3FC);
const _navyBtn = Color(0xFF0A2F52);
const _red = Color(0xFFD92D20);

const _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(24)),
  boxShadow: [
    BoxShadow(color: Color(0x120B3A5E), blurRadius: 16, offset: Offset(0, 6)),
  ],
);

IconData _modalityIcon(String id) => switch (id) {
  'laboratorio' => Icons.computer,
  'hibrido' => Icons.devices,
  _ => Icons.meeting_room_outlined,
};

enum _Saving { none, create, draft }

class CreateCourseScreen extends ConsumerStatefulWidget {
  const CreateCourseScreen({super.key});

  @override
  ConsumerState<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends ConsumerState<CreateCourseScreen> {
  static const _minSessions = 4;
  static const _maxSessions = 80;
  static const _notesMax = 240;
  static const _periods = <(String, String)>[
    ('2026-I', 'Vigente'),
    ('2026-II', 'Próximo'),
    ('Interciclo', 'Especial'),
  ];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _notes = TextEditingController();
  late final DocumentReference<Map<String, dynamic>> _ref;

  int _period = 1;
  int _sessions = 32;
  String _modality = 'presencial';
  _Saving _saving = _Saving.none;
  String? _codeError;

  @override
  void initState() {
    super.initState();
    _ref = ref.read(courseRepositoryProvider).newCourseRef();
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _notes.dispose();
    super.dispose();
  }

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

  Future<void> _editSessions() async {
    final controller = TextEditingController(text: '$_sessions');
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Número de clases',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          decoration: InputDecoration(
            helperText: 'Entre $_minSessions y $_maxSessions',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(int.tryParse(controller.text)),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && mounted) {
      setState(
        () => _sessions = value.clamp(_minSessions, _maxSessions).toInt(),
      );
    }
  }

  Future<void> _submit({required bool draft}) async {
    if (_saving != _Saving.none) return;
    setState(() => _codeError = null);
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = draft ? _Saving.draft : _Saving.create);

    try {
      final repo = ref.read(courseRepositoryProvider);
      final code = _code.text.trim();

      if (code.isNotEmpty && await repo.codeExists(code, exceptId: _ref.id)) {
        if (mounted)
          setState(() => _codeError = 'Ya tienes un curso con este código');
        return;
      }

      await repo.saveCourse(
        _ref,
        CourseInput(
          name: _name.text.trim(),
          code: code,
          period: _periods[_period].$1,
          totalSessions: _sessions,
          modality: _modality,
          notes: _notes.text.trim(),
        ),
        draft: draft,
      );
      if (!mounted) return;
      _snack(draft ? 'Borrador guardado' : 'Curso creado correctamente');
      _back();
    } on TimeoutException {
      if (mounted)
        _snack('Sin conexión. Revisa tu internet e intenta de nuevo.');
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _snack(
        e.code == 'permission-denied'
            ? 'Sin permiso: usa una cuenta de docente y publica las reglas de Firestore.'
            : 'No se pudo guardar el curso (${e.code}).',
      );
    } catch (_) {
      if (mounted) _snack('No se pudo guardar el curso.');
    } finally {
      if (mounted) setState(() => _saving = _Saving.none);
    }
  }

  InputDecoration _decoration({
    required String hint,
    Widget? prefix,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF8A97A6)),
      prefixIcon: prefix,
      errorText: errorText,
      counterText: '',
      filled: true,
      fillColor: AppColors.chipBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide.none,
      ),
    );
  }

  // ------------------------------ Interfaz ------------------------------

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final fullName = displayNameOf(user?.displayName, user?.email);
    final initials = initialsOf(fullName);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                _TopBar(onBack: _back, initials: initials),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                      children: [
                        _headerCard(initials),
                        const SizedBox(height: 14),
                        _nameCard(),
                        const SizedBox(height: 14),
                        _periodCard(),
                        const SizedBox(height: 14),
                        _sessionsCard(),
                        const SizedBox(height: 14),
                        _modalityCard(),
                        const SizedBox(height: 14),
                        _notesCard(),
                        const SizedBox(height: 18),
                        _actions(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerCard(String initials) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.navy,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _mint,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.check, size: 14, color: _teal),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: const BoxDecoration(
                    color: _blueBg,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: const Text(
                    'GESTIÓN ACADÉMICA • DOCENTE',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Configura tu nuevo curso',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Define los parámetros básicos para iniciar el control de asistencia inteligente y segura.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardTitle(IconData icon, String title, {Widget? trailing}) {
    return Row(
      children: [
        Icon(icon, size: 21, color: AppColors.navy),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _nameCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            Icons.menu_book_outlined,
            'Nombre de la asignatura',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: const BoxDecoration(
                color: _blueBg,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: const Text(
                'Obligatorio',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 120,
            decoration: _decoration(
              hint: 'Ej. Arquitectura de Software Avanzada',
              prefix: const Icon(
                Icons.school_outlined,
                color: AppColors.textMuted,
              ),
            ),
            validator: (v) => (v == null || v.trim().length < 3)
                ? 'Ingresa el nombre de la asignatura (mínimo 3 letras)'
                : null,
          ),
          const SizedBox(height: 16),
          const Text(
            'Código Materia',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 210,
              child: TextFormField(
                controller: _code,
                maxLength: 12,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
                  TextInputFormatter.withFunction(
                    (oldValue, newValue) =>
                        newValue.copyWith(text: newValue.text.toUpperCase()),
                  ),
                ],
                onChanged: (_) {
                  if (_codeError != null) setState(() => _codeError = null);
                },
                decoration: _decoration(
                  hint: 'EJ. INF-302',
                  prefix: const Icon(Icons.tag, color: AppColors.textMuted),
                  errorText: _codeError,
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null; // es opcional
                  return t.length < 2 ? 'Código muy corto' : null;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodCard() {
    final regular = _period != 2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            Icons.calendar_today_outlined,
            'Periodo Académico',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _teal,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  regular ? 'Ciclo regular' : 'Ciclo especial',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _teal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < _periods.length; i++) ...[
                Expanded(child: _periodOption(i)),
                if (i < _periods.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _periodOption(int i) {
    final selected = _period == i;
    return GestureDetector(
      onTap: () => setState(() => _period = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? _navyBtn : _soft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              _periods[i].$1,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _periods[i].$2,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white70 : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback? onTap) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 1.5,
        shadowColor: const Color(0x1A0B3A5E),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, size: 24, color: AppColors.navy),
          ),
        ),
      ),
    );
  }

  Widget _sessionsCard() {
    final max = _sessions * CourseRepository.tolerancePercent ~/ 100;
    final hours = _sessions * 2;

    final List<InlineSpan> tail;
    if (max == 0) {
      tail = const [
        TextSpan(
          text: ' clases no se permite ninguna inasistencia antes de entrar en estatus de riesgo o reprobación.',
        ),
      ];
    } else {
      tail = [
        const TextSpan(text: ' clases, el límite permitido es de '),
        TextSpan(
          text: ' $max ${max == 1 ? 'inasistencia' : 'inasistencias'} ',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: _red,
            backgroundColor: Color(0xFFFCE0E0),
          ),
        ),
        const TextSpan(
          text: ' antes de entrar en estatus de riesgo o reprobación.',
        ),
      ];
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            Icons.pie_chart_outline,
            'Número total de clases programadas',
          ),
          const SizedBox(height: 4),
          const Text(
            'Semestre estándar de 16 semanas (2 sesiones semanales).',
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: Row(
              children: [
                _stepButton(
                  Icons.remove,
                  _sessions > _minSessions
                      ? () => setState(() => _sessions--)
                      : null,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _editSessions,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$_sessions',
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'sesiones',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _mint.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$hours Horas Académicas',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF065F52),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _stepButton(
                  Icons.add,
                  _sessions < _maxSessions
                      ? () => setState(() => _sessions++)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0E4A78),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: const Icon(
                    Icons.calculate_outlined,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cálculo de tolerancia reglamentaria (20% Máx.)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Con '),
                            TextSpan(
                              text: '$_sessions',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                            ...tail,
                          ],
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Color(0xFF3D4B5C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modalityCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.wifi_tethering, 'Modalidad y verificación de aula'),
          const SizedBox(height: 14),
          for (final m in courseModalities)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ModalityTile(
                modality: m,
                icon: _modalityIcon(m.id),
                selected: _modality == m.id,
                onTap: () => setState(() => _modality = m.id),
              ),
            ),
        ],
      ),
    );
  }

  Widget _notesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            Icons.edit_note,
            'Notas y Criterios Específicos',
            trailing: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _notes,
              builder: (context, value, _) => Text(
                '${value.text.length} / $_notesMax',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _notes,
            maxLength: _notesMax,
            minLines: 4,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration(
              hint: 'Agrega información relevante como horario previsto, tolerancia de minutos (ej. 10 min), aula física o enlaces del syllabus…',
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    final busy = _saving != _Saving.none;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: busy ? null : () => _submit(draft: false),
          style: FilledButton.styleFrom(
            backgroundColor: _navyBtn,
            minimumSize: const Size.fromHeight(58),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: _saving == _Saving.create
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Crear e inicializar curso',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: busy ? null : () => _submit(draft: true),
          style: FilledButton.styleFrom(
            backgroundColor: _blueBg,
            foregroundColor: AppColors.navy,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: _saving == _Saving.draft
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save_outlined, size: 21),
                    SizedBox(width: 10),
                    Text(
                      'Guardar como borrador',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, size: 16, color: AppColors.textMuted),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Los estudiantes registran su asistencia con el QR dinámico y el código de la sesión.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
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
// Piezas
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
            width: 100,
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
            child: Text(
              'Crear Nuevo Curso',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Align(
              alignment: Alignment.centerRight,
              child: CircleAvatar(
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
            ),
          ),
        ],
      ),
    );
  }
}

class _ModalityTile extends StatelessWidget {
  const _ModalityTile({
    required this.modality,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final CourseModality modality;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _blueBg : _soft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: selected ? _navyBtn : _blueBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 23,
                color: selected ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    modality.title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    modality.description,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? _navyBtn : Colors.transparent,
                border: Border.all(
                  color: selected ? _navyBtn : const Color(0xFFB4BFD0),
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 15, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
