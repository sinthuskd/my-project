import 'package:flutter/material.dart';
import '../utils/icon_map.dart';

class SlotOffer {
  final String time;
  final int price;
  final String slotId; // admin slot id, used to book (POST /bookings)
  const SlotOffer(this.time, this.price, {this.slotId = ''});

  factory SlotOffer.fromJson(Map<String, dynamic> j) => SlotOffer(
        '${j['time'] ?? ''}',
        (j['price'] as num?)?.round() ?? 0,
        slotId: '${j['slotId'] ?? j['id'] ?? ''}',
      );
}

class AmenityTag {
  final IconData icon;
  final String label;
  const AmenityTag(this.icon, this.label);
}

class CourtListing {
  final String id;
  final String courtId;
  final String venueId;
  final String name;
  final String area;
  final double distanceKm;
  final double rating;
  final int reviews;
  final String imageAsset;
  final bool topPick;
  final bool instantLock;
  final String? tag; // e.g. WOODEN PARQUET
  final String? certified; // e.g. BWF CERTIFIED MAT
  final List<AmenityTag> amenities;
  final List<SlotOffer> slots;
  final bool featuredSlots;
  final int rate;

  const CourtListing({
    required this.id,
    this.courtId = '',
    this.venueId = '',
    required this.name,
    required this.area,
    required this.distanceKm,
    required this.rating,
    required this.reviews,
    required this.imageAsset,
    this.topPick = false,
    this.instantLock = false,
    this.tag,
    this.certified,
    required this.amenities,
    required this.slots,
    this.featuredSlots = false,
    required this.rate,
  });

  /// GET /listings -> items[]
  factory CourtListing.fromJson(Map<String, dynamic> j) => CourtListing(
        id: '${j['id'] ?? ''}',
        courtId: '${j['courtId'] ?? j['id'] ?? ''}',
        venueId: '${j['venueId'] ?? ''}',
        name: '${j['name'] ?? ''}',
        area: '${j['area'] ?? ''}',
        distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0,
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        reviews: (j['reviews'] as num?)?.toInt() ?? 0,
        imageAsset: '${j['imageAsset'] ?? ''}',
        topPick: j['topPick'] == true,
        instantLock: j['instantLock'] == true,
        tag: j['tag'] == null ? null : '${j['tag']}',
        certified: j['certified'] == null ? null : '${j['certified']}',
        amenities: ((j['amenities'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .map((a) => AmenityTag(
                iconFromName('${a['icon'] ?? ''}'), '${a['label'] ?? ''}'))
            .toList(),
        slots: ((j['slots'] as List?) ?? [])
            .map((e) => SlotOffer.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        featuredSlots: j['featuredSlots'] == true,
        rate: (j['rate'] as num?)?.round() ?? 0,
      );
}
