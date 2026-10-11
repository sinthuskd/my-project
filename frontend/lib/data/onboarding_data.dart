import 'package:flutter/material.dart';
import '../models/onboarding_page_data.dart';

const onboardingPages = <OnboardingPageData>[
  OnboardingPageData(
    stepLabel: 'STEP 1 OF 3 • DISCOVER',
    title: 'Find & Book Verified Courts in Seconds',
    description:
        'Explore premium indoor badminton, tennis, and paddle courts near you with live availability and instant slot lock.',
    heroAsset: 'assets/images/discover.jpg',
    heroBadge: 'Courts Available Now Near You',
    heroBadgeIsDot: false,
    showSeal: true,
    heroBottom: HeroBottomType.sports,
    layout: FeatureLayout.tiles,
    features: [
      FeatureItem(Icons.radar, 'Real-time Slot Radar',
          'Direct sync with stadium lighting timers'),
      FeatureItem(Icons.roofing, '100% Weatherproof Arenas',
          'Zero rain cancellations, climate-controlled'),
      FeatureItem(Icons.workspace_premium_outlined, 'Verified Facility Quality',
          'BWF & ITF grade shock-absorbing mats'),
    ],
    footer: 'OFFICIAL PARTNER • COLOMBO SPORTS AUTHORITY',
  ),
  OnboardingPageData(
    stepLabel: 'STEP 2 OF 3',
    tag: 'SQUAD & SPLIT',
    title: 'Rally Your Squad & Split Bills Effortlessly',
    description:
        'Coordinate matches with your regular crew, auto-invite teammates via WhatsApp, and split court costs automatically.',
    heroAsset: 'assets/images/squad.jpg',
    heroBadge: 'Instant Squad Split',
    heroBottom: HeroBottomType.squad,
    layout: FeatureLayout.chips,
    features: [
      FeatureItem(Icons.send_outlined, '1-Tap Team Invites'),
      FeatureItem(Icons.pie_chart_outline, 'Fair cost split'),
      FeatureItem(Icons.verified_outlined, 'Zero hassle booking'),
    ],
    footer: 'OFFICIAL PARTNER • COLOMBO SPORTS AUTHORITY',
  ),
  OnboardingPageData(
    stepLabel: 'STEP 3 OF 3 • DIGITAL ACCESS',
    title: 'Contactless Entry with Digital Match Pass',
    description:
        'Unlock venue turnstiles with dynamic QR codes, access your locker automatically, and never wait in line again.',
    heroAsset: 'assets/images/access.jpg',
    heroBadge: 'Zero-Contact Entry',
    heroBottom: HeroBottomType.access,
    layout: FeatureLayout.chips,
    features: [
      FeatureItem(Icons.qr_code_2, 'Dynamic Turnstile QR'),
      FeatureItem(Icons.lock_open_outlined, 'Keyless Locker Sync'),
      FeatureItem(Icons.account_balance_wallet_outlined,
          'Apple / Google Wallet Ready'),
    ],
    footer: 'Official partner • Colombo Sports Authority',
    footerSub: 'Version 2.4.0 • FastPass Protocol Enabled',
  ),
];
