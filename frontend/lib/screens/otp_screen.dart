import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../utils/routes.dart';
import '../widgets/pill_chip.dart';
import '../widgets/primary_button.dart';
import 'location_permission_screen.dart';

/// Step 2 of registration: user types the 6-digit SMS code.
/// On success the backend logs the user in and we continue into the app.
class OtpScreen extends StatefulWidget {
  final OtpChallenge challenge;
  const OtpScreen({super.key, required this.challenge});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;

  late int _expiresIn;
  late int _resendIn;
  String? _devOtp;
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _expiresIn = widget.challenge.expiresInSeconds;
    _resendIn = widget.challenge.resendInSeconds;
    _devOtp = widget.challenge.devOtp;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_expiresIn > 0) _expiresIn--;
        if (_resendIn > 0) _resendIn--;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _mmss(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Future<void> _verify() async {
    if (_verifying) return;
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await AuthService.verifyOtp(phone: widget.challenge.phone, code: code);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
          fadeRoute(const LocationPermissionScreen()), (r) => false);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      _code.clear();
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resending || _resendIn > 0) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final ch = await AuthService.resendOtp(widget.challenge.phone);
      if (!mounted) return;
      setState(() {
        _expiresIn = ch.expiresInSeconds;
        _resendIn = ch.resendInSeconds;
        _devOtp = ch.devOtp;
        _code.clear();
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('New code sent')));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        final ra = e.data['retryAfter'];
        if (ra is num) _resendIn = ra.toInt();
      });
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Widget _box(String ch, bool active) {
    final border = _error != null
        ? AppColors.danger
        : (active ? AppColors.primary : Colors.transparent);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1.6),
          ),
          child: Text(ch,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = _code.text;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 16),
              const PillChip(
                  text: 'STEP 2 OF 2 • VERIFICATION',
                  dot: true,
                  bold: true,
                  foreground: AppColors.textDark,
                  fontSize: 12),
              const SizedBox(height: 16),
              const Text('Verify Phone Number',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8)),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit code sent via SMS to +94 ${fmtNational(widget.challenge.phone)}',
                style: const TextStyle(
                    fontSize: 15, height: 1.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: Stack(
                  children: [
                    Row(
                      children: [
                        for (var i = 0; i < 6; i++)
                          _box(i < text.length ? text[i] : '',
                              i == text.length),
                      ],
                    ),
                    // Invisible field on top: it receives the typing.
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0,
                        child: TextField(
                          controller: _code,
                          focusNode: _focus,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration:
                              const InputDecoration(border: InputBorder.none),
                          onChanged: (v) {
                            setState(() => _error = null);
                            if (v.length == 6) _verify();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.danger, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _expiresIn > 0
                          ? 'Code expires in ${_mmss(_expiresIn)}'
                          : 'Code expired. Request a new one.',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ),
                  TextButton(
                    onPressed: (_resendIn > 0 || _resending) ? null : _resend,
                    child: Text(
                        _resendIn > 0 ? 'Resend in ${_resendIn}s' : 'Resend code',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              if (_devOtp != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.chip,
                      borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      const Icon(Icons.developer_mode,
                          color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Dev mode: your code is $_devOtp',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      TextButton(
                        onPressed: () {
                          _code.text = _devOtp!;
                          setState(() => _error = null);
                          _verify();
                        },
                        child: const Text('Autofill'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              PrimaryButton(
                label: _verifying ? 'Verifying...' : 'Verify & Activate Account',
                icon: _verifying ? null : Icons.arrow_forward,
                onPressed: _verify,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
