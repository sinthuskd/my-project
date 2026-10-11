import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bookable_slot.dart';
import '../models/court.dart' show formatLkr;
import '../models/my_booking.dart';
import '../services/auth_service.dart';
import '../services/catalog_api.dart';
import '../theme/app_colors.dart';
import '../utils/app_events.dart';
import '../utils/date_utils.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_action_bar.dart';
import '../widgets/primary_button.dart';
import 'wallet_screen.dart';

/// Customer picks one of the slots the ADMIN created for a court and books it.
///   GET  /courts/:id/slots?date=YYYY-MM-DD
///   POST /bookings  {slotId, paymentMethod}
class SlotBookingScreen extends StatefulWidget {
  final String courtId;
  final String courtName;
  final String? initialSlotId;
  final DateTime? initialDate;
  const SlotBookingScreen({
    super.key,
    required this.courtId,
    required this.courtName,
    this.initialSlotId,
    this.initialDate,
  });

  @override
  State<SlotBookingScreen> createState() => _SlotBookingScreenState();
}

class _SlotBookingScreenState extends State<SlotBookingScreen> {
  late final List<DateTime> _days =
      List.generate(7, (i) => DateTime.now().add(Duration(days: i)));
  int _dayIndex = 0;
  CourtSlots? _data;
  bool _loading = true;
  bool _booking = false;
  String? _error;
  String? _slotId;
  String _pay = 'wallet';

  bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    _slotId = widget.initialSlotId;
    if (widget.initialDate != null) {
      final i = _days.indexWhere((d) => _same(d, widget.initialDate!));
      if (i >= 0) _dayIndex = i;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await CatalogApi.courtSlots(widget.courtId, _days[_dayIndex]);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
        if (_slotId != null && !d.slots.any((s) => s.id == _slotId)) {
          _slotId = null;
        }
      });
    } on CatalogException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  BookableSlot? get _selected {
    final d = _data;
    if (d == null || _slotId == null) return null;
    for (final s in d.slots) {
      if (s.id == _slotId) return s;
    }
    return null;
  }

  void _toast(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  /// Wallet is too low -> offer a top-up (or pay at the venue instead).
  Future<void> _askTopUp(double balance, int price) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Not enough wallet balance'),
        content: Text(
            'This slot costs LKR ${formatLkr(price)} but your wallet has LKR ${formatLkr(balance.round())}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Top Up')),
        ],
      ),
    );
    if (go == true && mounted) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const WalletScreen()));
    }
  }

  Future<void> _book() async {
    final slot = _selected;
    if (slot == null) return _toast('Select a time slot first');
    if (!AuthService.isLoggedIn) return _toast('Please log in to book a slot');
    setState(() => _booking = true);
    try {
      var b = <String, dynamic>{};
      if (_pay == 'wallet') {
        // 1) enough money?
        final w = await CatalogApi.wallet();
        if (w.balance < slot.price) {
          if (!mounted) return;
          setState(() => _booking = false);
          await _askTopUp(w.balance, slot.price);
          return;
        }
        // 2) SMS code (payment OTP) -> 3) book
        var ch = await CatalogApi.requestPaymentOtp();
        while (true) {
          if (!mounted) return;
          final code = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (_) => _PaymentOtpDialog(challenge: ch, amount: slot.price),
          );
          if (!mounted) return;
          if (code == null) {
            setState(() => _booking = false);
            return; // user closed the dialog
          }
          try {
            b = await CatalogApi.createBooking(
                slotId: slot.id, paymentMethod: 'wallet', otp: code);
            break;
          } on CatalogException catch (e) {
            if (e.code == 'INVALID_OTP' || e.code == 'OTP_REQUIRED') {
              _toast(e.message);
              continue; // ask the code again
            }
            if (e.code == 'OTP_EXPIRED') {
              _toast(e.message);
              ch = await CatalogApi.requestPaymentOtp();
              continue;
            }
            rethrow;
          }
        }
      } else {
        b = await CatalogApi.createBooking(
            slotId: slot.id, paymentMethod: 'pay_at_venue');
      }
      if (!mounted) return;
      setState(() => _booking = false);
      notifyDataChanged(); // My Bookings + wallet reload
      AuthService.refreshProfile();
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Booking confirmed ✅'),
          content: Text(
              '${_data?.venueName ?? ''} - ${_data?.courtName ?? widget.courtName}\n'
              '${dayMonth(_days[_dayIndex])}, ${slot.time} - ${slot.endTime}\n'
              'LKR ${formatLkr(slot.price)}\n\n'
              'Ref: ${b['ref'] ?? ''}\n'
              'See it in the Bookings tab.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK')),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on CatalogException catch (e) {
      if (!mounted) return;
      setState(() => _booking = false);
      if (e.code == 'INSUFFICIENT_BALANCE') {
        await _askTopUp(0, slot.price);
        return;
      }
      _toast(e.message);
      if (e.status == 409 || e.status == 404) _load(); // slot just taken
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = _data?.slots ?? const <BookableSlot>[];
    final sel = _selected;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: 'Select Slot'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  Text(_data?.courtName ?? widget.courtName,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  if ((_data?.venueName ?? '').isNotEmpty)
                    Text(_data!.venueName,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 74,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _days.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final on = i == _dayIndex;
                        return GestureDetector(
                          onTap: () {
                            if (on) return;
                            setState(() {
                              _dayIndex = i;
                              _slotId = null;
                            });
                            _load();
                          },
                          child: Container(
                            width: 60,
                            decoration: BoxDecoration(
                              color: on ? AppColors.primary : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(i == 0 ? 'Today' : weekdayShort(_days[i]),
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: on
                                            ? Colors.white70
                                            : AppColors.textSecondary)),
                                Text('${_days[i].day}',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: on
                                            ? Colors.white
                                            : AppColors.textDark)),
                                Text(monthShort(_days[i]),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: on
                                            ? Colors.white70
                                            : AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Available Slots',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (_loading)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Center(child: CircularProgressIndicator()))
                  else if (_error != null)
                    Column(children: [
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.danger)),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ])
                  else if (slots.isEmpty)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('No open slots on this day.\nTry another date.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary)))
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final s in slots)
                          GestureDetector(
                            onTap: () => setState(() => _slotId = s.id),
                            child: Container(
                              width: 150,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: s.id == _slotId
                                    ? AppColors.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${s.time} - ${s.endTime}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: s.id == _slotId
                                              ? Colors.white
                                              : AppColors.textDark)),
                                  const SizedBox(height: 2),
                                  Text(s.durationLabel,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: s.id == _slotId
                                              ? Colors.white70
                                              : AppColors.textSecondary)),
                                  Text('LKR ${formatLkr(s.price)}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: s.id == _slotId
                                              ? Colors.white
                                              : AppColors.primary)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 22),
                  const Text('Payment',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    value: 'wallet',
                    groupValue: _pay,
                    onChanged: (v) => setState(() => _pay = v!),
                    title: const Text('SportsBook Wallet'),
                  ),
                  RadioListTile<String>(
                    value: 'pay_at_venue',
                    groupValue: _pay,
                    onChanged: (v) => setState(() => _pay = v!),
                    title: const Text('Pay at venue'),
                  ),
                ],
              ),
            ),
            BottomActionBar(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('TOTAL',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textSecondary)),
                        Text(sel == null ? '—' : 'LKR ${formatLkr(sel.price)}',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    child: PrimaryButton(
                      label: _booking ? 'Booking...' : 'Confirm Booking',
                      onPressed: _booking ? () {} : _book,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks for the 6-digit code that was sent to the customer's mobile before a wallet payment.
class _PaymentOtpDialog extends StatefulWidget {
  final PaymentOtp challenge;
  final int amount;
  const _PaymentOtpDialog({required this.challenge, required this.amount});

  @override
  State<_PaymentOtpDialog> createState() => _PaymentOtpDialogState();
}

class _PaymentOtpDialogState extends State<_PaymentOtpDialog> {
  final _code = TextEditingController();
  late PaymentOtp _ch = widget.challenge;
  Timer? _timer;
  late int _left = _ch.resendInSeconds;
  bool _sending = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left > 0 && mounted) setState(() => _left--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    setState(() {
      _sending = true;
      _msg = null;
    });
    try {
      final c = await CatalogApi.requestPaymentOtp();
      if (!mounted) return;
      setState(() {
        _ch = c;
        _left = c.resendInSeconds;
        _sending = false;
        _msg = 'New code sent';
      });
    } on CatalogException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _msg = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'Enter the 6-digit code sent to your mobile to pay LKR ${formatLkr(widget.amount)} from your wallet.'),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 6),
            decoration: const InputDecoration(counterText: ''),
            onChanged: (_) => setState(() {}),
          ),
          if (_ch.devOtp != null)
            TextButton(
              onPressed: () => setState(() => _code.text = _ch.devOtp!),
              child: Text('Dev mode code: ${_ch.devOtp}  (tap to fill)'),
            ),
          if (_msg != null)
            Text(_msg!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: (_left > 0 || _sending) ? null : _resend,
              child: Text(_left > 0 ? 'Resend code in ${_left}s' : 'Resend code'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _code.text.trim().length == 6
              ? () => Navigator.pop(context, _code.text.trim())
              : null,
          child: const Text('Verify & Pay'),
        ),
      ],
    );
  }
}
