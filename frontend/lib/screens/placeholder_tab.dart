import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Temporary tab. Teammates / later milestones replace these.
class PlaceholderTab extends StatelessWidget {
  final String title;
  final String note;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  const PlaceholderTab(
      {super.key,
      required this.title,
      required this.note,
      required this.icon,
      this.actionLabel,
      this.onAction});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                    color: AppColors.chip, shape: BoxShape.circle),
                child: Icon(icon, size: 34, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(note,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.textSecondary)),
              if (actionLabel != null) ...[
                const SizedBox(height: 20),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
