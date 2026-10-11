import 'package:flutter/material.dart';
import '../models/court_listing.dart';
import '../models/search_filters.dart';
import '../models/venue.dart';
import '../services/catalog_api.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import '../utils/routes.dart';
import '../widgets/app_header.dart';
import '../widgets/court_listing_card.dart';
import '../widgets/partner_footer.dart';
import 'slot_booking_screen.dart';
import 'venue_detail_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final SearchFilters filters;
  final List<DateTime> days;
  const SearchResultsScreen(
      {super.key, required this.filters, required this.days});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  static const _sorts = ['Nearest', 'Top Rated', 'Lowest Price'];
  int _sort = 0;

  // Loaded from the backend: GET /listings (only courts that have open admin slots).
  List<CourtListing> _listings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await CatalogApi.listings(widget.filters, widget.days);
      if (!mounted) return;
      setState(() {
        _listings = r.items;
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
  late final List<String> _chips = _buildChips();

  List<String> _buildChips() {
    final f = widget.filters;
    return [
      'Today, ${dayMonth(widget.days[f.dayIndex])}'
          .replaceFirst('Today', f.dayIndex == 0 ? 'Today' : weekdayShort(widget.days[f.dayIndex])),
      if (f.timeWindow != 0) SearchFilters.timeShort[f.timeWindow],
      if (f.environment != 3) SearchFilters.environments[f.environment].title,
      ...f.surfaces,
    ];
  }

  List<CourtListing> get _sorted {
    final l = [..._listings];
    switch (_sort) {
      case 1:
        l.sort((a, b) => b.rating.compareTo(a.rating));
      case 2:
        l.sort((a, b) => a.rate.compareTo(b.rate));
      default:
        l.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    }
    return l;
  }

  void _toast(String t) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(t)));

  void _open(CourtListing l) {
    Navigator.of(context).push(fadeRoute(VenueDetailScreen(
        venue: Venue.empty,
        venueId: l.venueId.isEmpty ? null : l.venueId)));
  }

  void _book(CourtListing l, SlotOffer? slot) {
    Navigator.of(context).push(fadeRoute(SlotBookingScreen(
      courtId: l.courtId,
      courtName: l.name,
      initialSlotId:
          (slot == null || slot.slotId.isEmpty) ? null : slot.slotId,
      initialDate: widget.days[widget.filters.dayIndex],
    )));
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.filters;
    final listings = _sorted;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: 'Select Your Slot'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: AppColors.chip,
                        borderRadius: BorderRadius.circular(26)),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.sports_tennis,
                              color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.query.isEmpty ? f.sport : f.query,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(
                                  '${f.activeCount} FILTERS APPLIED  •  ${SearchFilters.timeShort[f.timeWindow]}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14)),
                            child: const Icon(Icons.tune,
                                color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _chips.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                            color: i == 0 ? AppColors.primary : AppColors.chip,
                            borderRadius: BorderRadius.circular(22)),
                        child: Row(
                          children: [
                            Text(_chips[i],
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: i == 0
                                        ? Colors.white
                                        : AppColors.textDark)),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() => _chips.removeAt(i)),
                              child: Icon(Icons.close,
                                  size: 16,
                                  color: i == 0
                                      ? Colors.white
                                      : AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.circle,
                          size: 8, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${listings.length} Available\nCourts',
                            style: const TextStyle(
                                fontSize: 22,
                                height: 1.15,
                                fontWeight: FontWeight.w800)),
                      ),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _sort = (_sort + 1) % _sorts.length),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                              color: AppColors.chip,
                              borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            children: [
                              const Icon(Icons.swap_vert, size: 18),
                              const SizedBox(width: 4),
                              Text(_sorts[_sort],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _toast('Map view (coming soon)'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20)),
                          child: const Row(
                            children: [
                              Icon(Icons.map_outlined,
                                  size: 18, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Map',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Column(
                      key: ValueKey(_sort),
                      children: [
                        for (final l in listings)
                          CourtListingCard(
                            listing: l,
                            onOpen: () => _open(l),
                            onBook: (slot) => _book(l, slot),
                          ),
                      ],
                    ),
                  ),
                  if (_loading)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()))
                  else if (_error != null)
                    Column(children: [
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.danger)),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ])
                  else if (listings.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Text(
                          'No courts with open slots match your filters.\nTry another date or time.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 15)),
                    ),
                  if (listings.isNotEmpty)
                  GestureDetector(
                    onTap: () => _toast('No more courts to show'),
                    child: Container(
                      height: 58,
                      decoration: BoxDecoration(
                          color: AppColors.textDark,
                          borderRadius: BorderRadius.circular(29)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.explore_outlined,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          const Text('View More',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle),
                            child: Text('${listings.length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const PartnerFooter(
                      title: 'LIVE AVAILABILITY RADAR ACTIVE',
                      sub: 'VERSION 2.4.0'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
