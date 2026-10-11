import 'package:flutter/material.dart';
import 'admin/admin_shell.dart';
import 'flow/flow_registry.dart';
import 'screens/main_shell.dart';
import 'screens/welcome_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'utils/routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFlow();
  await AuthService.init(); // restores the saved login (token + profile)
  runApp(const SportsBookApp());
}

class SportsBookApp extends StatelessWidget {
  const SportsBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SportsBook',
      navigatorKey: rootNavKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) => Container(
        color: const Color(0xFFFAF8FF),
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: child,
        ),
      ),
      // Already logged in -> admin goes to the admin panel, customers to the
      // app, everybody else to onboarding.
      home: !AuthService.isLoggedIn
          ? const WelcomeScreen()
          : (AuthService.user.value?.isAdmin == true
              ? const AdminShell()
              : const MainShell()),
    );
  }
}
