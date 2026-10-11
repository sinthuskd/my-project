import 'package:flutter/material.dart';
import '../flow/flow_ui.dart' show goScreen;
import 'package:flutter/services.dart';
import '../utils/routes.dart';
import 'venue_detail_screen.dart';
import '../models/app_user.dart';
import '../models/court.dart';
import '../models/sport_category.dart';
import '../models/venue.dart';
import '../services/auth_service.dart';
import '../services/catalog_api.dart';
import '../theme/app_colors.dart';
import '../widgets/app_logo.dart';
import '../widgets/court_card.dart';
import '../widgets/partner_footer.dart';

class CourtDashboardScreen extends StatefulWidget {
  final VoidCallback onOpenSearch;
  const CourtDashboardScreen({super.key, required this.onOpenSearch});

  @override
  State<CourtDashboardScreen> createState() => _CourtDashboardScreenState();
}

class _CourtDashboardScreenState extends State<CourtDashboardScreen> {
  String? _selected;

  // Loaded from the backend: GET /categories and GET /courts (admin data).
  List<SportCategory> _categories = [];
  List<Court> _allCourts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _allCourts.isEmpty;
      _error = null;
    });
    try {
      final cats = await CatalogApi.categories();
      final courts = await CatalogApi.courts();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _allCourts = courts;
        _loading = false;
        if (_selected != null && !cats.any((c) => c.name == _selected)) {
          _selected = null;
        }
      });
    } on CatalogException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _openVenue(Court c) => Navigator.of(context).push(fadeRoute(
      VenueDetailScreen(venue: Venue.empty, venueId: c.id)));

  void _toast(String t) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(t)));

  List<Court> get _courts => _selected == null
      ? _allCourts
      : _allCourts.where((c) => c.sports.contains(_selected)).toList();

  @override
  Widget build(BuildContext context) {
    final courts = _courts;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const AppLogoMark(size: 44),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SPORTSBOOK',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: AppColors.primary)),
                    Text('Court Dashboard',
                        style: TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w800)),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => goScreen(context, 20),
                  icon: const Icon(Icons.notifications_none, size: 26),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.person_outline, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _toast('Change location (coming soon)'),
                        child: const Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 18, color: AppColors.primary),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text('SET YOUR LOCATION',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: AppColors.primary)),
                            ),
                            Icon(Icons.keyboard_arrow_down,
                                size: 18, color: AppColors.primary),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      ValueListenableBuilder<AppUser?>(
                        valueListenable: AuthService.user,
                        builder: (_, u, __) => Text(
                            'Hello, ${u?.firstName ?? 'there'} 👋',
                            style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8)),
                      ),
                      const Text("Ready for today's match?",
                          style: TextStyle(
                              fontSize: 15, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: widget.onOpenSearch,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                        color: AppColors.chip, shape: BoxShape.circle),
                    child: const Icon(Icons.search, size: 26),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Categories
            Row(
              children: [
                const Text('Categories',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('${_categories.length} SPORTS ACTIVE',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final c = _categories[i];
                  final on = _selected == c.name;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selected = on ? null : c.name),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: on ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(35),
                        boxShadow: [
                          BoxShadow(
                              color: (on ? AppColors.primary : AppColors.textDark)
                                  .withValues(alpha: on ? 0.28 : 0.05),
                              blurRadius: 14,
                              offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(c.icon,
                              color: on ? Colors.white : AppColors.primary),
                          const SizedBox(width: 10),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name,
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: on
                                          ? Colors.white
                                          : AppColors.textDark)),
                              Text('${c.venues} Venues',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: on
                                          ? Colors.white70
                                          : AppColors.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 22),

            // Nearby courts
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nearby Courts',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800)),
                      Text('Real-time availability near you',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _toast('Map view (Member 2)'),
                  child: const Row(
                    children: [
                      Icon(Icons.map_outlined,
                          size: 18, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text('Map View',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Column(
                key: ValueKey(_selected),
                children: _loading
                    ? [
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: CircularProgressIndicator())),
                      ]
                    : _error != null
                    ? [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24)),
                          child: Column(children: [
                            Text(_error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.danger)),
                            TextButton(
                                onPressed: _load, child: const Text('Retry')),
                          ]),
                        ),
                        const SizedBox(height: 16),
                      ]
                    : courts.isEmpty
                    ? [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24)),
                          child: Text('No ${_selected ?? ''} courts yet.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 15)),
                        ),
                        const SizedBox(height: 16),
                      ]
                    : courts
                        .map((c) => CourtCard(
                              court: c,
                              onTap: () => _openVenue(c),
                              onBook: () => _openVenue(c),
                            ))
                        .toList(),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: PartnerFooter(
                  title: 'OFFICIAL PARTNER OF COLOMBO SPORTS AUTHORITY',
                  sub: 'SportsBook Version 2.4.0 • Real-time Sync Active'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
