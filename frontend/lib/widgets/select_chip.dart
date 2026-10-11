import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool showCheck;

  const SelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.showCheck = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.textDark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 5))
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showCheck && selected) ...[
              const Icon(Icons.check_circle_outline,
                  size: 18, color: Colors.white),
              const SizedBox(width: 8),
            ] else if (icon != null) ...[
              Icon(icon,
                  size: 18, color: selected ? Colors.white : AppColors.primary),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: fg)),
            ),
            if (showCheck && selected && icon == null) ...[
              // trailing check for sport chips handled by leading icon
            ],
          ],
        ),
      ),
    );
  }
}
