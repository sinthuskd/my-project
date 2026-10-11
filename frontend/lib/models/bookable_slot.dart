/// One slot created by the admin (GET /courts/:id/slots).
class BookableSlot {
  final String id;
  final String time; // "6:00 AM"
  final String endTime;
  final int durationMinutes;
  final int price;
  const BookableSlot({
    required this.id,
    required this.time,
    required this.endTime,
    required this.durationMinutes,
    required this.price,
  });

  factory BookableSlot.fromJson(Map<String, dynamic> j) => BookableSlot(
        id: '${j['id'] ?? j['slotId'] ?? ''}',
        time: '${j['time'] ?? ''}',
        endTime: '${j['endTime'] ?? ''}',
        durationMinutes: (j['durationMinutes'] as num?)?.toInt() ?? 0,
        price: (j['price'] as num?)?.round() ?? 0,
      );

  String get durationLabel {
    final h = durationMinutes ~/ 60, m = durationMinutes % 60;
    if (h == 0) return '$m min';
    return m == 0 ? '$h hr' : '$h hr $m min';
  }
}

class CourtSlots {
  final String courtId;
  final String courtName;
  final String venueName;
  final List<BookableSlot> slots;
  const CourtSlots(
      {required this.courtId,
      required this.courtName,
      required this.venueName,
      required this.slots});

  factory CourtSlots.fromJson(Map<String, dynamic> j) => CourtSlots(
        courtId: '${j['courtId'] ?? ''}',
        courtName: '${j['courtName'] ?? ''}',
        venueName: '${j['venueName'] ?? ''}',
        slots: ((j['slots'] as List?) ?? [])
            .map((e) => BookableSlot.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
