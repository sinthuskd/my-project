import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Rounded pill used for step labels, tags, feature chips.
class PillChip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool dot;
  final bool bold;
  final Color background;
  final Color foreground;
  final double fontSize;

  const PillChip({
    super.key,
    required this.text,
    this.icon,
    this.dot = false,
    this.bold = false,
    this.background = AppColors.chip,
    this.foreground = AppColors.textDark,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
          ],
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                color: foreground,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: bold ? 0.6 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
