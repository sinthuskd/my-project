import 'package:flutter/material.dart';

class EnvOption {
  final String title;
  final String subtitle;
  final IconData icon;
  const EnvOption(this.title, this.subtitle, this.icon);
}

class SearchFilters {
  String query;
  String sport;
  int dayIndex;
  int timeWindow;
  int radius;
  int environment;
  Set<String> surfaces;
  RangeValues rate;
  Set<String> facilities;

  /// Number of matching courts, filled from GET /listings (count).
  int courtCount;

  SearchFilters({
    required this.query,
    required this.sport,
    required this.dayIndex,
    required this.timeWindow,
    required this.radius,
    required this.environment,
    required this.surfaces,
    required this.rate,
    required this.facilities,
    this.courtCount = 0,
  });

  factory SearchFilters.initial() => SearchFilters(
        query: '',
        sport: sports.isNotEmpty ? sports.first : '',
        dayIndex: 0,
        timeWindow: 2,
        radius: 1,
        environment: 0,
        surfaces: {},
        rate: const RangeValues(1000, 5000),
        facilities: {},
      );

  SearchFilters copy() => SearchFilters(
        query: query,
        sport: sport,
        dayIndex: dayIndex,
        timeWindow: timeWindow,
        radius: radius,
        environment: environment,
        surfaces: {...surfaces},
        rate: rate,
        facilities: {...facilities},
        courtCount: courtCount,
      );

  /// Filled from the backend (GET /categories) = the sports the admin created.
  static List<String> sports = [];
  static const timeWindows = [
    'Any time',
    'Morning (6 AM - 12 PM)',
    'Evening / Floodlit (5 PM - 10 PM)',
    'Afternoon (12 PM - 5 PM)',
  ];
  static const timeShort = [
    'Any time',
    'Morning (6-12 AM)',
    'Evening (5-10 PM)',
    'Afternoon (12-5 PM)',
  ];
  static const radii = ['< 2 km', '5 km', '10 km', '15 km+'];
  static const environments = [
    EnvOption('Indoor Court', 'Climate shielded', Icons.apartment),
    EnvOption('Outdoor Court', 'Open skies', Icons.wb_sunny_outlined),
    EnvOption('Covered Rooftop', 'High elevation', Icons.roofing),
    EnvOption('All Environments', 'Any arena', Icons.tune),
  ];
  static const surfaceOptions = [
    'Wooden Parquet',
    'Synthetic BWF Mat',
    'Clay Court',
    'Hard Court Acrylic',
    'Natural / Turf Grass',
  ];
  static const facilityOptions = [
    ('Floodlights / LED Stadium Lights', Icons.wb_sunny_outlined),
    ('On-premise Free Parking', Icons.local_parking),
    ('Locker Rooms & Hot Showers', Icons.shower_outlined),
    ('Air Conditioned Players Lounge', Icons.ac_unit),
    ('Racket & Grip Equipment Rental', Icons.sports_tennis),
    ('Non-marking Shoe Rental Desk', Icons.directions_walk),
  ];

  /// Number of active filters (sport, date, time, environment, surface, rate, facilities).
  int get activeCount {
    var n = 2; // sport + date
    if (timeWindow != 0) n++;
    if (environment != 3) n++;
    if (surfaces.isNotEmpty) n++;
    if (rate.start > 1000 || rate.end < 5000) n++;
    if (facilities.isNotEmpty) n++;
    return n;
  }

  /// Query string values for GET /listings.
  Map<String, Object?> toQuery(List<DateTime> days) {
    String two(int n) => n.toString().padLeft(2, '0');
    final d = days[dayIndex];
    return {
      'q': query.trim(),
      'sport': sport,
      'date': '${d.year}-${two(d.month)}-${two(d.day)}',
      'timeWindow': const ['any', 'morning', 'evening', 'afternoon'][timeWindow],
      'radiusKm': const [2, 5, 10, null][radius],
      'environment': const ['indoor', 'outdoor', 'rooftop', 'all'][environment],
      'surfaces': surfaces.join(','),
      'minRate': rate.start > 1000 ? rate.start.round() : null,
      'maxRate': rate.end < 5000 ? rate.end.round() : null,
      'facilities': facilities.join(','),
    };
  }
}
