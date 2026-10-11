import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_colors.dart';
import 'admin_court_form.dart';
import 'admin_facility_form.dart';
import 'admin_slots_screen.dart';
import 'admin_ui.dart';

/// One facility: details, edit / delete, and its courts (add / edit / delete / manage slots).
class AdminFacilityDetailScreen extends StatefulWidget {
  final String venueId;
  const AdminFacilityDetailScreen({super.key, required this.venueId});

  @override
  State<AdminFacilityDetailScreen> createState() => _AdminFacilityDetailScreenState();
}

class _AdminFacilityDetailScreenState extends State<AdminFacilityDetailScreen> {
  int _version = 0;

  void _refresh() => setState(() => _version++);

  Future<void> _edit(Map<String, dynamic> v) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AdminFacilityForm(venue: v)));
    if (saved == true) _refresh();
  }

  Future<void> _delete(Map<String, dynamic> v) async {
    final ok = await confirmDialog(context,
        title: 'Delete facility',
        message: 'Delete "${v['name']}" with all its courts and slots? This cannot be undone.',
        confirmLabel: 'Delete',
        danger: true);
    if (!ok || !mounted) return;
    final done = await runAction(context, () => AdminApi.deleteVenue('${v['id']}'), ok: 'Facility deleted');
    if (done && mounted) Navigator.pop(context);
  }

  Future<void> _addCourt() async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AdminCourtForm(venueId: widget.venueId)));
    if (saved == true) _refresh();
  }

  Future<void> _editCourt(Map<String, dynamic> c) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AdminCourtForm(venueId: widget.venueId, court: c)));
    if (saved == true) _refresh();
  }

  Future<void> _deleteCourt(Map<String, dynamic> c) async {
    final ok = await confirmDialog(context,
        title: 'Delete court', message: 'Delete "${c['name']}" and its slots?', confirmLabel: 'Delete', danger: true);
    if (!ok || !mounted) return;
    if (await runAction(context, () => AdminApi.deleteCourt('${c['id']}'), ok: 'Court deleted')) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return LoadView<Map<String, dynamic>>(
      key: ValueKey(_version),
      stateAppBar: adminAppBar('Facility'),
      load: () => AdminApi.venue(widget.venueId),
      builder: (context, v, reload) {
        final courts = ((v['courts'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final active = v['active'] == true;
        Widget info(String k, String val) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 100, child: Text(k, style: const TextStyle(color: AppColors.textSecondary))),
                Expanded(child: Text(val, style: const TextStyle(fontWeight: FontWeight.w600))),
              ]),
            );
        return Scaffold(
          appBar: adminAppBar('${v['name']}', actions: [
            IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Edit', onPressed: () => _edit(v)),
            IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger), tooltip: 'Delete', onPressed: () => _delete(v)),
          ]),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _addCourt,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Add court'),
          ),
          body: RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 90), children: [
              AdminCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Expanded(child: Text('Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                    StatusChip(active ? 'LIVE' : 'HIDDEN', active ? AppColors.success : AppColors.disabled),
                  ]),
                  const SizedBox(height: 6),
                  info('Area', '${v['area']}'),
                  info('Address', '${v['address']}'),
                  info('Hours', '${v['openHour']}:00 - ${v['closeHour']}:00'),
                  info('Gate', '${v['gate']}'),
                  info('Surface', '${v['surfaceLabel']}'),
                  if (((v['facilities'] as List?) ?? []).isNotEmpty) info('Filters', ((v['facilities'] as List).join(', '))),
                ]),
              ),
              SectionTitle('Courts (${courts.length})'),
              if (courts.isEmpty)
                const EmptyState(icon: Icons.sports_tennis, text: 'No courts yet.\nAdd a court, then create its slots.')
              else
                for (final c in courts)
                  AdminCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('${c['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                        StatusChip(c['active'] == true ? 'LIVE' : 'HIDDEN', c['active'] == true ? AppColors.success : AppColors.disabled),
                      ]),
                      const SizedBox(height: 2),
                      Text('${c['sport']} • ${c['environment']} • ${lkr(c['price'] as num?)}/hour',
                          style: const TextStyle(color: AppColors.textSecondary)),
                      Text('${c['upcomingSlots'] ?? 0} upcoming slots', style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, children: [
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminSlotsScreen(initialCourtId: '${c['id']}', standalone: true))),
                          icon: const Icon(Icons.schedule, size: 18),
                          label: const Text('Slots'),
                        ),
                        OutlinedButton.icon(onPressed: () => _editCourt(c), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit')),
                        OutlinedButton.icon(
                          onPressed: () => _deleteCourt(c),
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Delete'),
                        ),
                      ]),
                    ]),
                  ),
            ]),
          ),
        );
      },
    );
  }
}
