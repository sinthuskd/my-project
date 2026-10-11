class Court {
  final String id;
  final String name;
  final String address;
  final String surface;
  final List<String> sports;
  final double rating;
  final int reviews;
  final double distanceKm;
  final String nextAvailable;
  final int pricePerHour;
  final String imageAsset;

  const Court({
    required this.id,
    required this.name,
    required this.address,
    required this.surface,
    required this.sports,
    required this.rating,
    required this.reviews,
    required this.distanceKm,
    required this.nextAvailable,
    required this.pricePerHour,
    required this.imageAsset,
  });

  String get priceLabel => 'LKR ${formatLkr(pricePerHour)}';

  /// One dashboard card = one venue (GET /courts).
  factory Court.fromJson(Map<String, dynamic> j) => Court(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? ''}',
        address: '${j['address'] ?? ''}',
        surface: '${j['surface'] ?? ''}',
        sports: ((j['sports'] as List?) ?? []).map((e) => '$e').toList(),
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        reviews: (j['reviews'] as num?)?.toInt() ?? 0,
        distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0,
        nextAvailable: '${j['nextAvailable'] ?? ''}',
        pricePerHour: (j['pricePerHour'] as num?)?.round() ?? 0,
        imageAsset: '${j['imageAsset'] ?? ''}',
      );
}

String formatLkr(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}
