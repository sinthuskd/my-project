import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_colors.dart';
import 'admin_ui.dart';

/// Slots: pick a court and a day, then add / edit / switch off / delete slots
/// (time + price) or bulk-generate many at once.
class AdminSlotsScreen extends StatefulWidget {
  final String? initialCourtId;

  /// true when opened from a court (needs its own back button via app bar).
  final bool standalone;
  const AdminSlotsScreen({super.key, this.initialCourtId, this.standalone = false});

  @override
  State<AdminSlotsScreen> createState() => _AdminSlotsScreenState();
}

class _AdminSlotsScreenState extends State<AdminSlotsScreen> {
  List<Map<String, dynamic>>? _courts;
  String? _error;
  String? _courtId;
  DateTime _date = DateTime.now();
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _courtId = widget.initialCourtId;
    _loadCourts();
  }

  Future<void> _loadCourts() async {
    try {
      final c = await AdminApi.courts();
      if (!mounted) return;
      setState(() {
        _courts = c;
        _error = null;
        if (_courtId == null || !c.any((x) => '${x['id']}' == _courtId)) {
          _courtId = c.isNotEmpty ? '${c.first['id']}' : null;
        }
      });
    } on AdminApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Map<String, dynamic>? get _court {
    for (final c in _courts ?? const <Map<String, dynamic>>[]) {
      if ('${c['id']}' == _courtId) return c;
    }
    return null;
  }

  void _reload() => setState(() => _version++);

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (d != null) setState(() => _date = d);
  }

  void _shift(int days) => setState(() => _date = _date.add(Duration(days: days)));

  Future<void> _openSlotSheet({Map<String, dynamic>? slot}) async {
    final court = _court;
    if (court == null) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _SlotSheet(courtId: '${court['id']}', date: _date, hourlyPrice: (court['price'] as num?)?.toInt() ?? 0, slot: slot),
    );
    if (ok == true) _reload();
  }

  Future<void> _openBulkSheet() async {
    final court = _court;
    if (court == null) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _BulkSheet(courtId: '${court['id']}', from: _date, hourlyPrice: (court['price'] as num?)?.toInt() ?? 0),
    );
    if (ok == true) _reload();
  }

  Future<void> _toggle(Map<String, dynamic> s) async {
    final on = s['active'] == true;
    if (await runAction(context, () => AdminApi.updateSlot('${s['id']}', {'active': !on}), ok: on ? 'Slot switched off' : 'Slot switched on')) {
      _reload();
    }
  }

  Future<void> _delete(Map<String, dynamic> s) async {
    final ok = await confirmDialog(context,
        title: 'Delete slot', message: 'Delete the ${s['timeLabel']} slot on ${s['date']}?', confirmLabel: 'Delete', danger: true);
    if (!ok || !mounted) return;
    try {
      final r = await AdminApi.deleteSlot('${s['id']}');
      if (!mounted) return;
      toast(context, r['deactivated'] == true ? 'Slot has bookings, so it was switched off instead' : 'Slot deleted');
      _reload();
    } on AdminApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_error != null) {
      body = ErrorState(message: _error!, onRetry: () {
        setState(() => _error = null);
        _loadCourts();
      });
    } else if (_courts == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_courts!.isEmpty) {
      body = const EmptyState(icon: Icons.sports_tennis, text: 'No courts yet.\nCreate a facility and add a court first (Facilities tab).');
    } else {
      body = Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: DropdownButtonFormField<String>(
            value: _courtId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Court',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            items: [
              for (final c in _courts!)
                DropdownMenuItem(
                  value: '${c['id']}',
                  child: Text('${c['venueName'] ?? ''} • ${c['name']} (${c['sport']})', overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (x) => setState(() => _courtId = x),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: TextButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(prettyDate(_date), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
          ]),
        ),
        Expanded(
          child: LoadView<List<Map<String, dynamic>>>(
            key: ValueKey('$_courtId#${ymd(_date)}#$_version'),
            load: () => AdminApi.slots(courtId: _courtId, date: ymd(_date)),
            builder: (context, slots, reload) {
              if (slots.isEmpty) {
                return ListView(children: [
                  const EmptyState(icon: Icons.schedule, text: 'No slots on this day.\nUse + to add one, or generate many at once.'),
                  Center(child: OutlinedButton.icon(onPressed: _openBulkSheet, icon: const Icon(Icons.auto_awesome), label: const Text('Bulk generate'))),
                ]);
              }
              return RefreshIndicator(
                onRefresh: reload,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: slots.length,
                  itemBuilder: (_, i) {
                    final s = slots[i];
                    final status = '${s['status']}';
                    final booked = status == 'booked';
                    final booking = s['booking'] is Map ? Map<String, dynamic>.from(s['booking'] as Map) : null;
                    return AdminCard(
                      onTap: booked ? null : () => _openSlotSheet(slot: s),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${s['timeLabel']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 2),
                            Text('${s['durationMinutes']} min • ${lkr(s['price'] as num?)}', style: const TextStyle(color: AppColors.textSecondary)),
                            if (booking != null)
                              Text('Booked by ${booking['bookedBy']} (${booking['ref']})', style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                          ]),
                        ),
                        StatusChip(status.toUpperCase(), statusColor(status)),
                        PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') _openSlotSheet(slot: s);
                            if (v == 'toggle') _toggle(s);
                            if (v == 'delete') _delete(s);
                          },
                          itemBuilder: (_) => [
                            if (!booked) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            if (!booked) PopupMenuItem(value: 'toggle', child: Text(s['active'] == true ? 'Switch off' : 'Switch on')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.danger))),
                          ],
                        ),
                      ]),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ]);
    }

    final canAdd = _court != null;
    return Scaffold(
      appBar: adminAppBar('Slots', actions: [
        if (canAdd) IconButton(onPressed: _openBulkSheet, tooltip: 'Bulk generate', icon: const Icon(Icons.auto_awesome)),
      ]),
      floatingActionButton: canAdd
          ? FloatingActionButton.extended(
              onPressed: () => _openSlotSheet(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add slot'),
            )
          : null,
      body: body,
    );
  }
}

