import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_logo.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> actions;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle = 'SPORTSBOOK',
    this.showBack = true,
    this.onBack,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
            )
          else
            const SizedBox(width: 12),
          const AppLogoMark(size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.primary)),
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          ...actions,
          const SizedBox(width: 4),
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
                color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.person_outline,
                color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }
}
