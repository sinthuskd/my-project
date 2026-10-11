import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/court.dart' show formatLkr;
import '../models/venue.dart';
import '../services/catalog_api.dart';
import '../widgets/app_image.dart';
import 'slot_booking_screen.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_action_bar.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';

class VenueDetailScreen extends StatefulWidget {
  final Venue venue;

  /// If given, the venue is loaded from the backend (GET /venues/:id).
  final String? venueId;
  const VenueDetailScreen({super.key, required this.venue, this.venueId});

  @override
  State<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends State<VenueDetailScreen> {
  final _pager = PageController();
  int _photo = 0;
  late Venue _v = widget.venue;
  String _sport = '';
  bool _loading = false;
  String? _error;
  bool _saved = false;
  final Set<String> _notify = {};

  void _toast(String t) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(t)));

  String _firstSport(Venue v) =>
      v.disciplines.isEmpty ? '' : v.disciplines.keys.first;

  @override
  void initState() {
    super.initState();
    _sport = _firstSport(_v);
    final id = widget.venueId ?? (_v.id.isNotEmpty ? _v.id : null);
    if (id != null) _load(id);
  }

  Future<void> _load(String id) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final v = await CatalogApi.venue(id);
      if (!mounted) return;
      setState(() {
        _v = v;
        _sport = _firstSport(v);
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

  /// Opens the real slot picker (admin slots) for one court.
  void _openBooking(VenueCourt? c) {
    if (c == null || c.id.isEmpty) {
      _toast('No court available to book yet');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SlotBookingScreen(courtId: c.id, courtName: c.name)));
  }

  VenueCourt? _firstBookable(List<VenueCourt> courts) {
    for (final c in courts) {
      if (c.status != CourtStatus.booked) return c;
    }
    return courts.isEmpty ? null : courts.first;
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _v;
    if (_loading && v.id.isEmpty) {
      return const Scaffold(
          body: SafeArea(child: Center(child: CircularProgressIndicator())));
    }
    if (_error != null && v.id.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Column(children: [
            const AppHeader(title: 'Venue Detail'),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.danger)),
                    TextButton(
                        onPressed: () => _load(widget.venueId ?? ''),
                        child: const Text('Retry')),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      );
    }
    final disciplines = v.disciplines;
    final courts = v.courts.where((c) => c.sport == _sport).toList();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Venue Detail',
              actions: [
                IconButton(
                  onPressed: () {
                    setState(() => _saved = !_saved);
                    _toast(_saved ? 'Saved to favourites' : 'Removed');
                  },
                  icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border,
                      color: _saved ? AppColors.primary : null),
                ),
                IconButton(
                  onPressed: () => _toast('Share link copied (demo)'),
                  icon: const Icon(Icons.share_outlined),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  _hero(v),
                  const SizedBox(height: 16),
                  _summary(v),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Text('AVAILABLE DISCIPLINES',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: AppColors.textSecondary)),
                      const Spacer(),
                      CardTag('${disciplines.length} Sports Configured'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: disciplines.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final name = disciplines.keys.elementAt(i);
                        final on = name == _sport;
                        return GestureDetector(
                          onTap: () => setState(() => _sport = name),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            decoration: BoxDecoration(
                                color: on ? AppColors.primary : Colors.white,
                                borderRadius: BorderRadius.circular(24)),
                            child: Row(
                              children: [
                                Icon(Icons.sports_tennis,
                                    size: 18,
                                    color: on
                                        ? Colors.white
                                        : AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Text('$name (${disciplines[name]})',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: on
                                            ? Colors.white
                                            : AppColors.textDark)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _hours(),
                  _location(v),
                  const SizedBox(height: 4),
                  _liveAvailability(courts),
                  const SizedBox(height: 8),
                  const Text('Arena Amenities',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  _amenities(v),
                  const SizedBox(height: 16),
                  _guidelines(v),
                  _contact(),
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
                        const Text('STARTING FROM',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: AppColors.textSecondary)),
                        Text.rich(TextSpan(
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w800),
                          children: [
                            const TextSpan(
                                text: 'LKR ',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary)),
                            TextSpan(text: formatLkr(v.startingRate)),
                          ],
                        )),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: PrimaryButton(
                      label: 'Book Court Now',
                      leadingIcon: Icons.calendar_month_outlined,
                      onPressed: () => _openBooking(_firstBookable(courts)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(Venue v) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: SizedBox(
        height: 230,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pager,
              itemCount: v.photos.length,
              onPageChanged: (i) => setState(() => _photo = i),
              itemBuilder: (_, i) => AppImage(v.photos[i]),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(20)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text('INDOOR & OUTDOOR',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: AppColors.primary)),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_camera_outlined,
                        size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text('${_photo + 1}/${v.photos.length} Photos',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              bottom: 18,
              child: Row(
                children: [
                  for (var i = 0; i < v.photos.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _photo ? 26 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: i == _photo
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8)),
                    ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: GestureDetector(
                onTap: () => _toast('Photo gallery (coming soon)'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.grid_view, size: 16, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text('View All',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(Venue v) {
    Widget badge(IconData i, String t) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.chip,
                borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Icon(i, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(t,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
              ],
            ),
          ),
        );
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              badge(Icons.verified, 'Verified Facility'),
              const SizedBox(width: 10),
              badge(Icons.bolt, 'Fast Confirmation'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.name,
                        style: const TextStyle(
                            fontSize: 24,
                            height: 1.15,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 18, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text('${v.rating}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        Text('  (${v.reviews} reviews)',
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(v.address,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('RATE',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: AppColors.textSecondary)),
                  Text.rich(TextSpan(
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary),
                    children: [
                      const TextSpan(
                          text: 'LKR ', style: TextStyle(fontSize: 14)),
                      TextSpan(text: formatLkr(v.startingRate)),
                    ],
                  )),
                  const Text('/ hour',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hours() {
    Widget tile(String d, String t) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(t,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        );
    return SectionCard(
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.circle, size: 10, color: AppColors.success),
              const SizedBox(width: 8),
              const Text('Opening Hours',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              tile('Mon – Fri', '—'),
              const SizedBox(width: 10),
              tile('Sat – Sun', '—'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _location(Venue v) {
    return SectionCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                    color: AppColors.chip, shape: BoxShape.circle),
                child: const Icon(Icons.location_on_outlined,
                    color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.address,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    Text('${v.area} • ${v.distanceKm} km away from you',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 130,
            width: double.infinity,
            decoration: BoxDecoration(
                color: const Color(0xFFC9D6F5),
                borderRadius: BorderRadius.circular(18)),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.sports_tennis,
                          size: 18, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(v.name.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _toast('Opening maps (demo)'),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                        color: AppColors.chip,
                        borderRadius: BorderRadius.circular(16)),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.turn_right,
                            size: 18, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text('Get Directions',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: v.address));
                  _toast('Address copied');
                },
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16)),
                  child: const Row(
                    children: [
                      Icon(Icons.copy, size: 16),
                      SizedBox(width: 6),
                      Text('Copy',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _liveAvailability(List<VenueCourt> courts) {
    final today = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Live Court Availability',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  Text('Instant booking with lock-in slot',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: AppColors.chip,
                  borderRadius: BorderRadius.circular(18)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text('Today, ${dayMonth(today)}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Column(
            key: ValueKey(_sport),
            children: [for (final c in courts) _courtRow(c)],
          ),
        ),
      ],
    );
  }

  Widget _courtRow(VenueCourt c) {
    final booked = c.status == CourtStatus.booked;
    final notified = _notify.contains(c.name);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: booked ? AppColors.card : Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(c.name,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: AppColors.chip,
                              borderRadius: BorderRadius.circular(12)),
                          child: Text(c.tag,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(c.description,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('LKR ${formatLkr(c.price)}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: booked
                              ? AppColors.textSecondary
                              : AppColors.primary)),
                  const Text('/hr',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                  booked
                      ? Icons.remove_circle_outline
                      : (c.status == CourtStatus.availableNow
                          ? Icons.check_circle_outline
                          : Icons.schedule),
                  size: 20,
                  color: booked ? AppColors.textSecondary : AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(c.statusText,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: booked
                            ? AppColors.textSecondary
                            : AppColors.primary)),
              ),
              if (booked)
                GestureDetector(
                  onTap: () {
                    setState(() => notified
                        ? _notify.remove(c.name)
                        : _notify.add(c.name));
                    _toast(notified
                        ? 'Notification off'
                        : "We'll notify you when ${c.name} is free");
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                        color: notified ? AppColors.success : AppColors.chip,
                        borderRadius: BorderRadius.circular(22)),
                    child: Text(notified ? 'Notified ✓' : 'Notify Me',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color:
                                notified ? Colors.white : AppColors.textDark)),
                  ),
                )
              else
                PrimaryButton(
                    label: 'Book Slot',
                    small: true,
                    onPressed: () => _openBooking(c)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amenities(Venue v) {
    return Column(
      children: [
        for (var i = 0; i < v.amenities.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _amenity(v.amenities[i])),
                const SizedBox(width: 10),
                Expanded(
                    child: i + 1 < v.amenities.length
                        ? _amenity(v.amenities[i + 1])
                        : const SizedBox()),
              ],
            ),
          ),
      ],
    );
  }

  Widget _amenity(VenueAmenity a) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: AppColors.chip,
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(a.icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800)),
                  Text(a.subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _guidelines(Venue v) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.chip, borderRadius: BorderRadius.circular(28)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Venue Guidelines & Rules',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 14),
          for (final g in v.guidelines)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7, right: 10),
                    child: Icon(Icons.circle, size: 7, color: AppColors.primary),
                  ),
                  Expanded(child: _richBullet(g)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Turns "a **bold** b" into rich text.
  Widget _richBullet(String s) {
    final parts = s.split('**');
    return Text.rich(TextSpan(
      style: const TextStyle(
          fontSize: 15, height: 1.45, color: AppColors.textSecondary),
      children: [
        for (var i = 0; i < parts.length; i++)
          TextSpan(
              text: parts[i],
              style: i.isOdd
                  ? const TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.textDark)
                  : null),
      ],
    ));
  }

  Widget _contact() {
    return SectionCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
                color: AppColors.primary, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Text('ADM',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Facility Admin',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                Text('Ask about this venue',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _toast('Chat with facility admin (coming soon)'),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: AppColors.chip,
                  borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.chat_bubble_outline,
                  color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
