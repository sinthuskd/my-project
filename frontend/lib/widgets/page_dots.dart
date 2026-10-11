import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PageDots extends StatelessWidget {
  final int count;
  final int current;
  const PageDots({super.key, required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.dotInactive,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}
