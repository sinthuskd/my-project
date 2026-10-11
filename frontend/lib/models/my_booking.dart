/// One booking of the logged-in customer (GET /bookings).
class MyBooking {
  final String id;
  final String ref;
  final String status; // confirmed | cancelled | completed
  final String paymentMethod; // wallet | pay_at_venue
  final String paymentStatus; // paid | pending | refunded
  final int totalLkr;
  final String date; // yyyy-MM-dd
  final String timeSlot;
  final String duration;
  final String courtName;
  final String sport;
  final String venueName;
  final String venueAddress;
  final bool canCancel;

  const MyBooking({
    required this.id,
    required this.ref,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.totalLkr,
    required this.date,
    required this.timeSlot,
    required this.duration,
    required this.courtName,
    required this.sport,
    required this.venueName,
    required this.venueAddress,
    required this.canCancel,
  });

  factory MyBooking.fromJson(Map<String, dynamic> j) {
    final court = Map<String, dynamic>.from((j['court'] as Map?) ?? const {});
    final venue = Map<String, dynamic>.from((j['venue'] as Map?) ?? const {});
    return MyBooking(
      id: '${j['id'] ?? ''}',
      ref: '${j['ref'] ?? ''}',
      status: '${j['status'] ?? ''}',
      paymentMethod: '${j['paymentMethod'] ?? ''}',
      paymentStatus: '${j['paymentStatus'] ?? ''}',
      totalLkr: (j['totalLkr'] as num?)?.round() ?? 0,
      date: '${j['date'] ?? ''}',
      timeSlot: '${j['timeSlot'] ?? ''}',
      duration: '${j['duration'] ?? ''}',
      courtName: '${court['name'] ?? ''}',
      sport: '${court['sport'] ?? ''}',
      venueName: '${venue['name'] ?? ''}',
      venueAddress: '${venue['address'] ?? ''}',
      canCancel: j['canCancel'] == true,
    );
  }

  String get paymentLabel {
    if (paymentStatus == 'refunded') return 'Refunded to wallet';
    if (paymentStatus == 'paid') return 'Paid (wallet)';
    return 'Pay at venue';
  }
}

class WalletTx {
  final double amount; // + credit, - debit
  final String kind; // topup | booking | refund
  final String note;
  final DateTime? createdAt;
  const WalletTx(this.amount, this.kind, this.note, this.createdAt);

  factory WalletTx.fromJson(Map<String, dynamic> j) => WalletTx(
        (j['amount'] as num?)?.toDouble() ?? 0,
        '${j['kind'] ?? ''}',
        '${j['note'] ?? ''}',
        DateTime.tryParse('${j['createdAt'] ?? ''}')?.toLocal(),
      );
}

class WalletInfo {
  final double balance;
  final List<WalletTx> transactions;
  const WalletInfo(this.balance, this.transactions);

  factory WalletInfo.fromJson(Map<String, dynamic> j) => WalletInfo(
        (j['balance'] as num?)?.toDouble() ?? 0,
        ((j['transactions'] as List?) ?? [])
            .map((e) => WalletTx.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Result of POST /payments/otp.
class PaymentOtp {
  final int expiresInSeconds;
  final int resendInSeconds;
  final String? devOtp; // only when the backend runs with OTP_DEV_MODE=true
  const PaymentOtp(this.expiresInSeconds, this.resendInSeconds, this.devOtp);

  factory PaymentOtp.fromJson(Map<String, dynamic> j) => PaymentOtp(
        (j['expiresInSeconds'] as num?)?.toInt() ?? 300,
        (j['resendInSeconds'] as num?)?.toInt() ?? 30,
        j['devOtp']?.toString(),
      );
}
