import 'package:flutter/material.dart';
import '../admin/admin_shell.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../utils/routes.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_text_field.dart';
import '../widgets/partner_footer.dart';
import '../widgets/pill_chip.dart';
import '../widgets/primary_button.dart';
import '../widgets/skip_pill.dart';
import '../widgets/social_row.dart';
import 'main_shell.dart';
import 'otp_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  void _goHome() => Navigator.of(context)
      .pushAndRemoveUntil(fadeRoute(const MainShell()), (r) => false);

  Future<void> _login() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.login(
        identifier: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      // Same login screen for everybody: admins land on the admin panel.
      if (AuthService.user.value?.isAdmin == true) {
        Navigator.of(context).pushAndRemoveUntil(
            fadeRoute(const AdminShell()), (r) => false);
      } else {
        _goHome();
      }
    } on NotVerifiedException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please verify your mobile number to continue')));
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => OtpScreen(challenge: e.challenge)));
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
              Align(
                  alignment: Alignment.centerRight,
                  child: SkipPill(onTap: _goHome)),
              const SizedBox(height: 4),
              const AppLogo(),
              const SizedBox(height: 14),
              const PillChip(
                  text: 'FAST-COURT PASS',
                  dot: true,
                  bold: true,
                  foreground: AppColors.primary,
                  fontSize: 12),
              const SizedBox(height: 12),
              const Text('SportsBook',
                  style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1)),
              const SizedBox(height: 2),
              const Text('Instant courts, zero friction.',
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              const SizedBox(height: 10),
              const Text(
                'Sign in to access your booked courts and instant reservations.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, height: 1.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.07),
                        blurRadius: 30,
                        offset: const Offset(0, 10)),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      AppTextField(
                        label: 'Username or Email',
                        hint: 'Email or mobile number',
                        icon: Icons.person_outline,
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter your username or email'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Password',
                        hint: 'Enter your password',
                        icon: Icons.lock_outline,
                        controller: _password,
                        obscure: _obscure,
                        suffix: IconButton(
                          icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.textSecondary),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Enter your password'
                            : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                                  content: Text('Password reset coming soon'))),
                          child: const Text('Forgot Password?',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
                        ),
                      ),
                      PrimaryButton(
                          label: _loading ? 'Please wait...' : 'Log In',
                          icon: _loading ? null : Icons.arrow_forward,
                          onPressed: _login),
                      const SizedBox(height: 20),
                      const Row(
                        children: [
                          Expanded(child: Divider(color: AppColors.chip)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('Or connect with',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14)),
                          ),
                          Expanded(child: Divider(color: AppColors.chip)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const SocialRow(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? ",
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 15)),
                  GestureDetector(
                    onTap: () => Navigator.of(context)
                        .pushReplacement(fadeRoute(const RegisterScreen())),
                    child: const Text('Register Now',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline)),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const PartnerFooter(),
            ],
          ),
        ),
      ),
    );
  }
}
