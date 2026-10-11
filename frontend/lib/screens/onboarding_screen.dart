import 'package:flutter/material.dart';
import '../data/onboarding_data.dart';
import '../models/onboarding_page_data.dart';
import '../theme/app_colors.dart';
import '../widgets/feature_tile.dart';
import '../widgets/hero_card.dart';
import '../widgets/login_link.dart';
import '../widgets/page_dots.dart';
import '../widgets/pill_chip.dart';
import '../widgets/primary_button.dart';
import '../utils/routes.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  bool get _isLast => _page == onboardingPages.length - 1;

  void _goLogin() => Navigator.of(context)
      .pushReplacement(fadeRoute(const LoginScreen()));

  void _goRegister() => Navigator.of(context)
      .pushReplacement(fadeRoute(const RegisterScreen()));

  void _next() {
    if (_isLast) {
      _goRegister();
    } else {
      _controller.nextPage(
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  void _back() {
    if (_page == 0) {
      Navigator.of(context).pop();
    } else {
      _controller.previousPage(
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = onboardingPages[_page];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: back, step chip, skip
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  if (_page > 0)
                    GestureDetector(
                      onTap: _back,
                      child: Container(
                        width: 44,
                        height: 44,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: const BoxDecoration(
                            color: AppColors.chip, shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_back, size: 22),
                      ),
                    ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: PillChip(
                      key: ValueKey(data.stepLabel),
                      text: data.stepLabel,
                      dot: true,
                      bold: true,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _goLogin,
                    child: const Text('Skip',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: onboardingPages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _OnboardingPage(data: onboardingPages[i]),
              ),
            ),
            // Fixed bottom area
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                children: [
                  PageDots(count: onboardingPages.length, current: _page),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: _isLast ? 'Get Started Now' : 'Next',
                    icon: _isLast
                        ? Icons.rocket_launch_outlined
                        : Icons.arrow_forward,
                    onPressed: _next,
                  ),
                  const SizedBox(height: 12),
                  LoginLink(onTap: _goLogin),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Column(
                      key: ValueKey(_page),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.verified,
                                size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(data.footer,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.4,
                                      color: AppColors.textSecondary)),
                            ),
                          ],
                        ),
                        if (data.footerSub != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(data.footerSub!,
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textMuted)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final OnboardingPageData data;
  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeroCard(
            asset: data.heroAsset,
            showSeal: data.showSeal,
            height: 270,
            topBadge: HeroBadge(text: data.heroBadge, dot: data.heroBadgeIsDot),
            bottom: HeroBottom(type: data.heroBottom),
          ),
          const SizedBox(height: 20),
          if (data.tag != null)
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PillChip(
                  text: data.tag!,
                  icon: Icons.groups_outlined,
                  bold: true,
                  fontSize: 12,
                ),
              ),
            ),
          Text(
            data.title,
            textAlign: data.tag != null ? TextAlign.center : TextAlign.start,
            style: const TextStyle(
                fontSize: 30,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8),
          ),
          const SizedBox(height: 12),
          Text(
            data.description,
            textAlign: data.tag != null ? TextAlign.center : TextAlign.start,
            style: const TextStyle(
                fontSize: 15, height: 1.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          if (data.layout == FeatureLayout.tiles)
            ...data.features.map((f) => FeatureTile(item: f))
          else
            Align(
              alignment:
                  data.tag != null ? Alignment.center : Alignment.centerLeft,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: data.tag != null
                    ? WrapAlignment.center
                    : WrapAlignment.start,
                children: data.features
                    .map((f) =>
                        PillChip(text: f.title, icon: f.icon, fontSize: 14))
                    .toList(),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
