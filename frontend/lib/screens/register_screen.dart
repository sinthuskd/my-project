import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../utils/routes.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_text_field.dart';
import '../widgets/login_link.dart';
import '../widgets/partner_footer.dart';
import '../widgets/pill_chip.dart';
import '../widgets/primary_button.dart';
import '../widgets/skip_pill.dart';
import '../widgets/social_row.dart';
import 'login_screen.dart';
import 'main_shell.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _agreed = false;
  bool _loading = false;
  final Set<String> _sports = {};

  static const _sportOptions = [
    ('🏸', 'Badminton'),
    ('🎾', 'Tennis'),
    ('🏀', 'Basketball'),
    ('🏓', 'Padel & TT'),
  ];

  int _strength(String p) {
    var s = 0;
    if (p.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) s++;
    if (RegExp(r'\d').hasMatch(p)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    return s;
  }

  void _msg(String t) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(t)));

  Future<void> _create() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    if (_sports.isEmpty) return _msg('Pick at least 1 favorite sport');
    if (!_agreed) return _msg('Please agree to the Terms and Venue Policies');
    setState(() => _loading = true);
    try {
      final challenge = await AuthService.register(
        fullName: _name.text.trim(),
        phone: _phone.text.replaceAll(' ', ''),
        email: _email.text.trim(),
        password: _password.text,
        sports: _sports.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => OtpScreen(challenge: challenge)));
    } on AuthException catch (e) {
      _msg(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goHome() => Navigator.of(context)
      .pushAndRemoveUntil(fadeRoute(const MainShell()), (r) => false);

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strength = _strength(_password.text);
    final strengthColors = [
      AppColors.dotInactive,
      AppColors.danger,
      AppColors.warning,
      AppColors.primary,
      AppColors.success,
    ];
    final strengthLabels = ['', 'Weak password', 'Fair password', 'Good password', 'Strong password'];

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
                          color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back),
                    ),
                  ),
                  const Spacer(),
                  SkipPill(onTap: _goHome),
                ],
              ),
              const SizedBox(height: 4),
              const PillChip(
                  text: 'STEP 1 OF 2',
                  dot: true,
                  bold: true,
                  foreground: AppColors.textDark,
                  fontSize: 12),
              const SizedBox(height: 16),
              const AppLogo(size: 76, icon: Icons.visibility),
              const SizedBox(height: 12),
              const PillChip(
                  text: 'ATHLETE REGISTRATION',
                  icon: Icons.bolt,
                  bold: true,
                  foreground: AppColors.primary,
                  fontSize: 12),
              const SizedBox(height: 12),
              const Text('Join SportsBook',
                  style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1)),
              const SizedBox(height: 8),
              const Text(
                'Instant access to verified Colombo courts & squad match splitting',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, height: 1.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(20),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        label: 'Full Name',
                        trailingLabel: 'REQUIRED',
                        hint: 'Your full name',
                        icon: Icons.person_outline,
                        controller: _name,
                        validator: (v) => (v == null || v.trim().length < 2)
                            ? 'Enter your full name'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        label: 'Mobile Number',
                        trailingLabel: 'SMS OTP',
                        hint: '77 123 4567',
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 14, right: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🇱🇰', style: TextStyle(fontSize: 18)),
                              SizedBox(width: 8),
                              Text('+94',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                            ],
                          ),
                        ),
                        validator: (v) {
                          final d = (v ?? '').replaceAll(' ', '');
                          return RegExp(r'^\d{9}$').hasMatch(d)
                              ? null
                              : 'Enter 9 digits, e.g. 771234567';
                        },
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        label: 'Email Address',
                        hint: 'name@example.com',
                        icon: Icons.mail_outline,
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch((v ?? '').trim())
                            ? null
                            : 'Enter a valid email',
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        label: 'Create Password',
                        hint: 'At least 8 characters',
                        icon: Icons.lock_outline,
                        controller: _password,
                        obscure: _obscure,
                        onChanged: (_) => setState(() {}),
                        suffix: IconButton(
                          icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.textSecondary),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                        validator: (v) => (v == null || v.length < 8)
                            ? 'Use at least 8 characters'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (strength > 0) ...[
                            Icon(Icons.circle,
                                size: 8, color: strengthColors[strength]),
                            const SizedBox(width: 6),
                            Text(strengthLabels[strength],
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: strengthColors[strength])),
                            if (strength == 4)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.check_circle,
                                    size: 16, color: AppColors.success),
                              ),
                          ],
                          const Spacer(),
                          for (var i = 0; i < 4; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.only(left: 6),
                              width: 28,
                              height: 4,
                              decoration: BoxDecoration(
                                color: i < strength
                                    ? strengthColors[strength]
                                    : AppColors.dotInactive,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Row(
                        children: [
                          Text('Favorite Sports',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          Spacer(),
                          Text('Pick at least 1',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _sportOptions.map((o) {
                          final on = _sports.contains(o.$2);
                          return GestureDetector(
                            onTap: () => setState(() =>
                                on ? _sports.remove(o.$2) : _sports.add(o.$2)),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 14),
                              decoration: BoxDecoration(
                                color: on ? AppColors.primary : AppColors.card,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('${o.$1} ${o.$2}',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: on
                                          ? Colors.white
                                          : AppColors.textDark)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () => setState(() => _agreed = !_agreed),
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color:
                                    _agreed ? AppColors.primary : AppColors.card,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                    color: _agreed
                                        ? AppColors.primary
                                        : AppColors.dotInactive,
                                    width: 1.5),
                              ),
                              child: _agreed
                                  ? const Icon(Icons.check,
                                      size: 18, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text.rich(
                                TextSpan(
                                  style: TextStyle(
                                      fontSize: 14,
                                      height: 1.4,
                                      color: AppColors.textSecondary),
                                  children: [
                                    TextSpan(text: 'I agree to the '),
                                    TextSpan(
                                        text: 'SportsBook Terms',
                                        style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700)),
                                    TextSpan(
                                        text:
                                            ' and Colombo Sports Authority Venue Policies.'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      PrimaryButton(
                          label:
                              _loading ? 'Please wait...' : 'Create Account',
                          icon: _loading ? null : Icons.arrow_forward,
                          onPressed: _create),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Row(
                children: [
                  Expanded(child: Divider(color: AppColors.chip)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text('OR REGISTER WITH',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.textSecondary)),
                  ),
                  Expanded(child: Divider(color: AppColors.chip)),
                ],
              ),
              const SizedBox(height: 16),
              const SocialRow(fill: Colors.white),
              const SizedBox(height: 22),
              LoginLink(
                  onTap: () => Navigator.of(context)
                      .pushReplacement(fadeRoute(const LoginScreen()))),
              const SizedBox(height: 22),
              const PartnerFooter(),
            ],
          ),
        ),
      ),
    );
  }
}
