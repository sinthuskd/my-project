import 'package:flutter/material.dart';
import '../models/venue.dart';
import '../screens/digital_match_pass_screen.dart';
import '../screens/location_permission_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_shell.dart';
import '../screens/my_bookings_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/register_screen.dart';
import '../screens/search_filter_screen.dart';
import '../screens/venue_detail_screen.dart';
import '../screens/wallet_screen.dart';
import '../screens/welcome_screen.dart';
import '../utils/routes.dart';
import 'flow_screens.dart';
import 'flow_ui.dart';

/// Registers all 34 screens. Screens you already built replace my versions
/// at the same position, so the remaining screens link into your real ones.
void registerFlow() {
  if (kScreens.isNotEmpty) return;
  registerScreens();
  void use(int i, WidgetBuilder b) => kScreens[i] = MapEntry(kScreens[i].key, b);
  use(0, (_) => const WelcomeScreen());
  for (final i in [1, 2, 3]) {
    use(i, (_) => const OnboardingScreen());
  }
  use(4, (_) => const LoginScreen());
  use(5, (_) => const RegisterScreen());
  use(6, (_) => const LocationPermissionScreen());
  use(7, (_) => const MainShell());
  use(8, (_) => const SearchFilterScreen());
  use(11, (_) => VenueDetailScreen(venue: Venue.empty));
  use(16, (_) => const MyBookingsScreen());
  use(17, (_) => const DigitalMatchPassScreen());
  use(19, (_) => const ProfileScreen());
  use(25, (_) => const WalletScreen());
  kOnPlayerTab = (c, i) => Navigator.of(c).pushAndRemoveUntil(
      fadeRoute(MainShell(initialIndex: i)), (r) => false);
}

/// Opens Select Slot & Court (start of the booking flow).
void openBooking(BuildContext c) => goScreen(c, 12);
