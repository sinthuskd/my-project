import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/routes.dart';
import '../widgets/app_logo.dart';
import '../widgets/primary_button.dart';
import '../widgets/secondary_button.dart';
import 'main_shell.dart';

class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(seconds: 3))
    ..repeat();

  void _goHome() => Navigator.of(context)
      .pushAndRemoveUntil(fadeRoute(const MainShell()), (r) => false);

  void _enable() {
    // TODO: use the geolocator package to request real permission later
    _goHome();
  }

  void _manual() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Manual location selection is coming soon')));
    _goHome();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                          color: AppColors.card, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back),
                    ),
                  ),
                  const Spacer(),
                  const AppLogoMark(size: 40),
                  const SizedBox(width: 8),
                  const Text.rich(TextSpan(
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                    children: [
                      TextSpan(text: 'Sports'),
                      TextSpan(
                          text: 'Book',
                          style: TextStyle(color: AppColors.primary)),
                    ],
                  )),
                  const Spacer(),
                  GestureDetector(
                    onTap: _goHome,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(24)),
                      child: const Text('Maybe Later',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 300,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) {
                        final t = math.sin(_pulse.value * 2 * math.pi);
                        Widget ring(double d, double a) => Container(
                              width: d + t * 8,
                              height: d + t * 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withValues(alpha: a),
                              ),
                            );
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            ring(260, 0.05),
                            ring(200, 0.07),
                            ring(140, 0.09),
                          ],
                        );
                      },
                    ),
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 10)),
                        ],
                      ),
                      child: Transform.rotate(
                        angle: 0.75,
                        child: const Icon(Icons.navigation,
                            color: Colors.white, size: 38),
                      ),
                    ),
                    const Align(
                      alignment: Alignment(0.22, 0.12),
                      child: _MiniBadge(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text('Find Courts Near You Automatically',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 32,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8)),
              const SizedBox(height: 12),
              const Text(
                'Enable location access so SportsBook can show real-time court availability, instant travel times, and local tournaments across Colombo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, height: 1.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              const _InfoCard(Icons.explore_outlined, 'Nearest Court Discovery',
                  'Instant distance calculation to top-rated indoor & outdoor arenas.'),
              const _InfoCard(Icons.schedule, 'Real-Time Slot Availability',
                  'Prioritize courts you can reach in under 15 minutes.'),
              const _InfoCard(
                  Icons.wb_cloudy_outlined,
                  'Live Weather & Court Conditions',
                  'Accurate outdoor court playability warnings before you depart.'),
              const SizedBox(height: 14),
              PrimaryButton(
                  label: 'Enable Location Access',
                  leadingIcon: Icons.location_on_outlined,
                  onPressed: _enable),
              const SizedBox(height: 12),
              SecondaryButton(
                  label: 'Enter Location Manually',
                  icon: Icons.search,
                  onPressed: _manual),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Icon(Icons.lock, size: 18, color: AppColors.textSecondary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'We only use your location while using the app to show nearby facilities. Your privacy is protected.',
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Colombo Sports Authority Partner • Version 2.4.0',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge();
  @override
  Widget build(BuildContext context) => Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
            color: Colors.white, shape: BoxShape.circle),
        child: const Icon(Icons.sports_tennis,
            size: 18, color: AppColors.primary),
      );
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  const _InfoCard(this.icon, this.title, this.sub);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.textDark.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