/* ---------------- add / edit one slot ---------------- */

class _SlotSheet extends StatefulWidget {
  final String courtId;
  final DateTime date;
  final int hourlyPrice;
  final Map<String, dynamic>? slot;
  const _SlotSheet({required this.courtId, required this.date, required this.hourlyPrice, this.slot});

  @override
  State<_SlotSheet> createState() => _SlotSheetState();
}

class _SlotSheetState extends State<_SlotSheet> {
  late DateTime _date = widget.slot != null ? parseYmd('${widget.slot!['date']}') : widget.date;
  late String _start = widget.slot != null ? '${widget.slot!['startTime']}' : '18:00';
  late String _end = widget.slot != null ? '${widget.slot!['endTime']}' : '19:00';
  late final _price = TextEditingController(text: widget.slot != null ? '${widget.slot!['price']}' : '');
  late bool _active = widget.slot?['active'] != false;
  bool _busy = false;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool start) async {
    final t = await showTimePicker(context: context, initialTime: parseHm(start ? _start : _end));
    if (t != null) setState(() => start ? _start = hm(t) : _end = hm(t));
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
        context: context, initialDate: _date, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 730)));
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final priceText = _price.text.trim();
    if (priceText.isNotEmpty && int.tryParse(priceText) == null) {
      toast(context, 'Price must be a whole number', error: true);
      return;
    }
    final body = <String, dynamic>{
      'date': ymd(_date),
      'startTime': _start,
      'endTime': endOf(_end),
      if (priceText.isNotEmpty) 'price': int.parse(priceText),
      if (widget.slot != null) 'active': _active,
    };
    setState(() => _busy = true);
    final editing = widget.slot != null;
    final ok = await runAction(
      context,
      () => editing ? AdminApi.updateSlot('${widget.slot!['id']}', body) : AdminApi.createSlot(widget.courtId, body),
      ok: editing ? 'Slot updated' : 'Slot added',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.slot != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(editing ? 'Edit slot' : 'Add slot', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_today, size: 18), label: Text(prettyDate(_date))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => _pickTime(true), icon: const Icon(Icons.schedule, size: 18), label: Text('Start $_start'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: () => _pickTime(false), icon: const Icon(Icons.schedule, size: 18), label: Text('End $_end'))),
          ]),
          const SizedBox(height: 14),
          FormBox(
            label: 'Price (LKR)',
            controller: _price,
            hint: widget.hourlyPrice > 0 ? 'Empty = court rate (${lkr(widget.hourlyPrice)}/hour) x hours' : 'Whole number',
            keyboard: TextInputType.number,
          ),
          if (editing)
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Bookable'), value: _active, onChanged: (x) => setState(() => _active = x)),
          const SizedBox(height: 6),
          SaveButton(label: editing ? 'Save slot' : 'Add slot', busy: _busy, onPressed: _save),
        ]),
      ),
    );
  }
}

