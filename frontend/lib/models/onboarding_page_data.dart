import 'package:flutter/material.dart';

enum FeatureLayout { tiles, chips }

enum HeroBottomType { sports, squad, access }

class FeatureItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  const FeatureItem(this.icon, this.title, [this.subtitle]);
}

class OnboardingPageData {
  final String stepLabel;
  final String? tag;
  final String title;
  final String description;
  final String heroAsset;
  final String heroBadge;
  final bool heroBadgeIsDot;
  final bool showSeal;
  final HeroBottomType heroBottom;
  final List<FeatureItem> features;
  final FeatureLayout layout;
  final String footer;
  final String? footerSub;

  const OnboardingPageData({
    required this.stepLabel,
    this.tag,
    required this.title,
    required this.description,
    required this.heroAsset,
    required this.heroBadge,
    this.heroBadgeIsDot = true,
    this.showSeal = false,
    required this.heroBottom,
    required this.features,
    required this.layout,
    required this.footer,
    this.footerSub,
  });
}
