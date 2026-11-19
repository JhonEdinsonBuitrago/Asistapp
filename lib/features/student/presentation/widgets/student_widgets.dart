import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

const _red = Color(0xFFD92D20);

// ---------------------------------------------------------------------------
// Aviso para justificar inasistencias
// ---------------------------------------------------------------------------
class JustificationBanner extends StatelessWidget {
  const JustificationBanner({
    super.key,
    required this.hoursLeft,
    required this.onJustify,
  });

  final int hoursLeft;
  final VoidCallback onJustify;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3FC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE6F5)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: const Icon(
              Icons.event_note_outlined,
              size: 20,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿Faltaste por causa médica o fuerza mayor?',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tienes hasta ${hoursLeft}h para radicar soportes',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFD3DDF0)),
            ),
            child: InkWell(
              onTap: onJustify,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Text(
                  'Justificar',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
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

// ---------------------------------------------------------------------------
// Filtro Todos / En riesgo
// ---------------------------------------------------------------------------
class CourseFilterTabs extends StatelessWidget {
  const CourseFilterTabs({
    super.key,
    required this.index,
    required this.total,
    required this.riskCount,
    required this.onChanged,
  });

  final int index; // 0 = todos, 1 = en riesgo
  final int total;
  final int riskCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: AppColors.chipBackground,
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FilterTab(
              label: 'Todos ($total)',
              selected: index == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _FilterTab(
              label: 'En riesgo ($riskCount)',
              selected: index == 1,
              dot: riskCount > 0,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot = false,
  });

  final String label;
  final bool selected;
  final bool dot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x1A0B3A5E),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.navy : AppColors.textMuted,
              ),
            ),
            if (dot) ...[
              const SizedBox(width: 6),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: _red,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
