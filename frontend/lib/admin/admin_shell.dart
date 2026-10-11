import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../utils/routes.dart';
import 'admin_bookings_screen.dart';
import 'admin_customers_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_facilities_screen.dart';
import 'admin_slots_screen.dart';
import 'admin_sports_screen.dart';
import 'admin_ui.dart';

/// Admin home: bottom navigation Dashboard, Facilities, Slots, Bookings, More.
/// Shown instead of the customer app when an admin logs in.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  Future<void> _logout() async {
    final ok = await confirmDialog(context,
        title: 'Log out', message: 'Log out of the admin panel?', confirmLabel: 'Log out');
    if (!ok) return;
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(fadeRoute(const LoginScreen()), (r) => false);
  }

  Widget _tab() {
    switch (_index) {
      case 0:
        return AdminDashboardScreen(key: const ValueKey('dash'), onOpenTab: (i) => setState(() => _index = i));
      case 1:
        return const AdminFacilitiesScreen(key: ValueKey('fac'));
      case 2:
        return const AdminSlotsScreen(key: ValueKey('slots'));
      case 3:
        return const AdminBookingsScreen(key: ValueKey('book'));
      default:
        return _MoreTab(key: const ValueKey('more'), onLogout: _logout);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(bottom: false, child: _tab()),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: AppColors.textDark.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: NavigationBar(
          backgroundColor: Colors.white,
          elevation: 0,
          indicatorColor: AppColors.chip,
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: AppColors.primary), label: 'Dashboard'),
            NavigationDestination(icon: Icon(Icons.stadium_outlined), selectedIcon: Icon(Icons.stadium, color: AppColors.primary), label: 'Facilities'),
            NavigationDestination(icon: Icon(Icons.schedule_outlined), selectedIcon: Icon(Icons.schedule, color: AppColors.primary), label: 'Slots'),
            NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month, color: AppColors.primary), label: 'Bookings'),
            NavigationDestination(icon: Icon(Icons.more_horiz), selectedIcon: Icon(Icons.more_horiz, color: AppColors.primary), label: 'More'),
          ],
        ),
      ),
    );
  }
}

class _MoreTab extends StatelessWidget {
  final VoidCallback onLogout;
  const _MoreTab({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final u = AuthService.user.value;
    Widget tile(IconData icon, String title, String sub, VoidCallback onTap, {Color? color}) => AdminCard(
          onTap: onTap,
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: (color ?? AppColors.primary).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color ?? AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text(sub, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ]),
        );

    return Scaffold(
      appBar: adminAppBar('More'),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        AdminCard(
          child: Row(children: [
            CircleAvatar(radius: 26, backgroundColor: AppColors.primary, child: Text(u?.initials ?? 'A', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u?.fullName ?? 'Admin', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                Text(u?.email ?? '', style: const TextStyle(color: AppColors.textSecondary)),
              ]),
            ),
            const StatusChip('ADMIN', AppColors.primary),
          ]),
        ),
        const SectionTitle('Manage'),
        tile(Icons.sports_tennis, 'Sports', 'Add or edit the sports customers can pick',
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSportsScreen()))),
        tile(Icons.people_outline, 'Customers', 'See registered customers',
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCustomersScreen()))),
        const SectionTitle('Account'),
        tile(Icons.logout, 'Log out', 'Sign out of the admin panel', onLogout, color: AppColors.danger),
      ]),
    );
  }
}
