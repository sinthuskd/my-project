import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_colors.dart';
import 'admin_ui.dart';

/// Create (venue == null) or edit a facility. Pops `true` when saved.
class AdminFacilityForm extends StatefulWidget {
  final Map<String, dynamic>? venue; // full venue detail from GET /admin/venues/:id
  const AdminFacilityForm({super.key, this.venue});

  @override
  State<AdminFacilityForm> createState() => _AdminFacilityFormState();
}

class _AdminFacilityFormState extends State<AdminFacilityForm> {
  final _key = GlobalKey<FormState>();
  late final Map<String, dynamic> v = widget.venue ?? {};
  bool _busy = false;
  bool _active = true;

  late final _name = TextEditingController(text: '${v['name'] ?? ''}');
  late final _area = TextEditingController(text: '${v['area'] ?? ''}');
  late final _address = TextEditingController(text: '${v['address'] ?? ''}');
  late final _lat = TextEditingController(text: v['lat']?.toString() ?? '');
  late final _lng = TextEditingController(text: v['lng']?.toString() ?? '');
  late final _distance = TextEditingController(text: '${v['distanceKm'] ?? 0}');
  late final _surface = TextEditingController(text: '${v['surfaceLabel'] ?? ''}');
  late final _gate = TextEditingController(text: '${v['gate'] ?? 'Main Gate'}');
  late final _open = TextEditingController(text: '${v['openHour'] ?? 6}');
  late final _close = TextEditingController(text: '${v['closeHour'] ?? 22}');
  late final _image = TextEditingController(text: '${v['imageAsset'] ?? ''}');
  late final _photos = TextEditingController(text: ((v['photos'] as List?) ?? []).join('\n'));
  late final _facilities = TextEditingController(text: ((v['facilities'] as List?) ?? []).join(', '));
  late final _guidelines = TextEditingController(text: ((v['guidelines'] as List?) ?? []).join('\n'));
  late final _amenities = TextEditingController(
      text: ((v['amenities'] as List?) ?? [])
          .map((a) => '${a['icon']} | ${a['title']} | ${a['subtitle'] ?? ''}')
          .join('\n'));

  static const _bundled = ['court_royal.jpg', 'court_csa.jpg', 'court_liberty.jpg'];

  @override
  void initState() {
    super.initState();
    _active = v['active'] != false;
  }

  @override
  void dispose() {
    for (final c in [_name, _area, _address, _lat, _lng, _distance, _surface, _gate, _open, _close, _image, _photos, _facilities, _guidelines, _amenities]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(String s) => s.trim().isEmpty ? null : double.tryParse(s.trim());

  List<Map<String, String>> _parseAmenities() => splitLines(_amenities.text).map((l) {
        final p = l.split('|').map((x) => x.trim()).toList();
        return {
          'icon': p.isNotEmpty && p[0].isNotEmpty ? p[0] : 'info',
          'title': p.length > 1 ? p[1] : '',
          'subtitle': p.length > 2 ? p[2] : '',
        };
      }).where((a) => a['title']!.isNotEmpty).toList();

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final photos = splitLines(_photos.text);
    final image = _image.text.trim().isNotEmpty ? _image.text.trim() : (photos.isNotEmpty ? photos.first : '');
    if (image.isEmpty) {
      toast(context, 'Add a main image (path or URL) or at least one photo.', error: true);
      return;
    }
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'area': _area.text.trim(),
      'address': _address.text.trim(),
      'lat': _num(_lat.text),
      'lng': _num(_lng.text),
      'distanceKm': _num(_distance.text) ?? 0,
      'surfaceLabel': _surface.text.trim(),
      'gate': _gate.text.trim(),
      'openHour': int.parse(_open.text.trim()),
      'closeHour': int.parse(_close.text.trim()),
      'imageAsset': image,
      'photos': photos,
      'facilities': splitCsv(_facilities.text),
      'guidelines': splitLines(_guidelines.text),
      'amenities': _parseAmenities(),
      'active': _active,
    };
    setState(() => _busy = true);
    final editing = widget.venue != null;
    final ok = await runAction(
      context,
      () => editing ? AdminApi.updateVenue('${v['id']}', body) : AdminApi.createVenue(body),
      ok: editing ? 'Facility updated' : 'Facility created',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  String? _hour(String? s, int min, int max) {
    final n = int.tryParse((s ?? '').trim());
    return (n == null || n < min || n > max) ? '$min-$max' : null;
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.venue != null;
    return Scaffold(
      appBar: adminAppBar(editing ? 'Edit facility' : 'New facility'),
      body: Form(
        key: _key,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
          FormBox(label: 'Name *', controller: _name, validator: requiredField),
          FormBox(label: 'Area *', controller: _area, hint: 'e.g. Colombo 03', validator: requiredField),
          FormBox(label: 'Address *', controller: _address, validator: requiredField),
          Row(children: [
            Expanded(child: FormBox(label: 'Latitude', controller: _lat, keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true), validator: optionalNumber)),
            const SizedBox(width: 10),
            Expanded(child: FormBox(label: 'Longitude', controller: _lng, keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true), validator: optionalNumber)),
          ]),
          FormBox(label: 'Distance (km)', controller: _distance, hint: 'Used when the app has no location', keyboard: const TextInputType.numberWithOptions(decimal: true), validator: optionalNumber),
          FormBox(label: 'Surface label', controller: _surface, hint: 'Card text, e.g. Indoor Wood'),
          FormBox(label: 'Gate', controller: _gate),
          Row(children: [
            Expanded(child: FormBox(label: 'Opens (0-23)', controller: _open, keyboard: TextInputType.number, validator: (s) => _hour(s, 0, 23))),
            const SizedBox(width: 10),
            Expanded(child: FormBox(label: 'Closes (1-24)', controller: _close, keyboard: TextInputType.number, validator: (s) => _hour(s, 1, 24))),
          ]),
          FormBox(label: 'Main image', controller: _image, hint: 'Image URL or app asset path, e.g. assets/images/court_royal.jpg'),
          Wrap(spacing: 8, children: [
            for (final b in _bundled)
              ActionChip(label: Text(b), onPressed: () => setState(() => _image.text = 'assets/images/$b')),
          ]),
          const SizedBox(height: 14),
          FormBox(label: 'Photos', controller: _photos, hint: 'One image URL / path per line', maxLines: 3),
          FormBox(label: 'Search facilities', controller: _facilities, hint: 'Comma separated filters, e.g. On-premise Free Parking, Showers'),
          FormBox(
              label: 'Amenities',
              controller: _amenities,
              hint: 'One per line: icon | title | subtitle\ne.g. local_parking | Free Parking | 50 cars',
              maxLines: 4),
          FormBox(label: 'Guidelines', controller: _guidelines, hint: 'One per line. **bold** is supported', maxLines: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
            title: const Text('Visible to customers', style: TextStyle(fontWeight: FontWeight.w600)),
            value: _active,
            onChanged: (x) => setState(() => _active = x),
          ),
          const SizedBox(height: 10),
          SaveButton(label: editing ? 'Save changes' : 'Create facility', busy: _busy, onPressed: _save),
        ]),
      ),
    );
  }
}
