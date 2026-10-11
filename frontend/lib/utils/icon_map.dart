import 'package:flutter/material.dart';

/// Backend stores icons as plain names (sports.icon, venue_amenities.icon ...).
/// This turns a name such as "sports_tennis" into a Flutter icon.
/// Add more names here if the admin uses other icons.
const Map<String, IconData> _icons = {
  'sports': Icons.sports,
  'sports_tennis': Icons.sports_tennis,
  'sports_basketball': Icons.sports_basketball,
  'sports_soccer': Icons.sports_soccer,
  'sports_cricket': Icons.sports_cricket,
  'sports_volleyball': Icons.sports_volleyball,
  'sports_handball': Icons.sports_handball,
  'sports_baseball': Icons.sports_baseball,
  'sports_golf': Icons.sports_golf,
  'sports_hockey': Icons.sports_hockey,
  'sports_rugby': Icons.sports_rugby,
  'sports_football': Icons.sports_football,
  'sports_kabaddi': Icons.sports_kabaddi,
  'sports_martial_arts': Icons.sports_martial_arts,
  'sports_gymnastics': Icons.sports_gymnastics,
  'sports_score': Icons.sports_score,
  'fitness_center': Icons.fitness_center,
  'local_parking': Icons.local_parking,
  'parking': Icons.local_parking,
  'shower': Icons.shower_outlined,
  'ac_unit': Icons.ac_unit,
  'wifi': Icons.wifi,
  'wc': Icons.wc,
  'restaurant': Icons.restaurant,
  'local_cafe': Icons.local_cafe,
  'local_drink': Icons.local_drink,
  'water_drop': Icons.water_drop_outlined,
  'lock': Icons.lock_outline,
  'checkroom': Icons.checkroom,
  'lightbulb': Icons.lightbulb_outline,
  'light_mode': Icons.light_mode,
  'wb_sunny': Icons.wb_sunny_outlined,
  'roofing': Icons.roofing,
  'apartment': Icons.apartment,
  'directions_walk': Icons.directions_walk,
  'medical_services': Icons.medical_services_outlined,
  'videocam': Icons.videocam_outlined,
  'security': Icons.shield_outlined,
  'star': Icons.star_outline,
  'info': Icons.info_outline,
};

IconData iconFromName(String? name, {IconData fallback = Icons.info_outline}) {
  if (name == null) return fallback;
  return _icons[name.trim().toLowerCase()] ?? fallback;
}
