import 'package:flutter/material.dart';
import '../flow/flow_ui.dart' show goScreen;
import '../models/court.dart' show formatLkr;
import '../models/my_booking.dart';
import '../services/auth_service.dart';
import '../services/catalog_api.dart';
import '../theme/app_colors.dart';
import '../utils/app_events.dart';
import '../utils/date_utils.dart';
import '../widgets/app_header.dart';

/// "Bookings" tab: the logged-in customer's real bookings (GET /bookings).
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  static const _tabs = ['Upcoming', 'Past & Cancelled'];
  int _tab = 0;
  List<MyBooking> _items = [];
  bool _loading = false;
  String? _error;
  String? _cancelling;

  @override
  void initState() {
    super.initState();
    dataVersion.addListener(_load);
    AuthService.user.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    dataVersion.removeListener(_load);
    AuthService.user.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (!AuthService.isLoggedIn) {
      if (mounted) setState(() => _items = []);
      return;
    }
    if (mounted) {
      setState(() {
        _loading = _items.isEmpty;
        _error = null;
      });
    }
    try {
      final r = await CatalogApi.myBookings(_tab == 0 ? 'upcoming' : 'past');
      if (!mounted) return;
      setState(() {
        _items = r;
        _loading = false;
      });
    } on CatalogException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _toast(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _cancel(MyBooking b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: Text(b.paymentStatus == 'paid'
            ? '${b.venueName} - ${b.courtName}\n${b.timeSlot}\n\nLKR ${formatLkr(b.totalLkr)} will be refunded to your wallet.'
            : '${b.venueName} - ${b.courtName}\n${b.timeSlot}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep it')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel booking',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _cancelling = b.id);
    try {
      await CatalogApi.cancelBooking(b.id);
      if (!mounted) return;
      _toast(b.paymentStatus == 'paid'
          ? 'Cancelled. Refund added to your wallet.'
          : 'Booking cancelled.');
      notifyDataChanged();
      AuthService.refreshProfile();
    } on CatalogException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _cancelling = null);
    }
  }

  Color _statusColor(String s) => s == 'confirmed'
      ? AppColors.success
      : (s == 'cancelled' ? AppColors.danger : AppColors.textMuted);

  String _dateLabel(String d) {
    final dt = DateTime.tryParse(d);
    return dt == null ? d : fullDate(dt);
  }

  Widget _card(MyBooking b) {
    final c = _statusColor(b.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(b.venueName,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(b.status.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800, color: c)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('${b.sport} • ${b.courtName}',
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(_dateLabel(b.date),
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.schedule, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('${b.timeSlot}  (${b.duration})',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text('${b.ref}  •  ${b.paymentLabel}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ),
              Text('LKR ${formatLkr(b.totalLkr)}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
            ],
          ),
          if (b.status == 'confirmed') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => goScreen(context, 17),
                    child: const Text('Match Pass'),
                  ),
                ),
                if (b.canCancel) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancelling == b.id ? null : () => _cancel(b),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger),
                      child: Text(_cancelling == b.id ? '...' : 'Cancel'),
                    ),
                  ),
                ],
              ],
            ),
            if (!b.canCancel)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Free cancellation ended (2 hours before start).',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = AuthService.isLoggedIn;
    Widget body;
    if (!loggedIn) {
      body = const Center(
          child: Text('Log in to see your bookings.',
              style: TextStyle(color: AppColors.textSecondary)));
    } else if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger)),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: _items.isEmpty
            ? ListView(children: [
                const SizedBox(height: 80),
                Center(
                    child: Text(
                        _tab == 0
                            ? 'No upcoming bookings yet.\nBook a court from the Courts tab.'
                            : 'Nothing here yet.',
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: AppColors.textSecondary))),
              ])
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [for (final b in _items) _card(b)],
              ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: 'My Bookings', showBack: false),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_tab == i) return;
                          setState(() {
                            _tab = i;
                            _items = [];
                          });
                          _load();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: _tab == i
                                  ? AppColors.primary
                                  : AppColors.chip,
                              borderRadius: BorderRadius.circular(22)),
                          child: Text(_tabs[i],
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _tab == i
                                      ? Colors.white
                                      : AppColors.textDark)),
                        ),
                      ),
                    ),
                    if (i == 0) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
