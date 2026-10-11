import 'package:flutter/foundation.dart';

/// Bump this after something changes on the server (new booking, cancel, top-up).
/// Screens that are kept alive in the bottom tabs (My Bookings ...) listen to it and reload.
final ValueNotifier<int> dataVersion = ValueNotifier<int>(0);
void notifyDataChanged() => dataVersion.value++;
