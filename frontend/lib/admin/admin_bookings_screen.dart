import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_colors.dart';
import 'admin_dashboard_screen.dart' show BookingTile;
import 'admin_ui.dart';

/// All bookings with status filter, search, details and cancel.
class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  static const _filters = ['all', 'confirmed', 'completed', 'cancelled'];
  static const _limit = 30;

  final _search = TextEditingController();
  final List<Map<String, dynamic>> _items = [];
  String _status = 'all';
  String _q = '';
  int _total = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final r = await AdminApi.bookings(
        status: _status == 'all' ? null : _status,
        q: _q,
        limit: _limit,
        offset: reset ? 0 : _items.length,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(((r['items'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
        _total = (r['total'] as num?)?.toInt() ?? _items.length;
        _loading = false;
      });
    } on AdminApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _openDetail(Map<String, dynamic> b) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _BookingSheet(id: '${b['id']}'),
    );
    if (changed == true) _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('Bookings'),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) {
              _q = v.trim();
              _load(reset: true);
            },
            decoration: InputDecoration(
              hintText: 'Search ref, customer, facility',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (final f in _filters)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(f[0].toUpperCase() + f.substring(1)),
                  selected: _status == f,
                  onSelected: (_) {
                    _status = f;
                    _load(reset: true);
                  },
                ),
              ),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorState(message: _error!, onRetry: () => _load(reset: true))
                  : _items.isEmpty
                      ? const EmptyState(icon: Icons.calendar_month_outlined, text: 'No bookings found.')
                      : RefreshIndicator(
                          onRefresh: () => _load(reset: true),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                            itemCount: _items.length + (_items.length < _total ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i >= _items.length) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Center(child: OutlinedButton(onPressed: () => _load(), child: Text('Load more (${_items.length}/$_total)'))),
                                );
                              }
                              return BookingTile(b: _items[i], onTap: () => _openDetail(_items[i]));
                            },
                          ),
                        ),
        ),
      ]),
    );
  }
}

class _BookingSheet extends StatefulWidget {
  final String id;
  const _BookingSheet({required this.id});

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  Map<String, dynamic>? _b;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await AdminApi.booking(widget.id);
      if (mounted) setState(() => _b = b);
    } on AdminApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _cancel() async {
    final ok = await confirmDialog(context,
        title: 'Cancel booking',
        message: 'Cancel this booking? The slot becomes available again and a paid amount is refunded.',
        confirmLabel: 'Cancel booking',
        danger: true);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final done = await runAction(context, () => AdminApi.cancelBooking(widget.id), ok: 'Booking cancelled');
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) Navigator.pop(context, true);
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: AppColors.textSecondary))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final b = _b;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: _error != null
          ? Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: 8), TextButton(onPressed: _load, child: const Text('Retry'))])
          : b == null
              ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
              : SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${b['ref']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                      StatusChip('${b['status']}'.toUpperCase(), statusColor('${b['status']}')),
                    ]),
                    const SizedBox(height: 10),
                    _kv('Facility', '${(b['venue'] as Map?)?['name']}'),
                    _kv('Court', '${(b['court'] as Map?)?['name']} (${(b['court'] as Map?)?['sport']})'),
                    _kv('When', '${b['date']} • ${b['timeSlot']}'),
                    _kv('Duration', '${b['duration']}'),
                    _kv('Customer', '${(b['user'] as Map?)?['name']}'),
                    _kv('Contact', '${(b['user'] as Map?)?['phone']}\n${(b['user'] as Map?)?['email']}'),
                    _kv('Total', lkr(b['totalLkr'] as num?)),
                    _kv('Payment', '${b['paymentMethod']} • ${b['paymentStatus']}'),
                    if (b['pin'] != null) _kv('Entry PIN', '${b['pin']}'),
                    if (((b['players'] as List?) ?? []).isNotEmpty)
                      _kv('Players', ((b['players'] as List).map((p) => '${p['name']}${p['isHost'] == true ? ' (host)' : ''}')).join(', ')),
                    const SizedBox(height: 14),
                    if (b['status'] == 'confirmed')
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                          onPressed: _busy ? null : _cancel,
                          child: const Text('Cancel booking'),
                        ),
                      ),
                  ]),
                ),
    );
  }
}
