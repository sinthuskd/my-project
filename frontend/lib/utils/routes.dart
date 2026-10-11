import 'package:flutter/material.dart';

Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    );

/// Lets non-widget code (e.g. the admin API on a 401) navigate.
final GlobalKey<NavigatorState> rootNavKey = GlobalKey<NavigatorState>();
