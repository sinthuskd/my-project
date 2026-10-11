/// 5500 -> "LKR 5,500.00"
String fmtLkr(num v) {
  final parts = v.toStringAsFixed(2).split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return 'LKR $whole.${parts[1]}';
}

/// 4200 -> "4.2k", 350 -> "350"
String fmtCompact(num v) =>
    v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0);

/// 9-digit national number "771234567" -> "77 123 4567"
String fmtNational(String nine) {
  final d = nine.replaceAll(RegExp(r'\D'), '');
  if (d.length != 9) return nine;
  return '${d.substring(0, 2)} ${d.substring(2, 5)} ${d.substring(5)}';
}

/// "+94771234567" -> "+94 77 123 4567"
String fmtPhoneE164(String p) {
  final d = p.replaceAll(RegExp(r'\D'), '');
  if (d.length < 9) return p;
  return '+94 ${fmtNational(d.substring(d.length - 9))}';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String fmtMonthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';
