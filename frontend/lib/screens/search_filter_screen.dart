import 'package:flutter/material.dart';
import '../models/court.dart' show formatLkr;
import '../models/search_filters.dart';
import '../services/catalog_api.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import '../utils/routes.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_action_bar.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';
import '../widgets/select_chip.dart';
import 'search_results_screen.dart';

/// "Select Your Slot" - search filters (Search tab).
class SearchFilterScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const SearchFilterScreen({super.key, this.onBack});

  @override
  State<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends State<SearchFilterScreen> {
  SearchFilters _f = SearchFilters.initial();
  late final TextEditingController _query =
      TextEditingController(text: _f.query);
  final _days = List.generate(
      4, (i) => DateTime.now().add(Duration(days: i)),
      growable: false);

  static const _histogram = [
    0.15, 0.3, 0.55, 0.9, 0.7, 0.95, 0.6, 0.45, 0.25, 0.2, 0.15, 0.1, 0.1, 0.08
  ];

  String _countKey = '';
  int _countReq = 0;

  @override
  void initState() {
    super.initState();
    _loadSports();
  }

  /// Sports chips = the sports the admin created (GET /categories).
  Future<void> _loadSports() async {
    try {
      final cats = await CatalogApi.categories();
      if (!mounted) return;
      setState(() {
        SearchFilters.sports = cats.map((c) => c.name).toList();
        if (!SearchFilters.sports.contains(_f.sport)) {
          _f.sport =
              SearchFilters.sports.isNotEmpty ? SearchFilters.sports.first : '';
        }
        _countKey = ''; // force a fresh court count
      });
    } on CatalogException {
      // offline: chips stay empty
    }
  }

  /// Court count shown at the bottom (GET /listings -> count).
  Future<void> _syncCount() async {
    final key = '${_f.toQuery(_days)}';
    if (key == _countKey) return;
    _countKey = key;
    final req = ++_countReq;
    try {
      final r = await CatalogApi.listings(_f, _days);
      if (!mounted || req != _countReq) return;
      setState(() => _f.courtCount = r.count);
    } on CatalogException {
      // ignore
    }
  }

  void _reset() => setState(() {
        _f = SearchFilters.initial();
        _query.text = _f.query;
      });

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.textSecondary));

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncCount();
    });
    final f = _f;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          AppHeader(
              title: 'Select Your Slot',
              onBack: widget.onBack,
              showBack: widget.onBack != null),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                // Search field + Reset
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(26)),
                        child: Row(
                          children: [
                            const Icon(Icons.search,
                                color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _query,
                                onChanged: (v) => f.query = v,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500),
                                decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Search courts or areas'),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() {
                                _query.clear();
                                f.query = '';
                              }),
                              child: const Icon(Icons.close,
                                  size: 20, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _reset,
                      child: const Text('Reset',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.circle, size: 8, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                        child: _label('COLOMBO DISTRICT • LIVE AVAILABILITY')),
                    Text('${f.activeCount} Filters applied',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _label('SPORT CATEGORY'),
                    const Spacer(),
                    const CardTag('Racquet Sports'),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: SearchFilters.sports.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final s = SearchFilters.sports[i];
                      return SelectChip(
                        label: s,
                        selected: f.sport == s,
                        showCheck: false,
                        icon: Icons.sports_tennis,
                        onTap: () => setState(() {
                          f.sport = s;
                          f.query = s;
                          _query.text = f.query;
                        }),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Date & Time
                SectionCard(
                  icon: Icons.calendar_today_outlined,
                  title: 'Date & Time',
                  trailing: const CardTag('FLEXIBLE', pill: true),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          for (var i = 0; i < _days.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => f.dayIndex = i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: f.dayIndex == i
                                        ? AppColors.primary
                                        : AppColors.card,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                          i == 0
                                              ? 'TODAY'
                                              : weekdayShort(_days[i])
                                                  .toUpperCase(),
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: f.dayIndex == i
                                                  ? Colors.white70
                                                  : AppColors.textSecondary)),
                                      Text('${_days[i].day}',
                                          style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w800,
                                              color: f.dayIndex == i
                                                  ? Colors.white
                                                  : AppColors.textDark)),
                                      Text(monthShort(_days[i]),
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: f.dayIndex == i
                                                  ? Colors.white70
                                                  : AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      _label('PREFERRED TIME WINDOW'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0;
                              i < SearchFilters.timeWindows.length;
                              i++)
                            SelectChip(
                              label: SearchFilters.timeWindows[i],
                              selected: f.timeWindow == i,
                              icon: f.timeWindow == i ? Icons.check : null,
                              onTap: () => setState(() => f.timeWindow = i),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Distance
                SectionCard(
                  icon: Icons.near_me_outlined,
                  title: 'Distance Radius',
                  trailing: CardTag(
                      SearchFilters.radii[f.radius].replaceAll('< ', ''),
                      pill: true),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            for (var i = 0; i < SearchFilters.radii.length; i++)
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => f.radius = i),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                        color: f.radius == i
                                            ? AppColors.primary
                                            : Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: Center(
                                      child: Text(SearchFilters.radii[i],
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: f.radius == i
                                                  ? Colors.white
                                                  : AppColors.textDark)),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(16)),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 20, color: AppColors.primary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Search area\nCourts near your current location.',
                                style: TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Environment
                SectionCard(
                  icon: Icons.home_outlined,
                  title: 'Court Environment',
                  child: Column(
                    children: [
                      for (var row = 0; row < 2; row++) ...[
                        if (row > 0) const SizedBox(height: 10),
                        Row(
                          children: [
                            for (var col = 0; col < 2; col++) ...[
                              if (col > 0) const SizedBox(width: 10),
                              Expanded(child: _envTile(row * 2 + col)),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Surface
                SectionCard(
                  icon: Icons.layers_outlined,
                  title: 'Surface Type',
                  trailing: CardTag('${f.surfaces.length} selected'),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in SearchFilters.surfaceOptions)
                        SelectChip(
                          label: s,
                          selected: f.surfaces.contains(s),
                          showCheck: true,
                          onTap: () => setState(() => f.surfaces.contains(s)
                              ? f.surfaces.remove(s)
                              : f.surfaces.add(s)),
                        ),
                    ],
                  ),
                ),

                // Rate
                SectionCard(
                  icon: Icons.payments_outlined,
                  title: 'Hourly Rate',
                  trailing: Text(
                      'LKR ${formatLkr(f.rate.start.round())} – ${formatLkr(f.rate.end.round())} /hr',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 60,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 0; i < _histogram.length; i++)
                              Expanded(
                                child: Builder(builder: (_) {
                                  final price =
                                      1000 + (4000 * i / (_histogram.length - 1));
                                  final on =
                                      price >= f.rate.start - 150 &&
                                          price <= f.rate.end + 150;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 2),
                                    height: 8 + 52 * _histogram[i],
                                    decoration: BoxDecoration(
                                      color: on
                                          ? AppColors.primary
                                          : AppColors.dotInactive,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  );
                                }),
                              ),
                          ],
                        ),
                      ),
                      RangeSlider(
                        values: f.rate,
                        min: 1000,
                        max: 5000,
                        divisions: 40,
                        onChanged: (v) => setState(() => f.rate = v),
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('LKR 1,000',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary)),
                          Text('LKR 3,000',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary)),
                          Text('LKR 5,000+',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ratePreset('Under LKR 2,000', 1000, 2000),
                            _ratePreset('LKR 2,000 - 3,500', 2000, 3500),
                            _ratePreset('Premium LKR 3,500+', 3500, 5000),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Facilities
                SectionCard(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Facilities & Amenities',
                  trailing: CardTag('${f.facilities.length} ACTIVE'),
                  child: Column(
                    children: [
                      for (final o in SearchFilters.facilityOptions)
                        _facility(o.$1, o.$2),
                    ],
                  ),
                ),

                // Coverage
                Container(
                  height: 140,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(18),
                  alignment: Alignment.bottomLeft,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF6B8CAE), Color(0xFF1E3A5F)]),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SEARCH COVERAGE',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                              color: Colors.white70)),
                      Text('${f.courtCount} Venues Verified',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ],
                  ),
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
                      Row(
                        children: [
                          const Icon(Icons.circle,
                              size: 10, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text('${f.courtCount} Courts',
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      Text(
                          'Ready for ${dayMonth(_days[f.dayIndex])}',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: PrimaryButton(
                    label: 'Show Results',
                    icon: Icons.arrow_forward,
                    onPressed: () => Navigator.of(context).push(fadeRoute(
                        SearchResultsScreen(
                            filters: f.copy(), days: _days))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _envTile(int i) {
    final o = SearchFilters.environments[i];
    final on = _f.environment == i;
    return GestureDetector(
      onTap: () => setState(() => _f.environment = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: on ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: on ? Colors.white : AppColors.textDark)),
                  Text(o.subtitle,
                      style: TextStyle(
                          fontSize: 13,
                          color: on ? Colors.white70 : AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(o.icon,
                color: on ? Colors.white : AppColors.textSecondary, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _ratePreset(String label, double a, double b) {
    final on = _f.rate.start == a && _f.rate.end == b;
    return SelectChip(
      label: label,
      selected: on,
      onTap: () => setState(() => _f.rate = RangeValues(a, b)),
    );
  }

  Widget _facility(String label, IconData icon) {
    final on = _f.facilities.contains(label);
    return GestureDetector(
      onTap: () => setState(() =>
          on ? _f.facilities.remove(label) : _f.facilities.add(label)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: on ? AppColors.chip : AppColors.card,
            borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: on ? Colors.white : AppColors.chip,
                  shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                  color: on ? AppColors.primary : AppColors.dotInactive,
                  shape: BoxShape.circle),
              child: on
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}
