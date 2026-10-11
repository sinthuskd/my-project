import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SectionCard extends StatelessWidget {
  final IconData? icon;
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  const SectionCard({
    super.key,
    this.icon,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: padding,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 22, color: AppColors.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(title!,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}

/// Small blue text on the right of a SectionCard title.
class CardTag extends StatelessWidget {
  final String text;
  final bool pill;
  const CardTag(this.text, {super.key, this.pill = false});

  @override
  Widget build(BuildContext context) {
    final t = Text(text,
        style: TextStyle(
            fontSize: pill ? 11 : 14,
            fontWeight: FontWeight.w800,
            letterSpacing: pill ? 0.8 : 0,
            color: AppColors.primary));
    if (!pill) return t;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: AppColors.chip, borderRadius: BorderRadius.circular(20)),
      child: t,
    );
  }
}
