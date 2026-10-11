import 'package:flutter/material.dart';
import '../services/admin_api.dart';
import '../theme/app_colors.dart';
import 'admin_ui.dart';

class AdminDashboardScreen extends StatelessWidget {
  /// Switch the bottom tab (1 facilities, 2 slots, 3 bookings).
  final void Function(int) onOpenTab;
  const AdminDashboardScreen({super.key, required this.onOpenTab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('Dashboard'),
      body: LoadView<Map<String, dynamic>>(
        load: AdminApi.dashboard,
        builder: (context, d, reload) {
          Map<String, dynamic> m(String k) => Map<String, dynamic>.from((d[k] as Map?) ?? {});
          final totals = m('totals');
          final slots = m('slots');
          final bookings = m('bookings');
          final revenue = m('revenueLkr');
          final last7 = ((d['last7Days'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final today = ((d['todaysBookings'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final top = ((d['topFacilities'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final maxB = last7.fold<num>(1, (p, e) => ((e['bookings'] as num?) ?? 0) > p ? (e['bookings'] as num) : p);

          Widget stat(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) => Expanded(
                child: AdminCard(
                  onTap: onTap,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(icon, color: color),
                    const SizedBox(height: 8),
                    Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                  ]),
                ),
              );

          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
              Row(children: [
                stat('Facilities', '${totals['facilities'] ?? 0}', Icons.stadium, AppColors.primary, onTap: () => onOpenTab(1)),
                const SizedBox(width: 10),
                stat('Courts', '${totals['courts'] ?? 0}', Icons.sports_tennis, AppColors.success),
              ]),
              Row(children: [
                stat('Open slots', '${slots['upcomingOpen'] ?? 0}', Icons.schedule, AppColors.warning, onTap: () => onOpenTab(2)),
                const SizedBox(width: 10),
                stat('Booked slots', '${slots['upcomingBooked'] ?? 0}', Icons.event_available, AppColors.primary, onTap: () => onOpenTab(3)),
              ]),
              Row(children: [
                stat('Bookings today', '${bookings['today'] ?? 0}', Icons.today, AppColors.success),
                const SizedBox(width: 10),
                stat('Customers', '${totals['customers'] ?? 0}', Icons.people, AppColors.textSecondary),
              ]),
              const SectionTitle('Revenue'),
              AdminCard(
                child: Column(children: [
                  _row('Collected', lkr(revenue['collected'] as num?)),
                  _row('Today', lkr(revenue['today'] as num?)),
                  _row('Pay at venue (pending)', lkr(revenue['payAtVenuePending'] as num?)),
                ]),
              ),
              const SectionTitle('Bookings'),
              AdminCard(
                child: Column(children: [
                  _row('Upcoming', '${bookings['upcoming'] ?? 0}'),
                  _row('Completed', '${bookings['completed'] ?? 0}'),
                  _row('Cancelled', '${bookings['cancelled'] ?? 0}'),
                  _row('Total', '${bookings['total'] ?? 0}'),
                ]),
              ),
              if (last7.isNotEmpty) ...[
                const SectionTitle('Last 7 days'),
                AdminCard(
                  child: SizedBox(
                    height: 130,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      for (final e in last7)
                        Expanded(
                          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                            Text('${e['bookings'] ?? 0}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Container(
                              height: 8 + 80 * (((e['bookings'] as num?) ?? 0) / maxB).toDouble(),
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                            ),
                            const SizedBox(height: 4),
                            Text(((e['date'] ?? '') as String).length >= 10 ? (e['date'] as String).substring(8) : '',
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ]),
                        ),
                    ]),
                  ),
                ),
              ],
              SectionTitle("Today's bookings", trailing: TextButton(onPressed: () => onOpenTab(3), child: const Text('See all'))),
              if (today.isEmpty)
                const AdminCard(child: Text('No bookings today.', style: TextStyle(color: AppColors.textSecondary)))
              else
                for (final b in today) BookingTile(b: b),
              if (top.isNotEmpty) ...[
                const SectionTitle('Top facilities'),
                for (final f in top)
                  AdminCard(
                    child: Row(children: [
                      Expanded(child: Text('${f['name']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                      Text('${f['bookings']} bookings • ${lkr(f['revenueLkr'] as num?)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ]),
                  ),
              ],
            ]),
          );
        },
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(k, style: const TextStyle(color: AppColors.textSecondary))),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}

/// One booking row (used by the dashboard and the bookings list).
class BookingTile extends StatelessWidget {
  final Map<String, dynamic> b;
  final VoidCallback? onTap;
  const BookingTile({super.key, required this.b, this.onTap});

  @override
  Widget build(BuildContext context) {
    final court = Map<String, dynamic>.from((b['court'] as Map?) ?? {});
    final venue = Map<String, dynamic>.from((b['venue'] as Map?) ?? {});
    final user = Map<String, dynamic>.from((b['user'] as Map?) ?? {});
    final status = '${b['status']}';
    return AdminCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${venue['name']} • ${court['name']}', style: const TextStyle(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
          StatusChip(status.toUpperCase(), statusColor(status)),
        ]),
        const SizedBox(height: 4),
        Text('${b['date']} • ${b['timeSlot']}', style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Row(children: [
          Expanded(child: Text('${user['name']} • ${b['ref']}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13))),
          Text(lkr(b['totalLkr'] as num?), style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}