/* ---------------- bulk generate ---------------- */

class _BulkSheet extends StatefulWidget {
  final String courtId;
  final DateTime from;
  final int hourlyPrice;
  const _BulkSheet({required this.courtId, required this.from, required this.hourlyPrice});

  @override
  State<_BulkSheet> createState() => _BulkSheetState();
}

class _BulkSheetState extends State<_BulkSheet> {
  late DateTime _from = widget.from;
  late DateTime _to = widget.from.add(const Duration(days: 6));
  String _start = '06:00';
  String _end = '22:00';
  final _minutes = TextEditingController(text: '60');
  final _price = TextEditingController();
  final Set<int> _days = {0, 1, 2, 3, 4, 5, 6}; // 0 = Sunday
  bool _busy = false;

  static const _names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void dispose() {
    _minutes.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool from) async {
    final d = await showDatePicker(
        context: context,
        initialDate: from ? _from : _to,
        firstDate: DateTime.now().subtract(const Duration(days: 30)),
        lastDate: DateTime.now().add(const Duration(days: 730)));
    if (d != null) setState(() => from ? _from = d : _to = d);
  }

  Future<void> _pickTime(bool start) async {
    final t = await showTimePicker(context: context, initialTime: parseHm(start ? _start : _end));
    if (t != null) setState(() => start ? _start = hm(t) : _end = hm(t));
  }

  Future<void> _generate() async {
    final mins = int.tryParse(_minutes.text.trim());
    if (mins == null || mins <= 0) {
      toast(context, 'Slot length must be a number of minutes', error: true);
      return;
    }
    final priceText = _price.text.trim();
    if (priceText.isNotEmpty && int.tryParse(priceText) == null) {
      toast(context, 'Price must be a whole number', error: true);
      return;
    }
    final body = <String, dynamic>{
      'fromDate': ymd(_from),
      'toDate': ymd(_to),
      'daysOfWeek': _days.toList()..sort(),
      'startTime': _start,
      'endTime': endOf(_end),
      'slotMinutes': mins,
      if (priceText.isNotEmpty) 'price': int.parse(priceText),
    };
    setState(() => _busy = true);
    try {
      final r = await AdminApi.bulkSlots(widget.courtId, body);
      if (!mounted) return;
      toast(context, '${r['created'] ?? 0} slots created, ${r['skipped'] ?? 0} skipped');
      Navigator.pop(context, true);
    } on AdminApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        toast(context, e.message, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Bulk generate slots', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Splits the time window into equal slots for every chosen day. Max 500 slots and 62 days per run.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => _pickDate(true), child: Text('From ${ymd(_from)}'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton(onPressed: () => _pickDate(false), child: Text('To ${ymd(_to)}'))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => _pickTime(true), icon: const Icon(Icons.schedule, size: 18), label: Text('Start $_start'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: () => _pickTime(false), icon: const Icon(Icons.schedule, size: 18), label: Text('End $_end'))),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: FormBox(label: 'Slot length (min)', controller: _minutes, keyboard: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(
                child: FormBox(
                    label: 'Price (LKR)',
                    controller: _price,
                    hint: widget.hourlyPrice > 0 ? 'Court rate' : null,
                    keyboard: TextInputType.number)),
          ]),
          const Text('Days', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(spacing: 6, children: [
            for (var i = 0; i < 7; i++)
              FilterChip(
                label: Text(_names[i]),
                selected: _days.contains(i),
                onSelected: (on) => setState(() => on ? _days.add(i) : _days.remove(i)),
              ),
          ]),
          const SizedBox(height: 16),
          SaveButton(label: 'Generate slots', busy: _busy, onPressed: _days.isEmpty ? () => toast(context, 'Pick at least one day', error: true) : _generate),
        ]),
      ),
    );
  }
}
