import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BottomActionBar extends StatelessWidget {
  final Widget child;
  const BottomActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: AppColors.textDark.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}
