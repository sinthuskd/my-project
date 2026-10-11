import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_colors.dart';
import 'admin_ui.dart';

/// Sports list: add, change icon, delete.
class AdminSportsScreen extends StatefulWidget {
  const AdminSportsScreen({super.key});

  @override
  State<AdminSportsScreen> createState() => _AdminSportsScreenState();
}

class _AdminSportsScreenState extends State<AdminSportsScreen> {
  int _version = 0;

  Future<void> _edit({Map<String, dynamic>? sport}) async {
    final name = TextEditingController(text: sport == null ? '' : '${sport['name']}');
    final icon = TextEditingController(text: sport == null ? 'sports' : '${sport['icon']}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(sport == null ? 'Add sport' : 'Edit ${sport['name']}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 6),
          FormBox(label: 'Name', controller: name, enabled: sport == null, hint: 'e.g. Badminton'),
          FormBox(label: 'Icon', controller: icon, hint: 'Flutter icon name: sports_tennis, sports_basketball, sports_soccer, sports_cricket'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final ok = await runAction(
                c,
                () => sport == null ? AdminApi.createSport(name.text.trim(), icon.text.trim()) : AdminApi.updateSport('${sport['name']}', {'icon': icon.text.trim()}),
                ok: sport == null ? 'Sport added' : 'Sport updated',
              );
              if (ok && c.mounted) Navigator.pop(c, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
    icon.dispose();
    if (saved == true && mounted) setState(() => _version++);
  }

  Future<void> _delete(Map<String, dynamic> s) async {
    final ok = await confirmDialog(context,
        title: 'Delete sport', message: 'Delete "${s['name']}"? Sports that still have courts cannot be deleted.', confirmLabel: 'Delete', danger: true);
    if (!ok || !mounted) return;
    if (await runAction(context, () => AdminApi.deleteSport('${s['name']}'), ok: 'Sport deleted')) {
      setState(() => _version++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('Sports'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add sport'),
      ),
      body: LoadView<List<Map<String, dynamic>>>(
        key: ValueKey(_version),
        load: AdminApi.sports,
        builder: (context, list, reload) {
          if (list.isEmpty) {
            return ListView(children: const [EmptyState(icon: Icons.sports_tennis, text: 'No sports yet.\nAdd one, then create courts for it.')]);
          }
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final s = list[i];
                return AdminCard(
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${s['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        Text('icon: ${s['icon']} • ${s['courts'] ?? 0} courts', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ]),
                    ),
                    IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(sport: s)),
                    IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger), onPressed: () => _delete(s)),
                  ]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
