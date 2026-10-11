import { Injectable } from '@nestjs/common';
import { HttpError } from '../common/http-error';
import { addDays, fmtDuration, fmtTime, fromLocal, isValidDateStr, localDate, MINUTE } from '../common/time';
import { Db } from '../db/db.service';
import { bad, intParam, isUuid } from './admin.util';

const BOOKING_SELECT = `
  SELECT b.*, c.name AS court_name, c.sport, v.name AS venue_name, u.full_name AS user_name, u.email AS user_email, u.phone AS user_phone
  FROM bookings b
  JOIN courts c ON c.id = b.court_id
  JOIN venues v ON v.id = b.venue_id
  JOIN users u ON u.id = b.user_id`;

/** confirmed bookings whose end time passed count as completed (the user-side job settles them later) */
const effectiveStatus = (r: any) => (r.status === 'confirmed' && new Date(r.end_at) <= new Date() ? 'completed' : r.status);

const bookingDto = (r: any) => {
  const start = new Date(r.start_at);
  const end = new Date(r.end_at);
  const minutes = Math.round((end.getTime() - start.getTime()) / MINUTE);
  return {
    id: r.id,
    ref: r.ref,
    slotId: r.slot_id,
    status: effectiveStatus(r),
    paymentMethod: r.payment_method,
    paymentStatus: r.payment_status,
    totalLkr: r.total_lkr,
    date: localDate(start),
    timeSlot: `${fmtTime(start, true)} – ${fmtTime(end, true)}`,
    startAt: start.toISOString(),
    endAt: end.toISOString(),
    duration: fmtDuration(minutes),
    court: { id: r.court_id, name: r.court_name, sport: r.sport },
    venue: { id: r.venue_id, name: r.venue_name },
    user: { id: r.user_id, name: r.user_name, email: r.user_email, phone: r.user_phone },
    createdAt: new Date(r.created_at).toISOString(),
  };
};

/** Admin dashboard numbers, bookings management and the customer list. */
@Injectable()
export class AdminOpsService {
  constructor(private readonly db: Db) {}

  /* ------------------------------ dashboard ------------------------------ */

