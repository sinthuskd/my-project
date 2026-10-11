import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  const SecondaryButton(
      {super.key, required this.label, required this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onPressed,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: AppColors.textDark),
                const SizedBox(width: 8),
              ],
              Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
