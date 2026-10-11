import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

const kBlue = AppColors.primary;
const kBg = AppColors.background;
const kInk = AppColors.textDark;
final kScreens = <MapEntry<String, WidgetBuilder>>[];

/// Logged-in user's name for screens (guest -> 'You').
String get kMeFirst => AuthService.user.value?.firstName ?? 'You';
String get kMeFull => AuthService.user.value?.fullName ?? 'You';
String get kMeShort => AuthService.user.value?.shortName ?? 'You';
num get kMeWallet => AuthService.user.value?.walletBalance ?? 0;
void Function(BuildContext, int)? kOnPlayerTab;
const kOpsIdx = [28, 29, 30, 31, 33];

/// Wrap MainShell body with this so flow screens hide their own bottom nav.
class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required super.child});
  @override
  bool updateShouldNotify(ShellScope o) => false;
}

void goScreen(BuildContext c, int i) =>
    Navigator.push(c, MaterialPageRoute(builder: kScreens[i].value));

class Scr extends StatelessWidget {
  final String title;
  final List<Widget> body;
  final Widget? bottom;
  final int? tab;
  final bool ops;
  const Scr(this.title, this.body, {super.key, this.bottom, this.tab, this.ops = false});
  @override
  Widget build(BuildContext c) {
    final d = ops
        ? const [['Radar', Icons.radar], ['Scanner', Icons.qr_code_scanner], ['Schedule', Icons.calendar_today], ['Incidents', Icons.flag], ['Ledger', Icons.receipt_long]]
        : const [['Courts', Icons.grid_view], ['Search', Icons.search], ['Bookings', Icons.calendar_month], ['Partners', Icons.people], ['Profile', Icons.person]];
    final embedded = c.getInheritedWidgetOfExactType<ShellScope>() != null;
    return Scaffold(
      appBar: AppBar(backgroundColor: kBg, title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(padding: const EdgeInsets.all(16), children: body),
      bottomNavigationBar: bottom != null
          ? Padding(padding: const EdgeInsets.all(16), child: bottom)
          : tab != null && !embedded
              ? NavigationBar(
                  selectedIndex: tab!,
                  onDestinationSelected: (i) {
                    if (ops) {
                      Navigator.pushReplacement(c, MaterialPageRoute(builder: kScreens[kOpsIdx[i]].value));
                    } else {
                      kOnPlayerTab?.call(c, i);
                    }
                  },
                  destinations: [for (final x in d) NavigationDestination(icon: Icon(x[1] as IconData), label: x[0] as String)])
              : null,
    );
  }
}

Widget H(String t, [String? s]) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kInk)),
      if (s != null) Text(s, style: const TextStyle(color: Colors.black54)),
    ]));

Widget Cd(List<Widget> k, {Color? c}) => Card(
    color: c ?? Colors.white,
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: k)));

Widget Pl(String t, {bool on = false}) => Chip(
    label: Text(t),
    backgroundColor: on ? kBlue : const Color(0xFFE8ECFF),
    labelStyle: TextStyle(color: on ? Colors.white : kInk),
    side: BorderSide.none);

Widget Wr(List<String> t, [int sel = 0]) => Wrap(spacing: 8, children: [for (var i = 0; i < t.length; i++) Pl(t[i], on: i == sel)]);

Widget Kv(String k, String v, {bool b = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Flexible(child: Text(k)),
      Text(v, style: TextStyle(fontWeight: b ? FontWeight.w800 : FontWeight.w500)),
    ]));

Widget In(String l, String h, {bool obs = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
        obscureText: obs,
        decoration: InputDecoration(labelText: l, hintText: h, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))));

Widget Tg(String t, String s, [bool on = true]) =>
    SwitchListTile(value: on, onChanged: (_) {}, title: Text(t), subtitle: Text(s), contentPadding: EdgeInsets.zero);

Widget Btn(BuildContext c, String t, {int? to, bool red = false}) => SizedBox(
    width: double.infinity,
    child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: red ? Colors.red.shade700 : kBlue, minimumSize: const Size.fromHeight(52)),
        onPressed: () => to == null ? Navigator.maybePop(c) : Navigator.push(c, MaterialPageRoute(builder: kScreens[to].value)),
        child: Text(t)));

Widget Vc(BuildContext c, String n, String loc, String price, String r, String slot) =>
    Cd([Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(n, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), Text('★ $r')]), Text(loc), const SizedBox(height: 6), Kv('Next available', slot), Kv('Rate', price, b: true), Btn(c, 'Book Slot', to: 11)]);

class ScreenGallery extends StatelessWidget {
  const ScreenGallery({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('All 34 screens')),
        body: ListView.builder(
          itemCount: kScreens.length,
          itemBuilder: (c, i) => ListTile(
            leading: CircleAvatar(child: Text('${i + 1}')),
            title: Text(kScreens[i].key),
            onTap: () => goScreen(c, i),
          ),
        ),
      );
}
