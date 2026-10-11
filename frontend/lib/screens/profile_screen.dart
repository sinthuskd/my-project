import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../flow/flow_ui.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../utils/format.dart';
import '../utils/routes.dart';
import 'login_screen.dart';

/// Profile tab. Everything shown here comes from the backend (/auth/me).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Show the cached profile immediately, then refresh from the server.
    AuthService.refreshProfile();
  }

  void _openLogin() => Navigator.of(context)
      .pushAndRemoveUntil(fadeRoute(const LoginScreen()), (r) => false);

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    _openLogin();
  }

  String _hours(double h) => h == h.roundToDouble()
      ? h.toStringAsFixed(0)
      : h.toStringAsFixed(1);

  List<Widget> _guest() => [
        H('You are browsing as a guest',
            'Log in to see your profile, bookings and wallet.'),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: kBlue,
                minimumSize: const Size.fromHeight(52)),
            onPressed: _openLogin,
            child: const Text('Log In or Register'),
          ),
        ),
      ];

  List<Widget> _signedIn(BuildContext c, AppUser u) => [
        H('${u.fullName}${u.phoneVerified ? ' ✔' : ''}',
            '${u.memberId} • ${u.tier} TIER • ${u.matchesPlayed} matches'),
        Cd([
          Kv('Matches', '${u.matchesPlayed}'),
          Kv('Court Time', '${_hours(u.courtTimeHours)}h'),
          Kv('LKR Saved', fmtCompact(u.savedLkr)),
          Kv('Fairplay', u.fairplay == null ? '—' : u.fairplay!.toStringAsFixed(1)),
        ]),
        H('Account'),
        Cd([
          Kv('Email', u.email),
          Kv('Mobile', fmtPhoneE164(u.phone)),
          Kv('Mobile status', u.phoneVerified ? 'Verified' : 'Not verified'),
          if (u.createdAt != null)
            Kv('Member since', fmtMonthYear(u.createdAt!.toLocal())),
        ]),
        H('Favorite Sports'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final s in u.sports) Pl(s, on: true)],
        ),
        const SizedBox(height: 12),
        Cd([
          const Text('Court Credit Balance'),
          Text(fmtLkr(u.walletBalance),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          Btn(c, 'Top Up', to: 25),
        ], c: const Color(0xFFDCE6FF)),
        ListTile(
          leading: const Icon(Icons.notifications_none),
          title: const Text('Notifications'),
          onTap: () => goScreen(c, 20),
        ),
        ListTile(
          leading: const Icon(Icons.support_agent),
          title: const Text('Help & Support'),
          onTap: () => goScreen(c, 18),
        ),
        if (kDebugMode) ...[
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('Floor Ops (staff) - demo'),
            onTap: () => goScreen(c, 28),
          ),
          ListTile(
            leading: const Icon(Icons.view_list),
            title: const Text('All 34 screens (gallery) - demo'),
            onTap: () => Navigator.push(c,
                MaterialPageRoute(builder: (_) => const ScreenGallery())),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _logout,
          child: const Text('Log Out of SportsBook'),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUser?>(
      valueListenable: AuthService.user,
      builder: (context, u, _) => Scr(
        'Profile',
        u == null ? _guest() : _signedIn(context, u),
        tab: 4,
      ),
    );
  }
}
