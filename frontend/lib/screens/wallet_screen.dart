import 'package:flutter/material.dart';
import '../models/court.dart' show formatLkr;
import '../models/my_booking.dart';
import '../services/auth_service.dart';
import '../services/catalog_api.dart';
import '../theme/app_colors.dart';
import '../utils/app_events.dart';
import '../utils/date_utils.dart';
import '../widgets/app_header.dart';
import '../widgets/primary_button.dart';

/// Wallet Top-Up: balance, top-up (POST /wallet/topup) and history (GET /wallet).
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  static const _amounts = [1000, 2500, 5000, 10000];
  final _custom = TextEditingController();
  WalletInfo? _wallet;
  int? _amount = 2500;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _wallet == null;
      _error = null;
    });
    try {
      final w = await CatalogApi.wallet();
      if (!mounted) return;
      setState(() {
        _wallet = w;
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

  Future<void> _topUp() async {
    final amount = _custom.text.trim().isNotEmpty
        ? int.tryParse(_custom.text.trim())
        : _amount;
    if (amount == null || amount < 100 || amount > 100000) {
      return _toast('Enter an amount between LKR 100 and LKR 100,000');
    }
    setState(() => _busy = true);
    try {
      final w = await CatalogApi.topUp(amount);
      if (!mounted) return;
      setState(() {
        _wallet = w;
        _busy = false;
        _custom.clear();
      });
      _toast('LKR ${formatLkr(amount)} added to your wallet');
      notifyDataChanged();
      AuthService.refreshProfile();
    } on CatalogException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.status == 403
          ? 'Top-up is off. Set ALLOW_DEV_TOPUP=true in backend/.env and restart the backend.'
          : e.message);
    }
  }

  IconData _icon(String kind) => kind == 'topup'
      ? Icons.add_card
      : (kind == 'refund' ? Icons.undo : Icons.sports_tennis);

  @override
  Widget build(BuildContext context) {
    final w = _wallet;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: 'Wallet Top-Up'),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: AppColors.danger)),
                                TextButton(
                                    onPressed: _load,
                                    child: const Text('Retry')),
                              ]),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFDCE6FF),
                                    borderRadius: BorderRadius.circular(22)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('ACTIVE SPORTSBOOK CREDIT',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textSecondary)),
                                    const SizedBox(height: 4),
                                    Text(
                                        'LKR ${formatLkr((w?.balance ?? 0).round())}',
                                        style: const TextStyle(
                                            fontSize: 30,
                                            fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text('Select Top-Up Amount',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  for (final a in _amounts)
                                    ChoiceChip(
                                      label: Text('LKR ${formatLkr(a)}'),
                                      selected: _amount == a &&
                                          _custom.text.trim().isEmpty,
                                      onSelected: (_) => setState(() {
                                        _amount = a;
                                        _custom.clear();
                                      }),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _custom,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'Custom amount (LKR)',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              PrimaryButton(
                                label: _busy ? 'Please wait...' : 'Top Up Now',
                                onPressed: _busy ? () {} : _topUp,
                              ),
                              const SizedBox(height: 22),
                              const Text('History',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              if (w == null || w.transactions.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Text('No transactions yet.',
                                      style: TextStyle(
                                          color: AppColors.textSecondary)),
                                )
                              else
                                for (final t in w.transactions)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                        backgroundColor: AppColors.chip,
                                        child: Icon(_icon(t.kind),
                                            color: AppColors.primary,
                                            size: 20)),
                                    title: Text(t.note.isEmpty ? t.kind : t.note,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    subtitle: t.createdAt == null
                                        ? null
                                        : Text(dayMonth(t.createdAt!)),
                                    trailing: Text(
                                        '${t.amount >= 0 ? '+' : '-'} LKR ${formatLkr(t.amount.abs().round())}',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: t.amount >= 0
                                                ? AppColors.success
                                                : AppColors.danger)),
                                  ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
