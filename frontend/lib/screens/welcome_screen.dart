import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/hero_card.dart';
import '../widgets/login_link.dart';
import '../widgets/primary_button.dart';
import '../utils/routes.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _login(BuildContext c) =>
      Navigator.of(c).push(fadeRoute(const LoginScreen()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (_, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(
                  offset: Offset(0, 20 * (1 - v)), child: child),
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => _login(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Skip',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const HeroCard(
                  asset: 'assets/images/welcome.jpg',
                  height: 250,
                  topBadge: HeroBadge(text: '38 courts available now'),
                  bottom: Row(
                    children: [
                      _SportPill(Icons.sports_tennis, 'TENNIS'),
                      SizedBox(width: 8),
                      _SportPill(Icons.sports_basketball, 'BASKETBALL'),
                      SizedBox(width: 8),
                      Flexible(child: _SportPill(Icons.sports_tennis, 'PADDLE')),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 20)
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(18)),
                      child: const Icon(Icons.adjust,
                          color: Colors.white, size: 36),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('SportsBook',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1)),
                const SizedBox(height: 4),
                const Text('Instant courts, zero friction.',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                const Text(
                  'Find, book, and play on premium basketball, tennis, and paddle courts in seconds across the city.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Expanded(
                        child: _MiniFeature(
                            Icons.schedule, 'Real-time\nSlots')),
                    SizedBox(width: 10),
                    Expanded(
                        child: _MiniFeature(
                            Icons.verified_outlined, 'Verified\nVenues')),
                    SizedBox(width: 10),
                    Expanded(
                        child: _MiniFeature(Icons.bolt, 'Instant\nConfirm')),
                  ],
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Get Started',
                  icon: Icons.arrow_forward,
                  onPressed: () => Navigator.of(context)
                      .push(fadeRoute(const OnboardingScreen())),
                ),
                const SizedBox(height: 16),
                LoginLink(onTap: () => _login(context)),
                const SizedBox(height: 16),
                const Text(
                  'Official partner • Colombo Sports Authority\nVersion 2.4.0',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textMuted, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SportPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SportPill(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _MiniFeature extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniFeature(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
          color: AppColors.card, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
                color: AppColors.iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 19, color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
