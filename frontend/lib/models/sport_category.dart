import 'package:flutter/material.dart';
import '../utils/icon_map.dart';

class SportCategory {
  final String name;
  final int venues;
  final IconData icon;
  const SportCategory(this.name, this.venues, this.icon);

  /// GET /categories -> [{name, venues, icon}]
  factory SportCategory.fromJson(Map<String, dynamic> j) => SportCategory(
        '${j['name'] ?? ''}',
        (j['venues'] as num?)?.toInt() ?? 0,
        iconFromName('${j['icon'] ?? ''}', fallback: Icons.sports),
      );
}
