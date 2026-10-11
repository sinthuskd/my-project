import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'court_dashboard_screen.dart';
import 'search_filter_screen.dart';
import '../flow/flow_ui.dart';

/// Bottom navigation: Courts, Search, Bookings, Partners, Profile.
class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      CourtDashboardScreen(onOpenSearch: () => setState(() => _index = 1)),
      SearchFilterScreen(onBack: () => setState(() => _index = 0)),
      Builder(builder: kScreens[16].value),
      Builder(builder: kScreens[10].value),
      Builder(builder: kScreens[19].value),
    ];

    return Scaffold(
      body: ShellScope(child: IndexedStack(index: _index, children: tabs)),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: AppColors.textDark.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, -4)),
          ],
        ),
        child: NavigationBar(
          backgroundColor: Colors.white,
          elevation: 0,
          indicatorColor: AppColors.chip,
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon:
                    Icon(Icons.grid_view_rounded, color: AppColors.primary),
                label: 'Courts'),
            NavigationDestination(
                icon: Icon(Icons.search),
                selectedIcon: Icon(Icons.search, color: AppColors.primary),
                label: 'Search'),
            NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month,
                    color: AppColors.primary),
                label: 'Bookings'),
            NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people, color: AppColors.primary),
                label: 'Partners'),
            NavigationDestination(
                icon: Icon(Icons.account_circle_outlined),
                selectedIcon:
                    Icon(Icons.account_circle, color: AppColors.primary),
                label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
