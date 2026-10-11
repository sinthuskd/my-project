import 'package:flutter/material.dart';
import 'app_image.dart';
import '../models/court.dart';
import '../theme/app_colors.dart';
import 'primary_button.dart';

class CourtCard extends StatelessWidget {
  final Court court;
  final VoidCallback onBook;
  final VoidCallback? onTap;
  const CourtCard(
      {super.key, required this.court, required this.onBook, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: AppColors.textDark.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 160,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(court.imageAsset),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _Pill(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star,
                              size: 16, color: AppColors.warning),
                          const SizedBox(width: 4),
                          Text(court.rating.toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 14)),
                          Text(' (${court.reviews})',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: _Pill(
                      child: Text('${court.distanceKm} KM',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: AppColors.primary)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(court.name,
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: AppColors.chip,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(court.surface,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(court.address,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('NEXT AVAILABLE',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: AppColors.primary)),
                            const SizedBox(height: 2),
                            Text.rich(TextSpan(
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w800),
                              children: [
                                TextSpan(
                                    text:
                                        '${court.nextAvailable} • ${court.priceLabel}'),
                                const TextSpan(
                                    text: '/hr',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary)),
                              ],
                            )),
                          ],
                        ),
                      ),
                      PrimaryButton(
                          label: 'Book Slot', small: true, onPressed: onBook),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final Widget child;
  const _Pill({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      );
}
