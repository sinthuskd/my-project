import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shows an image that the admin typed in: a web URL (http...) or an app asset
/// path (assets/images/...). Never crashes - shows a placeholder if it fails.
class AppImage extends StatelessWidget {
  final String path;
  final BoxFit fit;
  const AppImage(this.path, {super.key, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: AppColors.chip,
      alignment: Alignment.center,
      child: const Icon(Icons.sports_tennis, size: 48, color: AppColors.primary),
    );
    if (path.isEmpty) return fallback;
    if (path.startsWith('http')) {
      return Image.network(path,
          fit: fit, errorBuilder: (_, __, ___) => fallback);
    }
    return Image.asset(path, fit: fit, errorBuilder: (_, __, ___) => fallback);
  }
}