  async dashboard() {
    const now = new Date();
    const today = localDate(now);
    const dayStart = fromLocal(today, 0);
    const dayEnd = fromLocal(addDays(today, 1), 0);
    const weekStart = fromLocal(addDays(today, -6), 0);

    const [counts, slots, bookings, money, week, recent, todays, top] = await Promise.all([
      this.db.one(
        `SELECT (SELECT count(*) FROM venues) AS venues, (SELECT count(*) FROM venues WHERE active) AS active_venues,
                (SELECT count(*) FROM courts) AS courts, (SELECT count(*) FROM sports) AS sports,
                (SELECT count(*) FROM users WHERE role = 'user') AS customers`),
      this.db.one(
        `SELECT count(*) FILTER (WHERE b.id IS NULL) AS open, count(*) FILTER (WHERE b.id IS NOT NULL) AS booked
         FROM court_slots s
         LEFT JOIN LATERAL (SELECT bk.id FROM bookings bk
            WHERE bk.court_id = s.court_id AND bk.status <> 'cancelled' AND bk.start_at < s.end_at AND bk.end_at > s.start_at LIMIT 1) b ON true
         WHERE s.active AND s.start_at > $1`, [now]),
      this.db.one(
        `SELECT count(*) FILTER (WHERE start_at >= $1 AND start_at < $2 AND status <> 'cancelled') AS today,
                count(*) FILTER (WHERE status = 'confirmed' AND end_at > $3) AS upcoming,
                count(*) FILTER (WHERE status = 'completed' OR (status = 'confirmed' AND end_at <= $3)) AS completed,
                count(*) FILTER (WHERE status = 'cancelled') AS cancelled,
                count(*) AS total
         FROM bookings`, [dayStart, dayEnd, now]),
      this.db.one(
        `SELECT COALESCE(sum(total_lkr) FILTER (WHERE status <> 'cancelled' AND payment_status = 'paid'), 0) AS collected,
                COALESCE(sum(total_lkr) FILTER (WHERE status <> 'cancelled' AND payment_status = 'pending'), 0) AS pay_at_venue,
                COALESCE(sum(total_lkr) FILTER (WHERE status <> 'cancelled' AND start_at >= $1 AND start_at < $2), 0) AS today
         FROM bookings`, [dayStart, dayEnd]),
      this.db.query(
        `SELECT (start_at AT TIME ZONE 'Asia/Colombo')::date::text AS day, count(*) AS bookings, COALESCE(sum(total_lkr), 0) AS revenue
         FROM bookings WHERE status <> 'cancelled' AND start_at >= $1 AND start_at < $2 GROUP BY 1`, [weekStart, dayEnd]),
      this.db.query(`${BOOKING_SELECT} ORDER BY b.created_at DESC LIMIT 10`),
      this.db.query(`${BOOKING_SELECT} WHERE b.start_at >= $1 AND b.start_at < $2 AND b.status <> 'cancelled' ORDER BY b.start_at`, [dayStart, dayEnd]),
      this.db.query(
        `SELECT v.id, v.name, count(b.id) AS bookings, COALESCE(sum(b.total_lkr), 0) AS revenue
         FROM venues v JOIN bookings b ON b.venue_id = v.id AND b.status <> 'cancelled'
         GROUP BY v.id, v.name ORDER BY bookings DESC, revenue DESC LIMIT 5`),
    ]);

    const byDay = new Map(week.rows.map((r) => [r.day as string, r]));
    const last7Days = Array.from({ length: 7 }, (_, i) => {
      const day = addDays(today, i - 6);
      const r = byDay.get(day);
      return { date: day, bookings: r?.bookings ?? 0, revenue: r?.revenue ?? 0 };
    });

    return {
      generatedAt: now.toISOString(),
      totals: {
        facilities: counts!.venues, activeFacilities: counts!.active_venues, courts: counts!.courts,
        sports: counts!.sports, customers: counts!.customers,
      },
      slots: { upcomingOpen: slots!.open, upcomingBooked: slots!.booked },
      bookings: {
        today: bookings!.today, upcoming: bookings!.upcoming, completed: bookings!.completed,
        cancelled: bookings!.cancelled, total: bookings!.total,
      },
      revenueLkr: { collected: money!.collected, payAtVenuePending: money!.pay_at_venue, today: money!.today },
      last7Days,
      todaysBookings: todays.rows.map(bookingDto),
      recentBookings: recent.rows.map(bookingDto),
      topFacilities: top.rows.map((r) => ({ id: r.id, name: r.name, bookings: r.bookings, revenueLkr: r.revenue })),
    };
  }

  /* ------------------------------ bookings ------------------------------ */

  /** ?status=confirmed|completed|cancelled &venueId= &courtId= &date= &q= (ref / name / email / phone) &limit= &offset= */
  async listBookings(q: Record<string, string>) {
    const where: string[] = [];
    const p: unknown[] = [];
    const add = (v: unknown) => { p.push(v); return `$${p.length}`; };

    if (q.venueId) where.push(`b.venue_id = ${add(q.venueId)}`);
    if (q.courtId) where.push(`b.court_id = ${add(q.courtId)}`);
    if (q.date) {
      if (!isValidDateStr(q.date)) throw bad('date must be YYYY-MM-DD');
      where.push(`b.start_at >= ${add(fromLocal(q.date, 0))} AND b.start_at < ${add(fromLocal(addDays(q.date, 1), 0))}`);
    }
    if (q.status) {
      if (q.status === 'confirmed') where.push(`b.status = 'confirmed' AND b.end_at > now()`);
      else if (q.status === 'completed') where.push(`(b.status = 'completed' OR (b.status = 'confirmed' AND b.end_at <= now()))`);
      else if (q.status === 'cancelled') where.push(`b.status = 'cancelled'`);
      else throw bad('status must be confirmed, completed or cancelled');
    }
    if (q.q?.trim()) {
      const like = add(`%${q.q.trim().toLowerCase()}%`);
      where.push(`lower(b.ref || ' ' || u.full_name || ' ' || u.email || ' ' || u.phone) LIKE ${like}`);
    }

    const limit = intParam(q.limit, 50, 1, 200);
    const offset = intParam(q.offset, 0, 0, 1_000_000);
    const cond = where.length ? `WHERE ${where.join(' AND ')}` : '';
    const total = (await this.db.one(
      `SELECT count(*) AS n FROM bookings b JOIN users u ON u.id = b.user_id ${cond}`, p))!.n as number;
    const rows = (await this.db.query(
      `${BOOKING_SELECT} ${cond} ORDER BY b.start_at DESC LIMIT ${limit} OFFSET ${offset}`, p)).rows;
    return { total, limit, offset, items: rows.map(bookingDto) };
  }

