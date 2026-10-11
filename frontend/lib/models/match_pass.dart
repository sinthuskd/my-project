import 'app_user.dart';

class RosterPlayer {
  final String name;
  final String initials;
  final bool ready;
  final bool isYou;
  const RosterPlayer(this.name, this.initials,
      {this.ready = true, this.isYou = false});
}

class MatchPass {
  final String arena;
  final String address;
  final String sport;
  final String surface;
  final String bookingRef;
  final String timeSlot;
  final String duration;
  final String gate;
  final String host;
  final int playersConfirmed;
  final String pin;
  final String session;
  final String lockers;
  final List<RosterPlayer> roster;

  const MatchPass({
    required this.arena,
    required this.address,
    required this.sport,
    required this.surface,
    required this.bookingRef,
    required this.timeSlot,
    required this.duration,
    required this.gate,
    required this.host,
    required this.playersConfirmed,
    required this.pin,
    required this.session,
    required this.lockers,
    required this.roster,
  });

  /// Empty pass, shown until the real pass is loaded from the backend (GET /match-pass).
  static const MatchPass empty = MatchPass(
    arena: '',
    address: '',
    sport: '',
    surface: '',
    bookingRef: '',
    timeSlot: '',
    duration: '',
    gate: '',
    host: '',
    playersConfirmed: 0,
    pin: '',
    session: '',
    lockers: '',
    roster: [],
  );

  /// Same pass, but the host / "You" entry is the real logged-in user.
  MatchPass withUser(AppUser? u) => MatchPass(
        arena: arena,
        address: address,
        sport: sport,
        surface: surface,
        bookingRef: bookingRef,
        timeSlot: timeSlot,
        duration: duration,
        gate: gate,
        host: u?.fullName ?? 'Guest',
        playersConfirmed: playersConfirmed,
        pin: pin,
        session: session,
        lockers: lockers,
        roster: [
          for (final r in roster)
            r.isYou
                ? RosterPlayer('${u?.firstName ?? 'You'} (You)',
                    u?.initials ?? 'YO',
                    isYou: true)
                : r,
        ],
      );
}
