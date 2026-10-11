import 'dart:async';
import '../services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/match_pass.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import '../widgets/app_header.dart';
import '../widgets/fake_qr.dart';
import '../widgets/section_card.dart';

class DigitalMatchPassScreen extends StatefulWidget {
  const DigitalMatchPassScreen({super.key});

  @override
  State<DigitalMatchPassScreen> createState() => _DigitalMatchPassScreenState();
}

class _DigitalMatchPassScreenState extends State<DigitalMatchPassScreen> {
  static const _refreshEvery = 30;
  late final MatchPass _p = MatchPass.empty.withUser(AuthService.user.value);
  int _left = _refreshEvery;
  int _token = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (_left <= 1) {
          _left = _refreshEvery;
          _token++; // new QR every 30s. Real token comes from NestJS.
        } else {
          _left--;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toast(String t) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(t)));

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    if (_p.bookingRef.isEmpty) {
      // No pass loaded yet (real pass comes from GET /match-pass).
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const AppHeader(title: 'Digital Match Pass'),
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                        'No upcoming booking yet.\nYour Match Pass will appear here after you book a court.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 16, color: AppColors.textSecondary)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Digital Match Pass',
              subtitle: null,
              actions: [
                IconButton(
                    onPressed: () => _toast('Pass shared (demo)'),
                    icon: const Icon(Icons.share_outlined)),
                IconButton(
                    onPressed: () => _toast('More options'),
                    icon: const Icon(Icons.more_vert)),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  _tokenBar(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 10, 8, 16),
                    child: Row(
                      children: [
                        Icon(Icons.wb_sunny_outlined,
                            size: 20, color: AppColors.primary),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              'Turn up screen brightness at Gate B turnstile scanner.',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                  ),
                  _ticket(today),
                  const SizedBox(height: 16),
                  _checklist(),
                  _roster(),
                  _navigate(),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _toast('Calling Arena Desk (demo)'),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.headset_mic_outlined,
                            size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                              'Need entry help? Call Arena Desk (Maitland Place)',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text('COLOMBO SPORTS AUTHORITY\nPARTNER',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted)),
                      Text('KINETIC ACCESS\nV2.4',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tokenBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: AppColors.chip, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 10, color: AppColors.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('LIVE SECURITY TOKEN',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.primary)),
          ),
          const Text('REFRESHES IN ',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary)),
          Text('${_left}s',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _left <= 5 ? AppColors.danger : AppColors.primary)),
        ],
      ),
    );
  }

  Widget _ticket(DateTime today) {
    Widget label(String t) => Text(t,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppColors.textSecondary));
    Widget cell(String l, Widget v, [Widget? sub]) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label(l),
              const SizedBox(height: 4),
              v,
              if (sub != null) sub,
            ],
          ),
        );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 26,
              offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        children: [
          // Blue header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('OFFICIAL MATCH PASS',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                              color: Colors.white70)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_outlined,
                              size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Verified',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(_p.arena,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(_p.address,
                        style: const TextStyle(
                            fontSize: 15, color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SPORT & COURT',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: Colors.white70)),
                          Text(_p.sport,
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          Text(_p.surface,
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.white70)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('BOOKING REF',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: Colors.white70)),
                        Text(_p.bookingRef,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                                color: Colors.white)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Details
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    cell('DATE',
                        Text(fullDate(today),
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700))),
                    cell(
                        'TIME SLOT',
                        Text(_p.timeSlot,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary)),
                        Text(_p.duration,
                            style: const TextStyle(
                                color: AppColors.textSecondary))),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    cell('TURNSTILE GATE',
                        Text(_p.gate,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700))),
                    cell(
                        'LEAD HOST',
                        Text(_p.host,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                        Text('${_p.playersConfirmed} Players Confirmed',
                            style: const TextStyle(
                                color: AppColors.primary))),
                  ],
                ),
              ],
            ),
          ),
          // Tear line with notches
          SizedBox(
            height: 28,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: Container(color: Colors.white)),
                Positioned(
                  left: -14,
                  top: 0,
                  child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                          color: AppColors.background,
                          shape: BoxShape.circle)),
                ),
                Positioned(
                  right: -14,
                  top: 0,
                  child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                          color: AppColors.background,
                          shape: BoxShape.circle)),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: LayoutBuilder(builder: (_, c) {
                      final n = (c.maxWidth / 12).floor();
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                            n,
                            (_) => Container(
                                width: 6,
                                height: 1.5,
                                color: AppColors.dotInactive)),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          // QR
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.textDark.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: FakeQr(key: ValueKey(_token), seed: _token, size: 200),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _p.pin));
                    _toast('PIN copied');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                        color: AppColors.chip,
                        borderRadius: BorderRadius.circular(26)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('MANUAL TURNSTILE PIN:',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: AppColors.textSecondary)),
                        const SizedBox(width: 10),
                        Text(_p.pin,
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3)),
                        const SizedBox(width: 10),
                        const Icon(Icons.copy_outlined,
                            size: 20, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                    'Hold QR code 10cm above turnstile scanner at Gate B, or show code to court marshal.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: AppColors.chip,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(26)),
            ),
            child: Row(
              children: [
                const Icon(Icons.sports_tennis,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Kinetic Turnstile Pass',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                Text('SESSION ${_p.session}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _checklist() {
    Widget item(IconData icon, String title, List<InlineSpan> body) =>
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.card, borderRadius: BorderRadius.circular(18)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text.rich(TextSpan(
                        style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: AppColors.textSecondary),
                        children: body)),
                  ],
                ),
              ),
            ],
          ),
        );
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: AppColors.chip,
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.checklist, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Court Access Checklist',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    Text('Requirements for seamless venue entry',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          item(Icons.check_circle_outline, 'Non-marking footwear mandatory', [
            const TextSpan(
                text:
                    'Parquet courts require clean indoor rubber gum soles.'),
          ]),
          item(Icons.lock_open_outlined, 'Lockers ${_p.lockers} Assigned', [
            const TextSpan(
                text: 'Electronic keyless access code matches your Entry PIN ('),
            TextSpan(
                text: _p.pin,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: AppColors.primary)),
            const TextSpan(text: ').'),
          ]),
          item(Icons.water_drop_outlined, 'Hydration & Towels Included', [
            const TextSpan(
                text:
                    'Collect 2x microfibre towels & electrolyte refills at reception desk.'),
          ]),
        ],
      ),
    );
  }

  Widget _roster() {
    final ready = _p.roster.where((r) => r.ready).length;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_outlined,
                  size: 22, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Roster Invites ($ready of ${_p.roster.length} Ready)',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              CardTag(ready == _p.roster.length ? 'Full Court' : 'Waiting',
                  pill: true),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _p.roster.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final r = _p.roster[i];
                return Container(
                  padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
                  decoration: BoxDecoration(
                      color: r.isYou ? AppColors.chip : AppColors.card,
                      borderRadius: BorderRadius.circular(26)),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: r.ready
                                ? AppColors.primary
                                : AppColors.disabled,
                            shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(r.initials,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                      const SizedBox(width: 8),
                      Text(r.name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => _toast('Match Pass sent to team WhatsApp (demo)'),
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                  color: AppColors.chip,
                  borderRadius: BorderRadius.circular(18)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.share_outlined,
                      size: 20, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Dispatch Match Pass to Team WhatsApp',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navigate() {
    return SectionCard(
      padding: const EdgeInsets.all(14),
      child: GestureDetector(
        onTap: () => _toast('Opening navigation (demo)'),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: AppColors.chip,
                  borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.navigation_outlined,
                  color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Navigate to Arena Turnstiles',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  Text('0.8 km • 4 min drive via Maitland Crescent',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