  async getBooking(id: string) {
    const r = isUuid(id) ? (await this.db.query(`${BOOKING_SELECT} WHERE b.id = $1`, [id])).rows[0] : undefined;
    if (!r) throw new HttpError(404, 'Booking not found');
    const players = (await this.db.query(
      `SELECT name, ready, is_host FROM booking_players WHERE booking_id=$1 ORDER BY is_host DESC, created_at`, [id])).rows;
    return { ...bookingDto(r), pin: r.pin, session: r.session_code, lockers: r.lockers, maxPlayers: r.max_players,
      players: players.map((x) => ({ name: x.name, ready: x.ready, isHost: x.is_host })) };
  }

  /** Admin can cancel any upcoming booking at any time. Wallet payments are refunded to the customer. */
  async cancelBooking(id: string) {
    if (!isUuid(id)) throw new HttpError(404, 'Booking not found');
    await this.db.tx(async (c) => {
      const b = (await c.query(`SELECT * FROM bookings WHERE id=$1 FOR UPDATE`, [id])).rows[0];
      if (!b) throw new HttpError(404, 'Booking not found');
      if (b.status === 'cancelled') throw new HttpError(409, 'Booking is already cancelled');
      if (b.status === 'completed' || new Date(b.end_at) <= new Date()) throw bad('This booking is already over');
      let payment = b.payment_status;
      if (b.payment_status === 'paid') {
        const u = (await c.query(
          `UPDATE users SET wallet_balance = wallet_balance + $2 WHERE id=$1 RETURNING wallet_balance`, [b.user_id, b.total_lkr])).rows[0];
        await c.query(
          `INSERT INTO wallet_transactions(user_id,amount,kind,booking_id,note,balance_after) VALUES ($1,$2,'refund',$3,$4,$5)`,
          [b.user_id, b.total_lkr, id, `Refund ${b.ref} (cancelled by venue)`, u.wallet_balance]);
        payment = 'refunded';
      }
      await c.query(`UPDATE bookings SET status='cancelled', payment_status=$2, cancelled_at=now() WHERE id=$1`, [id, payment]);
    });
    return this.getBooking(id);
  }

  /* ------------------------------ customers (read only) ------------------------------ */

  async listUsers(q: Record<string, string>) {
    const p: unknown[] = [];
    let cond = `WHERE u.role = 'user'`;
    if (q.q?.trim()) { p.push(`%${q.q.trim().toLowerCase()}%`); cond += ` AND lower(u.full_name || ' ' || u.email || ' ' || u.phone) LIKE $1`; }
    const limit = intParam(q.limit, 50, 1, 200);
    const offset = intParam(q.offset, 0, 0, 1_000_000);
    const total = (await this.db.one(`SELECT count(*) AS n FROM users u ${cond}`, p))!.n as number;
    const rows = (await this.db.query(
      `SELECT u.id, u.full_name, u.email, u.phone, u.phone_verified, u.wallet_balance, u.created_at,
              (SELECT count(*) FROM bookings b WHERE b.user_id = u.id AND b.status <> 'cancelled') AS bookings
       FROM users u ${cond} ORDER BY u.created_at DESC LIMIT ${limit} OFFSET ${offset}`, p)).rows;
    return {
      total, limit, offset,
      items: rows.map((u) => ({
        id: u.id, fullName: u.full_name, email: u.email, phone: u.phone, phoneVerified: u.phone_verified,
        walletBalance: u.wallet_balance, bookings: u.bookings, joinedAt: new Date(u.created_at).toISOString(),
      })),
    };
  }
}
