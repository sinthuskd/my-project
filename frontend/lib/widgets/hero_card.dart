import 'package:flutter/material.dart';
import '../models/onboarding_page_data.dart';
import '../theme/app_colors.dart';
import 'pill_chip.dart';

/// Big photo card with a badge on top and an overlay at the bottom.
class HeroCard extends StatelessWidget {
  final String asset;
  final Widget topBadge;
  final Widget? bottom;
  final bool showSeal;
  final double height;

  const HeroCard({
    super.key,
    required this.asset,
    required this.topBadge,
    this.bottom,
    this.showSeal = false,
    this.height = 280,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(asset, fit: BoxFit.cover),
            Positioned(
              left: 14,
              top: 14,
              right: showSeal ? 66 : 14,
              child: Align(alignment: Alignment.centerLeft, child: topBadge),
            ),
            if (showSeal)
              Positioned(
                right: 14,
                top: 14,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.verified_outlined,
                      color: AppColors.primary),
                ),
              ),
            if (bottom != null)
              Positioned(left: 14, right: 14, bottom: 14, child: bottom!),
          ],
        ),
      ),
    );
  }
}

/// White glass badge shown on top of the photo.
class HeroBadge extends StatelessWidget {
  final String text;
  final bool dot;
  const HeroBadge({super.key, required this.text, this.dot = true});

  @override
  Widget build(BuildContext context) {
    return PillChip(
      text: text,
      dot: dot,
      icon: dot ? null : Icons.wifi_tethering,
      background: Colors.white.withValues(alpha: 0.92),
      fontSize: 13,
    );
  }
}

/// Bottom overlay that changes depending on the onboarding page.
class HeroBottom extends StatelessWidget {
  final HeroBottomType type;
  const HeroBottom({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case HeroBottomType.sports:
        return const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SportChip('🏸', 'Badminton'),
            _SportChip('🎾', 'Tennis'),
            _SportChip('🏀', 'Basketball'),
            _SportChip('🏓', 'Padel'),
          ],
        );
      case HeroBottomType.squad:
        return _glass(
          Row(
            children: [
              const _Avatar('S', Color(0xFF3B6EF0)),
              const _Avatar('A', Color(0xFF0B4FD6)),
              const _Avatar('D', Color(0xFF6B7488)),
              const _Avatar('K', Color(0xFF0B4FD6)),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL SHARE',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5)),
                    Text('Equal split',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                  ],
                ),
              ),
              const PillChip(
                  text: 'AUTO PAY',
                  icon: Icons.bolt,
                  bold: true,
                  foreground: AppColors.primary,
                  fontSize: 12),
            ],
          ),
        );
      case HeroBottomType.access:
        return _glass(
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.qr_code_2, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Turnstile Entry',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    Text('Instant NFC & Optical sync',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const PillChip(
                  text: 'Scan & Play',
                  icon: Icons.check_circle_outline,
                  foreground: AppColors.primary,
                  fontSize: 12),
            ],
          ),
        );
    }
  }

  Widget _glass(Widget child) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(22),
        ),
        child: child,
      );
}

class _SportChip extends StatelessWidget {
  final String emoji;
  final String label;
  const _SportChip(this.emoji, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text('$emoji $label',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String letter;
  final Color color;
  const _Avatar(this.letter, this.color);

  @override
  Widget build(BuildContext context) {
    return Align(
      widthFactor: 0.7,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(letter,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
      ),
    );
  }
}
