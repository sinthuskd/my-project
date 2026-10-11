import 'package:flutter/material.dart';
import '../utils/icon_map.dart';

enum CourtStatus { nextSlot, availableNow, booked }

class VenueCourt {
  final String id; // court id, used to load its slots
  final String name;
  final String tag;
  final String description;
  final String sport;
  final int price;
  final CourtStatus status;
  final String statusText;
  const VenueCourt({
    this.id = '',
    required this.name,
    required this.tag,
    required this.description,
    required this.sport,
    required this.price,
    required this.status,
    required this.statusText,
  });

  factory VenueCourt.fromJson(Map<String, dynamic> j) {
    final st = '${j['status'] ?? 'booked'}';
    return VenueCourt(
      id: '${j['id'] ?? ''}',
      name: '${j['name'] ?? ''}',
      tag: '${j['tag'] ?? ''}',
      description: '${j['description'] ?? ''}',
      sport: '${j['sport'] ?? ''}',
      price: (j['price'] as num?)?.round() ?? 0,
      status: st == 'availableNow'
          ? CourtStatus.availableNow
          : (st == 'nextSlot' ? CourtStatus.nextSlot : CourtStatus.booked),
      statusText: '${j['statusText'] ?? ''}',
    );
  }
}

class VenueAmenity {
  final IconData icon;
  final String title;
  final String subtitle;
  const VenueAmenity(this.icon, this.title, this.subtitle);
}

class Venue {
  final String id;
  final String name;
  final String address;
  final String area;
  final double distanceKm;
  final double rating;
  final int reviews;
  final int startingRate;
  final List<String> photos;
  final List<VenueCourt> courts;
  final List<VenueAmenity> amenities;
  final List<String> guidelines; // **bold** markers supported

  const Venue({
    required this.id,
    required this.name,
    required this.address,
    required this.area,
    required this.distanceKm,
    required this.rating,
    required this.reviews,
    required this.startingRate,
    required this.photos,
    required this.courts,
    required this.amenities,
    required this.guidelines,
  });

  /// Empty venue, shown until real data is loaded from the backend (GET /venues/:id).
  static const Venue empty = Venue(
    id: '',
    name: '',
    address: '',
    area: '',
    distanceKm: 0,
    rating: 0,
    reviews: 0,
    startingRate: 0,
    photos: [],
    courts: [],
    amenities: [],
    guidelines: [],
  );

  /// GET /venues/:id
  factory Venue.fromJson(Map<String, dynamic> j) => Venue(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? ''}',
        address: '${j['address'] ?? ''}',
        area: '${j['area'] ?? ''}',
        distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0,
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        reviews: (j['reviews'] as num?)?.toInt() ?? 0,
        startingRate: (j['startingRate'] as num?)?.round() ?? 0,
        photos: ((j['photos'] as List?) ?? []).map((e) => '$e').toList(),
        courts: ((j['courts'] as List?) ?? [])
            .map((e) => VenueCourt.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        amenities: ((j['amenities'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .map((a) => VenueAmenity(iconFromName('${a['icon'] ?? ''}'),
                '${a['title'] ?? ''}', '${a['subtitle'] ?? ''}'))
            .toList(),
        guidelines: ((j['guidelines'] as List?) ?? []).map((e) => '$e').toList(),
      );

  Venue copyWith({
    String? name,
    String? address,
    double? distanceKm,
    double? rating,
    int? reviews,
    int? startingRate,
    List<String>? photos,
  }) =>
      Venue(
        id: id,
        name: name ?? this.name,
        address: address ?? this.address,
        area: area,
        distanceKm: distanceKm ?? this.distanceKm,
        rating: rating ?? this.rating,
        reviews: reviews ?? this.reviews,
        startingRate: startingRate ?? this.startingRate,
        photos: photos ?? this.photos,
        courts: courts,
        amenities: amenities,
        guidelines: guidelines,
      );

  /// Disciplines with court counts, in order of first appearance.
  Map<String, int> get disciplines {
    final m = <String, int>{};
    for (final c in courts) {
      m[c.sport] = (m[c.sport] ?? 0) + 1;
    }
    return m;
  }
}
