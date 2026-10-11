import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_colors.dart';
import 'admin_ui.dart';

/// Registered customers (read-only) with search.
class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({super.key});

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  static const _limit = 30;
  final _search = TextEditingController();
  final List<Map<String, dynamic>> _items = [];
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
      final r = await AdminApi.users(q: _q, limit: _limit, offset: reset ? 0 : _items.length);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('Customers ($_total)'),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) {
              _q = v.trim();
              _load(reset: true);
            },
            decoration: InputDecoration(
              hintText: 'Search name, email, phone',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorState(message: _error!, onRetry: () => _load(reset: true))
                  : _items.isEmpty
                      ? const EmptyState(icon: Icons.people_outline, text: 'No customers found.')
                      : RefreshIndicator(
                          onRefresh: () => _load(reset: true),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: _items.length + (_items.length < _total ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i >= _items.length) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Center(child: OutlinedButton(onPressed: () => _load(), child: Text('Load more (${_items.length}/$_total)'))),
                                );
                              }
                              final c = _items[i];
                              final name = '${c['fullName']}';
                              return AdminCard(
                                child: Row(children: [
                                  CircleAvatar(backgroundColor: AppColors.chip, child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800))),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                      Text('${c['email']}\n${c['phone']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                    ]),
                                  ),
                                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    Text('${c['bookings'] ?? 0} bookings', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                    Text(lkr(c['walletBalance'] as num?), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                  ]),
                                ]),
                              );
                            },
                          ),
                        ),
        ),
      ]),
    );
  }
}
