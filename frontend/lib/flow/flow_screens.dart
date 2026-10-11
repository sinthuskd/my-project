import 'package:flutter/material.dart';
import '../utils/format.dart';
import 'flow_ui.dart';

void _e(String n, Widget Function(BuildContext) b) => kScreens.add(MapEntry(n, b));

/// Empty-state card. These screens have no data yet: it will come from the backend.
Widget _none([String t = 'No data yet.']) =>
    Cd([Text(t, style: const TextStyle(color: Colors.black54))]);

/// Screens 0-8, 11, 17 and 19 are replaced by the real screens in flow_registry.dart,
/// so they only keep their name here (the gallery list needs it).
Widget _real(BuildContext c) => const SizedBox.shrink();

void registerScreens() {
  // 0-3 Onboarding, 4 Login, 5 Registration, 6 Location, 7 Courts (Home), 8 Search Filter
  _e('Onboarding 1', _real);
  _e('Onboarding 2', _real);
  _e('Onboarding 3', _real);
  _e('Onboarding 4', _real);
  _e('Login', _real);
  _e('Registration', _real);
  _e('Location Permission', _real);
  _e('Courts (Home)', _real);
  _e('Search Filter', _real);

  // 9 Search Results
  _e('Search Results', (c) => Scr('Select Your Slot', [H('Available Courts', 'Search results'), _none('No courts found yet.')], tab: 1));

  // 10 Partners
  _e('Find Partners', (c) => Scr('Find Partners', [Cd([const Text('Need a Partner Tonight?', style: TextStyle(fontWeight: FontWeight.w800)), const Text('Broadcast a match beacon to local athletes.'), Btn(c, 'Request a Partner', to: 23)], c: const Color(0xFFDCE6FF)), Wr(['Badminton', 'Tennis', 'Squash']), H('Live Match Hubs'), _none('No live matches yet.'), H('My Friends'), _none('No friends added yet.'), H('Active Racket Clubs'), _none('No clubs yet.')], tab: 3));

  // 11 Venue (real screen)
  _e('Venue & Court Details', _real);

  // 12 Slot, 13 Checkout, 14 Payment, 15 Confirmed
  _e('Select Slot & Court', (c) => Scr('Select Slot & Court', [const Text('STEP 1 OF 4 • Slot & Court Selection'), H('Select a Court', 'Venue and court details will load from the backend.'), const Text('Duration'), Wr(['1.0 Hr', '1.5 Hrs', '2.0 Hrs', '3.0 Hrs'], 2), H('Available Slots'), _none('No slots available yet.')], bottom: Btn(c, 'Continue to Checkout', to: 13)));

  _e('Booking Checkout', (c) => Scr('Booking Checkout', [const Text('STEP 2 OF 4 • Review & Add-ons'), _none('Booking summary will appear here.'), H('Equipment & Add-ons'), _none('No add-ons yet.'), Tg('Split with Friends', 'Share the cost with your team', false), H('Price Summary'), Cd([Kv('Court Rental', '—'), Kv('Gear Rentals', '—'), Kv('Subtotal', '—'), Kv('TOTAL', '—', b: true)])], bottom: Btn(c, 'Proceed to Payment', to: 14)));

  _e('Secure Payment', (c) => Scr('Secure Payment', [const Text('STEP 3 OF 4 • Payment'), H('Payment Methods'), _none('No saved cards yet.'), const ListTile(leading: Icon(Icons.add_card), title: Text('Add New Credit / Debit Card')), H('Venue Counter Payment'), Cd([const Text('Pay at Facility Counter')])], bottom: Btn(c, 'Pay Securely', to: 15)));

  _e('Booking Confirmed', (c) => Scr('Booking Confirmed', [const Icon(Icons.check_circle, color: kBlue, size: 72), H('Booking Confirmed! 🎉'), _none('Your booking details will appear here.'), const ListTile(leading: Icon(Icons.event), title: Text('Add to Apple / Google Calendar')), const ListTile(leading: Icon(Icons.share), title: Text('Share Match Pass with Team')), const ListTile(leading: Icon(Icons.directions), title: Text('Get GPS Directions'))], bottom: Column(mainAxisSize: MainAxisSize.min, children: [Btn(c, 'View in My Bookings', to: 16), TextButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: kScreens[7].value)), child: const Text('Return to Home Dashboard'))])));

  // 16 My Bookings, 17 Match Pass (real screen)
  _e('My Bookings', (c) => Scr('My Bookings', [Wr(['Upcoming', 'Completed', 'Cancelled']), _none('No bookings yet.')], tab: 2));
  _e('Digital Match Pass', _real);

  // 18 Help, 19 Profile (real screen), 20 Notifications
  _e('Help & Support / Report', (c) => Scr('Help & Support', [In('Search', 'Search help topics'), Cd([const Text('Court Ops Hotline', style: TextStyle(fontWeight: FontWeight.w700)), Btn(c, 'Call Now')], c: const Color(0xFFDCE6FF)), Wr(['Chat Marshal', 'WhatsApp', 'Email Us'], -1), H('Report Court or Venue Fault'), Cd([Wr(['Lighting / Floodlights', 'Net / Floor Hazard', 'Ventilation / A/C', 'Turnstile Gate', 'Locker & Shower']), Wr(['Active Game Halted', 'General Maintenance']), OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.add_a_photo), label: const Text('Add Photo of Court Issue')), Btn(c, 'Submit Report to Arena Manager')]), H('FAQ'), const ExpansionTile(title: Text('Court Cancellations & Refund Policy')), const ExpansionTile(title: Text('Non-Marking Shoe Requirements')), const ExpansionTile(title: Text('Split Payment with Teammates')), const ExpansionTile(title: Text('Bad Weather & Rain Guarantee')), const ExpansionTile(title: Text('Digital Match Pass & Gate Scanners'))]));
  // Profile: see lib/screens/profile_screen.dart (real data from the backend)
  _e('Profile', _real);
  _e('Notifications', (c) => Scr('Notifications', [Wr(['All', 'Bookings', 'Reminders', 'Partner']), _none('No notifications yet.')]));

  // 21 Modify, 22 Cancel
  _e('Modify Slot', (c) => Scr('Modify Slot', [_none('Your current reservation will appear here.'), H('Select a New Date & Time Slot'), _none('No slots available yet.'), Cd([const Text('Reschedule Balance Summary'), Kv('Original booking', '—'), Kv('New slot fee', '—'), Kv('Outstanding balance', '—', b: true)])], bottom: Column(mainAxisSize: MainAxisSize.min, children: [Btn(c, 'Confirm Reschedule', to: 16), TextButton(onPressed: () => Navigator.maybePop(c), child: const Text('Keep Original Reservation'))])));

  _e('Cancel Booking', (c) => Scr('Cancel Booking', [_none('Booking details will appear here.'), Cd([const Text('Refund Breakdown'), Kv('Original court fee', '—'), Kv('Cancellation policy fee', '—'), Kv('Total Refund', '—', b: true)]), const Text('Refund destination'), RadioListTile(value: 0, groupValue: 0, onChanged: (_) {}, title: const Text('Original payment method')), RadioListTile(value: 1, groupValue: 0, onChanged: (_) {}, title: const Text('SportsBook Wallet Credit (instant)')), const Text('Reason for cancellation'), for (final r in ['Change of plans / Schedule conflict', 'Teammates unable to attend', 'Injury or health issue', 'Booking mistake', 'Other reason']) RadioListTile(value: r, groupValue: 'Change of plans / Schedule conflict', onChanged: (_) {}, title: Text(r)), const Text('Access Revocation Notice: your gate pass is revoked and squad members are notified.')], bottom: Column(mainAxisSize: MainAxisSize.min, children: [Btn(c, 'Confirm & Cancel Booking', to: 16, red: true), TextButton(onPressed: () => Navigator.maybePop(c), child: const Text('Keep Booking / Go Back'))])));

  // 23 Request Partner, 24 OTP, 25 Wallet
  _e('Request a Partner (Match Beacon)', (c) => Scr('Request Partner', [H('Create Match Beacon', 'Broadcast to verified athletes nearby'), Wr(['Badminton', 'Tennis', 'Squash', 'Padel']), Wr(['Singles (1v1)', 'Doubles (2v2)', 'Any Format']), const Text('Required skill level'), Wr(['Beginner 1.0-2.5', 'Intermediate 3.0-4.0', 'Advanced 4.5+', 'All Welcome'], 1), CheckboxListTile(value: true, onChanged: (_) {}, title: const Text('Verified Athletes Only (90%+ attendance)')), _none('Select a booked court to attach to this beacon.'), const Text('Style & fee sharing'), Wr(['Casual Rally', 'Competitive Ranked']), RadioListTile(value: 0, groupValue: 0, onChanged: (_) {}, title: const Text('50/50 Split')), RadioListTile(value: 1, groupValue: 0, onChanged: (_) {}, title: const Text('Host Pays 100%')), RadioListTile(value: 2, groupValue: 0, onChanged: (_) {}, title: const Text('Bring Shuttles / Balls')), Tg('Auto-Expiry Timer', 'Closes 30 mins before match'), Tg('WhatsApp & SMS Alert', 'Notify on partner accept')], bottom: Btn(c, 'Broadcast Match Beacon', to: 10)));

  _e('OTP Verification', (c) => Scr('Verify Phone', [const Text('STEP 2 OF 2 • Verification'), H('Verify Phone Number', 'Enter the 6-digit token sent via SMS'), Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [for (final d in ['', '', '', '', '', '']) Container(width: 46, height: 56, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Text(d, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)))]), const SizedBox(height: 12), Row(children: [Expanded(child: OutlinedButton(onPressed: () {}, child: const Text('Send via WhatsApp'))), const SizedBox(width: 8), OutlinedButton(onPressed: () {}, child: const Text('Help'))])], bottom: Btn(c, 'Verify & Activate Account', to: 6)));

  _e('Wallet Top-Up', (c) => Scr('Wallet Top-Up', [Cd([const Text('ACTIVE SPORTSBOOK CREDIT'), Text(fmtLkr(kMeWallet), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)), const Text('Instant slot locking')], c: const Color(0xFFDCE6FF)), H('Select Top-Up Amount'), Wr(['LKR 1,000', 'LKR 2,500', 'LKR 5,000', 'LKR 10,000'], 2), In('Custom Recharge Amount', 'LKR'), Wr(['Saved Cards', 'New Card / Bank']), _none('No saved cards yet.'), Cd([const Text('Top-Up Breakdown'), Kv('Top-Up Amount', '—'), Kv('Total Credit', '—', b: true)])], bottom: Btn(c, 'Proceed to Top-Up', to: 19)));

  // 26 Empty states, 27 Review
  _e('Empty States & Offline', (c) => Scr('Search', [Wr(['No Courts', 'Bookings', 'Offline']), const Icon(Icons.location_off, size: 80, color: Colors.red), H('No Courts Found', 'No open slots match your filters.'), Btn(c, 'Reset Filters & Show All Courts', to: 7), H('Constructive Recovery'), Cd([const Text('Broaden Radius'), OutlinedButton(onPressed: () {}, child: const Text('Quick Apply'))]), Cd([const Text('Notify on Cancellation'), OutlinedButton(onPressed: () {}, child: const Text('Notify Me'))])], tab: 1));

  _e('Rate & Review Venue', (c) => Scr('Rate & Review', [_none('Booking details will appear here.'), H('How was your court today?'), Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (_) => const Icon(Icons.star_border, color: kBlue, size: 40))), Kv('Court Surface Quality', '—'), Kv('Lighting & Anti-Glare', '—'), H('What stood out most?'), Wr(['Clean parquet floor', 'Great LED lighting', 'Spacious lockers', 'Clear line markings', 'Fast turnstile QR', 'Slippery mat', 'AC too cold', 'Ample car parking'], -1), const TextField(maxLines: 4, decoration: InputDecoration(labelText: 'Your Match Review', filled: true, fillColor: Colors.white)), Tg('Publish as Verified $kMeShort', 'Boosts your athlete trust score', false)], bottom: Btn(c, 'Submit Review', to: 16)));

  // 28-33 Floor Ops
  _e('Ops - Live Court Radar', (c) => Scr('Floor Ops', [H('Welcome, $kMeFirst', 'Shift not started'), Btn(c, 'Fast Walk-In', to: 32), const SizedBox(height: 8), Cd([Kv('Take today', '—'), Kv('Occupancy', '—'), Kv('Gate scans', '—'), Kv('Hazards', '—')]), H('Court Radar', 'Live'), _none('No courts to show yet.'), H('Access Stream'), _none('No gate activity yet.')], tab: 0, ops: true));

  _e('Ops - Gate Pass Scanner', (c) => Scr('Gate Pass Scanner', [Wr(['Optical Viewfinder', 'Manual Entry PIN']), Container(height: 220, decoration: BoxDecoration(color: kInk, borderRadius: BorderRadius.circular(16)), alignment: Alignment.center, child: const Text('Align dynamic Pass QR inside frame', style: TextStyle(color: Colors.white))), const SizedBox(height: 12), _none('Scan result will appear here.'), Btn(c, 'Manual Unlock Turnstile'), OutlinedButton(onPressed: () {}, child: const Text('Flag Non-Marking Shoes Check'))], tab: 1, ops: true));

  _e('Ops - Court Grid & Pricing', (c) => Scr('Schedule', [_none('Select a court and date to see the schedule.'), Row(children: [Expanded(child: OutlinedButton(onPressed: () {}, child: const Text('Block for Clean'))), const SizedBox(width: 8), Expanded(child: FilledButton(onPressed: () {}, child: const Text('Set Surge Rate')))]), H('Time Slots'), _none('No slots scheduled yet.')], bottom: Btn(c, 'Quick Walk-in Reservation', to: 32), ops: true));

  _e('Ops - Incident & Hazard Desk', (c) => Scr('Incidents', [H('Facility Incident Desk'), Wr(['Active / Halts', 'In Progress', 'Resolved']), _none('No incidents reported.')], tab: 3, ops: true));

  _e('Ops - New Walk-In Booking', (c) => Scr('New Walk In Booking', [H('1 Athlete Identification'), In('Mobile Number', 'Mobile number'), _none('Athlete details will appear here.'), H('2 Court & Time'), Wr(['1.0 hr', '1.5 hrs', '2.0 hrs'], 2), _none('No court allocated yet.'), H('3 Arena Gear & Equipment'), _none('No equipment added.'), H('4 Settlement Method'), RadioListTile(value: 0, groupValue: 0, onChanged: (_) {}, title: const Text('Cash at Counter')), RadioListTile(value: 1, groupValue: 0, onChanged: (_) {}, title: const Text('LankaPay Dynamic QR / POS')), RadioListTile(value: 2, groupValue: 0, onChanged: (_) {}, title: const Text('Athlete Wallet')), Cd([Kv('Court', '—'), Kv('Equipment rental', '—'), Kv('TOTAL', '—', b: true)])], bottom: Column(mainAxisSize: MainAxisSize.min, children: [Btn(c, 'Collect Payment & Generate Gate QR Pass', to: 33), TextButton(onPressed: () {}, child: const Text('Save Draft / Hold Court Slot'))])));

  _e('Ops - Shift Ledger & Payouts', (c) => Scr('Shift Ledger & Payouts', [Cd([const Text('SHIFT REVENUE INTAKE'), const Text('LKR 0', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)), Kv('Cards & LankaPay', '—'), Kv('Athlete Wallet', '—'), Kv('Cash Drawer', '—')]), H('Rain-Check Action'), _none('No pending refunds.'), H('Shift Ingestion Feed', 'Live'), _none('No transactions yet.'), Cd([const Text('Vault Reconciliation Protocol'), Btn(c, 'Reconcile & Close Evening Shift', to: 28)])], tab: 4, ops: true));
}
