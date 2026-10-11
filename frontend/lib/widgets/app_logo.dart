import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Blue rounded logo mark.
class AppLogoMark extends StatelessWidget {
  final double size;
  final IconData icon;
  const AppLogoMark({super.key, this.size = 40, this.icon = Icons.adjust});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.6),
    );
  }
}

/// Logo mark inside a white glowing tile (login / register headers).
class AppLogo extends StatelessWidget {
  final double size;
  final IconData icon;
  const AppLogo({super.key, this.size = 80, this.icon = Icons.adjust});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.22), blurRadius: 24),
        ],
      ),
      child: Center(child: AppLogoMark(size: size * 0.74, icon: icon)),
    );
  }
}
