import { Injectable } from '@nestjs/common';
import { randomInt } from 'crypto';
import { HttpError } from '../common/http-error';
import { fmtDuration, fmtTime, localDate, localHM, MINUTE } from '../common/time';
import { Db } from '../db/db.service';

const CANCEL_BEFORE_MS = 2 * 60 * MINUTE;
const bad = (m: string) => new HttpError(400, m);

const initials = (name: string) => {
  const p = name.trim().split(/\s+/).filter(Boolean);
  if (!p.length) return '?';
  return (p.length === 1 ? p[0][0] : p[0][0] + p[p.length - 1][0]).toUpperCase();
};

const SELECT_BOOKING = `
  SELECT b.*, c.name AS court_name, c.sport, c.surface, c.environment, v.name AS venue_name,
         v.address AS venue_address, v.gate, u.full_name AS host_name
  FROM bookings b
  JOIN courts c ON c.id = b.court_id
  JOIN venues v ON v.id = b.venue_id
  JOIN users u ON u.id = b.user_id`;

@Injectable()
export class BookingsService {
  constructor(private readonly db: Db) {}

  /* ------------------------------ create ------------------------------ */

  /**
   * Books one admin-created slot. Body: {slotId, paymentMethod:"wallet"|"pay_at_venue", maxPlayers?}
   * Time and price come from the slot itself, so the user cannot book anything the admin did not publish.
   */
  async create(userId: string, body: unknown) {
    const b = (typeof body === 'object' && body !== null ? body : {}) as Record<string, unknown>;
    const slotId = typeof b.slotId === 'string' ? b.slotId : '';
    const method = (b.paymentMethod ?? 'wallet') as string;
    const maxPlayers = Number(b.maxPlayers ?? 4);

    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(slotId)) throw bad('slotId is required (pick a slot from /courts/:id/slots or /listings)');
    if (!['wallet', 'pay_at_venue'].includes(method)) throw bad('paymentMethod must be wallet or pay_at_venue');
    if (!Number.isInteger(maxPlayers) || maxPlayers < 1 || maxPlayers > 10) throw bad('maxPlayers must be 1-10');

    const id = await this.db.tx(async (c) => {
      // Lock the slot row: two people booking the same slot queue up here, so no double booking.
      const slot = (await c.query(
        `SELECT s.id, s.court_id, s.start_at, s.end_at, s.price, ct.name AS court_name, ct.price AS court_price, ct.venue_id
         FROM court_slots s
         JOIN courts ct ON ct.id = s.court_id
         JOIN venues v ON v.id = ct.venue_id
         WHERE s.id = $1 AND s.active AND ct.active AND v.active
         FOR UPDATE OF s`, [slotId])).rows[0];
      if (!slot) throw new HttpError(404, 'Slot not found or no longer available');

      const start = new Date(slot.start_at);
      const end = new Date(slot.end_at);
      if (start <= new Date()) throw bad('That time has already passed');

      const clash = await c.query(
        `SELECT 1 FROM bookings WHERE court_id=$1 AND status <> 'cancelled' AND start_at < $3 AND end_at > $2 LIMIT 1`,
        [slot.court_id, start, end]);
      if (clash.rowCount) throw new HttpError(409, 'Sorry, that slot was just booked. Please pick another one.');

      const minutes = Math.round((end.getTime() - start.getTime()) / MINUTE);
      const price = slot.price as number;
      const basePrice = Math.round(((slot.court_price as number) * minutes) / 60);

      const user = (await c.query(`SELECT id, full_name, phone_verified, wallet_balance FROM users WHERE id=$1 FOR UPDATE`, [userId])).rows[0];
      if (!user) throw new HttpError(401, 'Account no longer exists');
      if (!user.phone_verified) throw new HttpError(403, 'Verify your mobile number first');

      let payment: 'paid' | 'pending' = 'pending';
      let balanceAfter = user.wallet_balance as number;
      if (method === 'wallet') {
        if (user.wallet_balance < price) {
          throw new HttpError(402, `Insufficient wallet balance. You need LKR ${price} but have LKR ${user.wallet_balance}.`, {
            code: 'INSUFFICIENT_BALANCE', required: price, balance: user.wallet_balance,
          });
        }
        balanceAfter = Math.round((user.wallet_balance - price) * 100) / 100;
        await c.query(`UPDATE users SET wallet_balance=$2 WHERE id=$1`, [userId, balanceAfter]);
        payment = 'paid';
      }

      const seq = (await c.query(`SELECT nextval('booking_ref_seq') AS n`)).rows[0].n as number;
      const locker = randomInt(1, 40);
      const ins = await c.query(
        `INSERT INTO bookings(ref,user_id,court_id,venue_id,slot_id,start_at,end_at,total_lkr,saved_lkr,payment_method,payment_status,pin,session_code,lockers,max_players)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15) RETURNING id`,
        [`#SB-COL-${seq}`, userId, slot.court_id, slot.venue_id, slot.id, start, end, price, Math.max(0, basePrice - price), method, payment,
         String(randomInt(0, 10000)).padStart(4, '0'), `#${seq}-${initials(user.full_name)[0]}`,
         `#${locker} & #${locker + 1}`, maxPlayers],
      );
      const bookingId = ins.rows[0].id as string;

      await c.query(`INSERT INTO booking_players(booking_id,user_id,name,is_host) VALUES ($1,$2,$3,true)`, [bookingId, userId, user.full_name]);
      if (method === 'wallet') {
        await c.query(
          `INSERT INTO wallet_transactions(user_id,amount,kind,booking_id,note,balance_after) VALUES ($1,$2,'booking',$3,$4,$5)`,
          [userId, -price, bookingId, `Booking ${slot.court_name}`, balanceAfter]);
      }
      return bookingId;
    });

