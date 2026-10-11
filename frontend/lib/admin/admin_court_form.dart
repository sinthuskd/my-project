import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_colors.dart';
import 'admin_ui.dart';

/// Create (court == null) or edit a court of [venueId]. Pops `true` when saved.
class AdminCourtForm extends StatefulWidget {
  final String venueId;
  final Map<String, dynamic>? court;
  const AdminCourtForm({super.key, required this.venueId, this.court});

  @override
  State<AdminCourtForm> createState() => _AdminCourtFormState();
}

class _AdminCourtFormState extends State<AdminCourtForm> {
  final _key = GlobalKey<FormState>();
  late final Map<String, dynamic> c = widget.court ?? {};
  bool _busy = false;
  List<String>? _sports;
  String? _loadError;

  String? _sport;
  String _environment = 'indoor';
  bool _topPick = false, _instantLock = false, _active = true;

  late final _name = TextEditingController(text: '${c['name'] ?? ''}');
  late final _price = TextEditingController(text: c['price']?.toString() ?? '');
  late final _surface = TextEditingController(text: '${c['surface'] ?? ''}');
  late final _tag = TextEditingController(text: '${c['tag'] ?? ''}');
  late final _listingTag = TextEditingController(text: '${c['listingTag'] ?? ''}');
  late final _certified = TextEditingController(text: '${c['certified'] ?? ''}');
  late final _description = TextEditingController(text: '${c['description'] ?? ''}');
  late final _image = TextEditingController(text: '${c['imageAsset'] ?? ''}');
  late final _tags = TextEditingController(
      text: ((c['amenityTags'] as List?) ?? []).map((t) => '${t['icon']} | ${t['label']}').join('\n'));

  @override
  void initState() {
    super.initState();
    _sport = c['sport']?.toString();
    _environment = (c['environment'] ?? 'indoor').toString();
    _topPick = c['topPick'] == true;
    _instantLock = c['instantLock'] == true;
    _active = c['active'] != false;
    _loadSports();
  }

  Future<void> _loadSports() async {
    try {
      final s = await AdminApi.sports();
      if (!mounted) return;
      setState(() {
        _sports = s.map((e) => '${e['name']}').toList();
        _sport ??= _sports!.isNotEmpty ? _sports!.first : null;
        if (_sport != null && !_sports!.contains(_sport)) _sports!.add(_sport!);
      });
    } on AdminApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    }
  }

  @override
  void dispose() {
    for (final x in [_name, _price, _surface, _tag, _listingTag, _certified, _description, _image, _tags]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    if (_sport == null) {
      toast(context, 'Create a sport first (More > Sports).', error: true);
      return;
    }
    final tags = splitLines(_tags.text).map((l) {
      final p = l.split('|').map((x) => x.trim()).toList();
      return {'icon': p[0].isNotEmpty ? p[0] : 'check', 'label': p.length > 1 ? p[1] : ''};
    }).where((t) => t['label']!.isNotEmpty).toList();
    final editing = widget.court != null;
    final body = <String, dynamic>{
      'sport': _sport,
      'name': _name.text.trim(),
      'price': int.parse(_price.text.trim()),
      'surface': _surface.text.trim(),
      'environment': _environment,
      'tag': _tag.text.trim(),
      'listingTag': _listingTag.text.trim().isEmpty ? null : _listingTag.text.trim(),
      'description': _description.text.trim(),
      'certified': _certified.text.trim().isEmpty ? null : _certified.text.trim(),
      'amenityTags': tags,
      'topPick': _topPick,
      'instantLock': _instantLock,
      'active': _active,
    };
    // empty image = use the facility's main image
    if (_image.text.trim().isNotEmpty) {
      body['imageAsset'] = _image.text.trim();
    } else if (!editing) {
      body['imageAsset'] = null;
    }
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => editing ? AdminApi.updateCourt('${c['id']}', body) : AdminApi.createCourt(widget.venueId, body),
      ok: editing ? 'Court updated' : 'Court created',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.court != null;
    final sports = _sports;
    return Scaffold(
      appBar: adminAppBar(editing ? 'Edit court' : 'New court'),
      body: _loadError != null
          ? ErrorState(message: _loadError!, onRetry: () {
              setState(() => _loadError = null);
              _loadSports();
            })
          : sports == null
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _key,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
                    if (sports.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text('Create a sport first (More > Sports), then add courts.', style: TextStyle(color: AppColors.danger)),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: DropdownButtonFormField<String>(
                        value: _sport,
                        decoration: InputDecoration(
                          labelText: 'Sport *',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        items: [for (final s in sports) DropdownMenuItem(value: s, child: Text(s))],
                        onChanged: (x) => setState(() => _sport = x),
                      ),
                    ),
                    FormBox(label: 'Court name *', controller: _name, hint: 'e.g. Court 1', validator: requiredField),
                    FormBox(
                        label: 'Hourly price (LKR) *',
                        controller: _price,
                        hint: 'Default price for new slots',
                        keyboard: TextInputType.number,
                        validator: (s) => int.tryParse((s ?? '').trim()) == null ? 'Whole number' : null),
                    FormBox(label: 'Surface', controller: _surface, hint: 'e.g. Wooden Parquet, Synthetic Mat'),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: DropdownButtonFormField<String>(
                        value: _environment,
                        decoration: InputDecoration(
                          labelText: 'Environment',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'indoor', child: Text('Indoor')),
                          DropdownMenuItem(value: 'outdoor', child: Text('Outdoor')),
                          DropdownMenuItem(value: 'rooftop', child: Text('Rooftop')),
                        ],
                        onChanged: (x) => setState(() => _environment = x ?? 'indoor'),
                      ),
                    ),
                    FormBox(label: 'Label on venue page', controller: _tag, hint: 'e.g. BWF Approved'),
                    FormBox(label: 'Search card chip', controller: _listingTag, hint: 'e.g. WOODEN PARQUET'),
                    FormBox(label: 'Certified badge', controller: _certified, hint: 'e.g. BWF CERTIFIED MAT'),
                    FormBox(label: 'Description', controller: _description, maxLines: 3),
                    FormBox(label: 'Court image', controller: _image, hint: 'Optional URL / asset path. Empty = the facility\'s main image'),
                    FormBox(label: 'Search card amenities', controller: _tags, hint: 'One per line: icon | label\ne.g. ac_unit | Air Conditioned', maxLines: 3),
                    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Top pick'), value: _topPick, onChanged: (x) => setState(() => _topPick = x)),
                    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Instant lock'), value: _instantLock, onChanged: (x) => setState(() => _instantLock = x)),
                    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Visible to customers'), value: _active, onChanged: (x) => setState(() => _active = x)),
                    const SizedBox(height: 10),
                    SaveButton(label: editing ? 'Save changes' : 'Create court', busy: _busy, onPressed: _save),
                  ]),
                ),
    );
  }
}
