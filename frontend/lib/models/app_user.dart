/// The logged-in user, exactly as returned by the backend (/auth/me, /auth/login ...).
class AppUser {
  final String id;
  final String memberId;
  final String fullName;
  final String email;
  final String phone; // +94XXXXXXXXX
  final bool phoneVerified;
  final String role; // 'user' | 'admin'
  final List<String> sports;
  final String tier;
  final int matchesPlayed;
  final double courtTimeHours;
  final double savedLkr;
  final double? fairplay;
  final double walletBalance;
  final DateTime? createdAt;

  const AppUser({
    required this.id,
    required this.memberId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.phoneVerified,
    this.role = 'user',
    required this.sports,
    required this.tier,
    required this.matchesPlayed,
    required this.courtTimeHours,
    required this.savedLkr,
    required this.fairplay,
    required this.walletBalance,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.first.isEmpty ? 'there' : parts.first;
  }

  /// "Kasun Perera" -> "KP"
  String get initials {
    final parts =
        fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// "Kasun Perera" -> "Kasun P."
  String get shortName {
    final parts =
        fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length < 2) return firstName;
    return '${parts.first} ${parts.last[0].toUpperCase()}.';
  }

  factory AppUser.fromJson(Map<String, dynamic> j) {
    double d(Object? v) => (v as num?)?.toDouble() ?? 0;
    return AppUser(
      id: j['id'].toString(),
      memberId: (j['memberId'] ?? '').toString(),
      fullName: (j['fullName'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
      phone: (j['phone'] ?? '').toString(),
      phoneVerified: j['phoneVerified'] == true,
      role: (j['role'] ?? 'user').toString(),
      sports: ((j['sports'] as List?) ?? const []).map((e) => e.toString()).toList(),
      tier: (j['tier'] ?? 'BRONZE').toString(),
      matchesPlayed: (j['matchesPlayed'] as num?)?.toInt() ?? 0,
      courtTimeHours: d(j['courtTimeHours']),
      savedLkr: d(j['savedLkr']),
      fairplay: (j['fairplay'] as num?)?.toDouble(),
      walletBalance: d(j['walletBalance']),
      createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()),
    );
  }
}