    return this.get(userId, id);
  }

  /* ------------------------------ read ------------------------------ */

  async list(userId: string, scope: string) {
    await this.settleFinished(userId);
    const cond =
      scope === 'upcoming' ? `AND b.status='confirmed' AND b.end_at > now()`
      : scope === 'past' ? `AND (b.status <> 'confirmed' OR b.end_at <= now())`
      : '';
    const order = scope === 'upcoming' ? 'ASC' : 'DESC';
    const rows = (await this.db.query(`${SELECT_BOOKING} WHERE b.user_id=$1 ${cond} ORDER BY b.start_at ${order} LIMIT 100`, [userId])).rows;
    return Promise.all(rows.map((r) => this.dto(r, userId)));
  }

  async get(userId: string, id: string) {
    const row = await this.row(userId, id);
    return this.dto(row, userId);
  }

  /** Data for the Digital Match Pass screen (shape of the Flutter `MatchPass`). */
  async pass(userId: string, id: string) {
    const row = await this.row(userId, id);
    return this.passDto(await this.dto(row, userId), row.host_name);
  }

  /** The pass the app shows by default: the soonest booking that has not finished yet. */
  async nextPass(userId: string) {
    const r = (await this.db.query(
      `${SELECT_BOOKING} WHERE b.user_id=$1 AND b.status='confirmed' AND b.end_at > now() ORDER BY b.start_at LIMIT 1`, [userId])).rows[0];
    if (!r) throw new HttpError(404, 'You have no upcoming bookings');
    return this.passDto(await this.dto(r, userId), r.host_name);
  }

  /* ------------------------------ cancel ------------------------------ */

  async cancel(userId: string, id: string) {
    await this.db.tx(async (c) => {
      const b = (await c.query(`SELECT * FROM bookings WHERE id=$1 AND user_id=$2 FOR UPDATE`, [id, userId])).rows[0];
      if (!b) throw new HttpError(404, 'Booking not found');
      if (b.status === 'cancelled') throw new HttpError(409, 'Booking is already cancelled');
      if (b.status === 'completed' || new Date(b.end_at) <= new Date()) throw bad('This booking is already over');
      if (new Date(b.start_at).getTime() - Date.now() < CANCEL_BEFORE_MS) {
        throw bad('Free cancellation is only available up to 2 hours before the start time');
      }
      let payment = b.payment_status;
      if (b.payment_status === 'paid') {
        const u = (await c.query(
          `UPDATE users SET wallet_balance = wallet_balance + $2 WHERE id=$1 RETURNING wallet_balance`, [userId, b.total_lkr])).rows[0];
        await c.query(
          `INSERT INTO wallet_transactions(user_id,amount,kind,booking_id,note,balance_after) VALUES ($1,$2,'refund',$3,$4,$5)`,
          [userId, b.total_lkr, id, `Refund ${b.ref}`, u.wallet_balance]);
        payment = 'refunded';
      }
      await c.query(`UPDATE bookings SET status='cancelled', payment_status=$2, cancelled_at=now() WHERE id=$1`, [id, payment]);
    });
    return this.get(userId, id);
  }

  /* ------------------------------ players ------------------------------ */

  async addPlayer(userId: string, id: string, body: unknown) {
    const b = (typeof body === 'object' && body !== null ? body : {}) as Record<string, unknown>;
    const name = typeof b.name === 'string' ? b.name.trim() : '';
    if (name.length < 1 || name.length > 60) throw bad('Enter the player name');
    await this.db.tx(async (c) => {
      const bk = (await c.query(`SELECT * FROM bookings WHERE id=$1 AND user_id=$2 FOR UPDATE`, [id, userId])).rows[0];
      if (!bk) throw new HttpError(404, 'Booking not found');
      if (bk.status !== 'confirmed') throw bad('Only confirmed bookings can have players');
      const n = (await c.query(`SELECT count(*) AS n FROM booking_players WHERE booking_id=$1`, [id])).rows[0].n as number;
      if (n >= bk.max_players) throw new HttpError(409, `This booking is full (${bk.max_players} players)`);
      await c.query(`INSERT INTO booking_players(booking_id,name,ready) VALUES ($1,$2,$3)`, [id, name, b.ready !== false]);
    });
    return this.get(userId, id);
  }

  async removePlayer(userId: string, id: string, playerId: string) {
    await this.row(userId, id);
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(playerId)) throw new HttpError(404, 'Player not found');
    const r = await this.db.query(`DELETE FROM booking_players WHERE id=$1 AND booking_id=$2 AND is_host=false`, [playerId, id]);
    if (!r.rowCount) throw new HttpError(404, 'Player not found (the host cannot be removed)');
    return this.get(userId, id);
  }

  /* ------------------------------ stats ------------------------------ */

  /**
   * Bookings whose end time has passed become 'completed' and count towards the user's
   * matches played / court time / money saved. Runs when the profile or bookings are read.
   * Safe to call repeatedly (each booking is settled once).
   */
  async settleFinished(userId: string) {
    const q = this.db;
    const done = (await q.query(
      `UPDATE bookings SET status='completed'
       WHERE user_id=$1 AND status='confirmed' AND end_at <= now()
       RETURNING start_at, end_at, saved_lkr`, [userId])).rows;
    if (!done.length) return;
    const hours = done.reduce((s, r) => s + (new Date(r.end_at).getTime() - new Date(r.start_at).getTime()) / 3_600_000, 0);
    const saved = done.reduce((s, r) => s + Number(r.saved_lkr), 0);
    await q.query(
      `UPDATE users SET matches_played = matches_played + $2, court_time_hours = court_time_hours + $3,
         saved_lkr = saved_lkr + $4 WHERE id=$1`,
      [userId, done.length, Math.round(hours * 100) / 100, saved]);
  }

  /* ------------------------------ helpers ------------------------------ */

  private async row(userId: string, id: string) {
    const ok = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id);
    const r = ok ? (await this.db.query(`${SELECT_BOOKING} WHERE b.id=$1 AND b.user_id=$2`, [id, userId])).rows[0] : undefined;
    if (!r) throw new HttpError(404, 'Booking not found');
    return r;
  }

  private async dto(r: any, viewerId: string) {
    const players = (await this.db.query(
      `SELECT id, user_id, name, ready, is_host FROM booking_players WHERE booking_id=$1 ORDER BY is_host DESC, created_at`, [r.id])).rows;
    const start = new Date(r.start_at);
    const end = new Date(r.end_at);
    const minutes = Math.round((end.getTime() - start.getTime()) / MINUTE);
    const cancellableUntil = new Date(start.getTime() - CANCEL_BEFORE_MS);
    return {
      id: r.id,
      slotId: r.slot_id,
      ref: r.ref,
      status: r.status,
      paymentMethod: r.payment_method,
      paymentStatus: r.payment_status,
      totalLkr: r.total_lkr,
      savedLkr: r.saved_lkr,
      date: localDate(start),
      startTime: `${String(localHM(start).h).padStart(2, '0')}:${String(localHM(start).m).padStart(2, '0')}`,
      startAt: start.toISOString(),
      endAt: end.toISOString(),
      timeSlot: `${fmtTime(start, true)} – ${fmtTime(end, true)}`,
      durationMinutes: minutes,
      duration: fmtDuration(minutes),
      court: { id: r.court_id, name: r.court_name, sport: r.sport, surface: r.surface, environment: r.environment },
      venue: { id: r.venue_id, name: r.venue_name, address: r.venue_address, gate: r.gate },
      pin: r.pin,
      session: r.session_code,
      lockers: r.lockers,
      maxPlayers: r.max_players,
      players: players.map((p) => ({ id: p.id, name: p.name, ready: p.ready, isHost: p.is_host, isYou: p.user_id === viewerId })),
      canCancel: r.status === 'confirmed' && cancellableUntil.getTime() > Date.now(),
      cancellableUntil: cancellableUntil.toISOString(),
      createdAt: new Date(r.created_at).toISOString(),
    };
  }

  private passDto(b: Awaited<ReturnType<BookingsService['dto']>>, hostName: string) {
    const env = b.court.environment === 'rooftop' ? 'Covered Rooftop' : b.court.environment === 'outdoor' ? 'Outdoor' : 'Indoor';
    return {
      bookingId: b.id,
      status: b.status,
      arena: b.venue.name,
      address: b.venue.address,
      sport: `${b.court.sport} • ${b.court.name}`,
      surface: `${env} ${b.court.surface}`.trim(),
      bookingRef: b.ref,
      timeSlot: b.timeSlot,
      duration: `${b.duration} Duration`,
      gate: b.venue.gate,
      host: hostName,
      playersConfirmed: b.players.length,
      pin: b.pin,
      session: b.session,
      lockers: b.lockers,
      qrData: `SBK|${b.ref}|${b.pin}`,
      roster: b.players.map((p) => ({
        name: p.isYou ? `${p.name.split(/\s+/)[0]} (You)` : p.name.split(/\s+/)[0],
        initials: initials(p.name),
        ready: p.ready,
        isYou: p.isYou,
      })),
    };
  }
}
