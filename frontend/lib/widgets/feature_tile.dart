import 'package:flutter/material.dart';
import '../models/onboarding_page_data.dart';
import '../theme/app_colors.dart';

class FeatureTile extends StatelessWidget {
  final FeatureItem item;
  const FeatureTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
                color: AppColors.iconBg, shape: BoxShape.circle),
            child: Icon(item.icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                if (item.subtitle != null)
                  Text(item.subtitle!,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
