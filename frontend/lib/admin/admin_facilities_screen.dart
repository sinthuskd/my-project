import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_colors.dart';
import 'admin_facility_detail_screen.dart';
import 'admin_facility_form.dart';
import 'admin_ui.dart';

/// Facilities list: search, add, open one to manage its courts.
class AdminFacilitiesScreen extends StatefulWidget {
  const AdminFacilitiesScreen({super.key});

  @override
  State<AdminFacilitiesScreen> createState() => _AdminFacilitiesScreenState();
}

class _AdminFacilitiesScreenState extends State<AdminFacilitiesScreen> {
  final _search = TextEditingController();
  String _q = '';
  int _version = 0; // bump to reload

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AdminFacilityForm()));
    if (saved == true && mounted) setState(() => _version++);
  }

  Future<void> _open(Map<String, dynamic> v) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminFacilityDetailScreen(venueId: '${v['id']}')));
    if (mounted) setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('Facilities'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New facility'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => setState(() => _q = v.trim()),
            decoration: InputDecoration(
              hintText: 'Search facilities',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _q.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        setState(() => _q = '');
                      }),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: LoadView<List<Map<String, dynamic>>>(
            key: ValueKey('$_q#$_version'),
            load: () => AdminApi.venues(q: _q),
            builder: (context, list, reload) {
              if (list.isEmpty) {
                return ListView(children: const [
                  EmptyState(icon: Icons.stadium_outlined, text: 'No facilities yet.\nTap "New facility" to create the first one.'),
                ]);
              }
              return RefreshIndicator(
                onRefresh: reload,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final v = list[i];
                    final active = v['active'] == true;
                    return AdminCard(
                      onTap: () => _open(v),
                      child: Row(children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.stadium, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${v['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            Text('${v['area']}', style: const TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Text('${v['courtCount'] ?? 0} courts • ${v['upcomingSlots'] ?? 0} upcoming slots',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                          ]),
                        ),
                        StatusChip(active ? 'LIVE' : 'HIDDEN', active ? AppColors.success : AppColors.disabled),
                      ]),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
