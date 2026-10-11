import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PartnerFooter extends StatelessWidget {
  final String title;
  final String sub;
  const PartnerFooter({
    super.key,
    this.title = 'OFFICIAL BOOKING PARTNER',
    this.sub = 'Version 2.4.0 • Colombo Sports Authority',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_outlined,
                size: 16, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text(title,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        Text(sub,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ],
    );
  }
}
