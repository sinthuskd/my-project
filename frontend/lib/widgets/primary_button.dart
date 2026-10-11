import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon; // trailing icon
  final IconData? leadingIcon;
  final VoidCallback onPressed;
  final bool small;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leadingIcon,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final h = small ? 44.0 : 56.0;
    return Container(
      width: small ? null : double.infinity,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(h / 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(h / 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(h / 2),
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: small ? 20 : 0),
            child: Center(
              widthFactor: small ? 1 : null,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Row(
                  key: ValueKey(label),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (leadingIcon != null) ...[
                      Icon(leadingIcon, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: small ? 15 : 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: 8),
                      Icon(icon, color: Colors.white, size: 20),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
