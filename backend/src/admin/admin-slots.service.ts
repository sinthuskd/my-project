import { Injectable } from '@nestjs/common';
import { HttpError } from '../common/http-error';
import { addDays, fmt24, fmtTime, fromLocal, isValidDateStr, localDate, MINUTE } from '../common/time';
import { Db } from '../db/db.service';
import { asObject, bad, intParam, isUuid, parseHM, slotPrice, slotRange } from './admin.util';

const MAX_BULK = 500;

const slotDto = (r: any) => {
  const start = new Date(r.start_at);
  const end = new Date(r.end_at);
  const booked = !!r.booking_id;
  return {
    id: r.id,
    courtId: r.court_id,
    courtName: r.court_name,
    sport: r.sport,
    venueId: r.venue_id,
    venueName: r.venue_name,
    date: localDate(start),
    startTime: fmt24(start),
    endTime: fmt24(end),
    timeLabel: `${fmtTime(start, true)} – ${fmtTime(end, true)}`,
    startAt: start.toISOString(),
    endAt: end.toISOString(),
    durationMinutes: Math.round((end.getTime() - start.getTime()) / MINUTE),
    price: r.price,
    active: r.active,
    status: booked ? 'booked' : !r.active ? 'disabled' : start <= new Date() ? 'expired' : 'open',
    booking: booked ? { id: r.booking_id, ref: r.booking_ref, bookedBy: r.booked_by } : null,
  };
};

const SELECT_SLOT = `
  SELECT s.id, s.court_id, s.start_at, s.end_at, s.price, s.active,
         c.name AS court_name, c.sport, v.id AS venue_id, v.name AS venue_name,
         b.id AS booking_id, b.ref AS booking_ref, u.full_name AS booked_by
  FROM court_slots s
  JOIN courts c ON c.id = s.court_id
  JOIN venues v ON v.id = c.venue_id
  LEFT JOIN LATERAL (
    SELECT bk.id, bk.ref, bk.user_id FROM bookings bk
    WHERE bk.court_id = s.court_id AND bk.status <> 'cancelled' AND bk.start_at < s.end_at AND bk.end_at > s.start_at
    ORDER BY bk.created_at LIMIT 1) b ON true
  LEFT JOIN users u ON u.id = b.user_id`;

type Tx = { query: (t: string, p?: unknown[]) => Promise<{ rows: any[]; rowCount: number | null }> };

/** Admin creates / edits the bookable slots (time + price) of each court. */
@Injectable()
export class AdminSlotsService {
  constructor(private readonly db: Db) {}

  /* ------------------------------ read ------------------------------ */

  /** ?courtId= &venueId= &date= | &from= &to= (YYYY-MM-DD, default: today onwards) &status=open|booked|all &limit= */
  async list(q: Record<string, string>) {
    const where: string[] = [];
    const p: unknown[] = [];
    const add = (v: unknown) => { p.push(v); return `$${p.length}`; };

    if (q.courtId) where.push(`s.court_id = ${add(q.courtId)}`);
    if (q.venueId) where.push(`c.venue_id = ${add(q.venueId)}`);

    const today = localDate(new Date());
    let from = q.from || q.date || today;
    let to = q.to || q.date || '';
    for (const [k, v] of [['from', from], ['to', to]] as const) {
      if (v && !isValidDateStr(v)) throw bad(`${k} must be YYYY-MM-DD`);
    }
    if (q.date) { from = q.date; to = q.date; }
    where.push(`s.start_at >= ${add(fromLocal(from, 0))}`);
    if (to) where.push(`s.start_at < ${add(fromLocal(addDays(to, 1), 0))}`);

    const status = q.status || 'all';
    if (!['open', 'booked', 'all'].includes(status)) throw bad('status must be open, booked or all');
    if (status === 'open') where.push(`b.id IS NULL AND s.active AND s.start_at > now()`);
    if (status === 'booked') where.push(`b.id IS NOT NULL`);

    const limit = intParam(q.limit, 200, 1, 1000);
    const rows = (await this.db.query(
      `${SELECT_SLOT} WHERE ${where.join(' AND ')} ORDER BY s.start_at, c.name LIMIT ${limit}`, p)).rows;
    return { count: rows.length, items: rows.map(slotDto) };
  }

  /* ------------------------------ create one ------------------------------ */

  /** Body: {date:"2026-10-12", startTime:"18:00", endTime:"19:00", price?} (price defaults to court hourly rate x duration) */
  async create(courtId: string, body: unknown) {
    const b = asObject(body);
    const { start, end } = slotRange(b.date, b.startTime, b.endTime);
    if (start <= new Date()) throw bad('Slot start time must be in the future');

    const id = await this.db.tx(async (c) => {
      const court = await this.lockCourt(c, courtId);
      const price = b.price === undefined ? Math.round((court.price * (end.getTime() - start.getTime())) / 3_600_000) : slotPrice(b.price);
      await this.assertNoOverlap(c, courtId, start, end);
      const r = await c.query(
        `INSERT INTO court_slots(court_id, start_at, end_at, price) VALUES ($1,$2,$3,$4) RETURNING id`, [courtId, start, end, price]);
      return r.rows[0].id as string;
    });
    return this.get(id);
  }

  /* ------------------------------ create many ------------------------------ */

  /**
   * Body: {fromDate, toDate, daysOfWeek?:[0..6] (0=Sunday, default every day), startTime:"06:00", endTime:"22:00",
   *        slotMinutes:60, price?}
   * Splits startTime-endTime into slots of slotMinutes for every chosen day. Past times and times that overlap
   * an existing slot are skipped. Max 500 slots per call.
   */
  async bulk(courtId: string, body: unknown) {
    const b = asObject(body);
    if (!isValidDateStr(b.fromDate) || !isValidDateStr(b.toDate)) throw bad('fromDate and toDate must be YYYY-MM-DD');
    if (b.toDate < b.fromDate) throw bad('toDate must not be before fromDate');
    if (b.toDate > addDays(b.fromDate, 61)) throw bad('Date range can be at most 62 days');

    const s = parseHM(b.startTime, 'startTime');
    const e = parseHM(b.endTime, 'endTime');
    const winMin = e.h * 60 + e.m - (s.h * 60 + s.m);
    const step = b.slotMinutes;
    if (typeof step !== 'number' || !Number.isInteger(step) || step < 15 || step > 720) throw bad('slotMinutes must be a whole number from 15 to 720');
    if (winMin <= 0) throw bad('endTime must be after startTime');
    if (winMin % step !== 0) throw bad('The time window must divide evenly into slots (e.g. 06:00-22:00 with 60-minute slots)');

    let days = [0, 1, 2, 3, 4, 5, 6];
    if (b.daysOfWeek !== undefined) {
      if (!Array.isArray(b.daysOfWeek) || !b.daysOfWeek.length || b.daysOfWeek.some((d) => !Number.isInteger(d) || d < 0 || d > 6)) {
        throw bad('daysOfWeek must be a list of numbers 0-6 (0 = Sunday)');
      }
      days = b.daysOfWeek as number[];
    }

    const now = new Date();
    const wanted: { start: Date; end: Date }[] = [];
    for (let d: string = b.fromDate; d <= b.toDate; d = addDays(d, 1)) {
      if (!days.includes(new Date(`${d}T00:00:00Z`).getUTCDay())) continue;
      for (let t = 0; t < winMin; t += step) {
        const start = fromLocal(d, s.h, s.m + t);
        wanted.push({ start, end: new Date(start.getTime() + step * MINUTE) });
      }
    }
    if (wanted.length > MAX_BULK) throw bad(`That would create ${wanted.length} slots; the limit is ${MAX_BULK} per request. Use a shorter date range.`);

    const result = await this.db.tx(async (c) => {
      const court = await this.lockCourt(c, courtId);
      const price = b.price === undefined ? undefined : slotPrice(b.price);
      const first = wanted[0]?.start ?? now;
      const last = wanted[wanted.length - 1]?.end ?? now;
      const existing = (await c.query(
        `SELECT start_at, end_at FROM court_slots WHERE court_id=$1 AND active AND start_at < $3 AND end_at > $2`, [courtId, first, last])).rows
        .map((x) => ({ start: new Date(x.start_at), end: new Date(x.end_at) }));

      const fresh = wanted.filter((w) => w.start > now && !existing.some((x) => x.start < w.end && x.end > w.start));
      if (fresh.length) {
        await c.query(
          `INSERT INTO court_slots(court_id, start_at, end_at, price)
           SELECT $1, st, en, pr FROM unnest($2::timestamptz[], $3::timestamptz[], $4::int[]) AS t(st, en, pr)`,
          [courtId, fresh.map((x) => x.start.toISOString()), fresh.map((x) => x.end.toISOString()),
           fresh.map((x) => price ?? Math.round((court.price * (x.end.getTime() - x.start.getTime())) / 3_600_000))]);
      }
      return { created: fresh.length, skipped: wanted.length - fresh.length };
    });
    return { ...result, courtId };
  }

  /* ------------------------------ update / delete ------------------------------ */

  /** Body (any of): {date, startTime, endTime, price, active}. A slot that already has a booking cannot be changed. */
  async update(id: string, body: unknown) {
    const b = asObject(body);
    if (!isUuid(id)) throw new HttpError(404, 'Slot not found');
    await this.db.tx(async (c) => {
      const cur = (await c.query(`SELECT * FROM court_slots WHERE id=$1 FOR UPDATE`, [id])).rows[0];
      if (!cur) throw new HttpError(404, 'Slot not found');
      await this.assertNotBooked(c, cur, 'This slot is booked. Cancel the booking first (POST /admin/bookings/:id/cancel).');

      let start = new Date(cur.start_at);
      let end = new Date(cur.end_at);
      if (b.date !== undefined || b.startTime !== undefined || b.endTime !== undefined) {
        const r = slotRange(b.date ?? localDate(start), b.startTime ?? fmt24(start), b.endTime ?? (fmt24(end) === '00:00' ? '24:00' : fmt24(end)));
        start = r.start;
        end = r.end;
        if (start <= new Date()) throw bad('Slot start time must be in the future');
        await this.assertNoOverlap(c, cur.court_id, start, end, id);
      }
      const price = b.price === undefined ? cur.price : slotPrice(b.price);
      if (b.active !== undefined && typeof b.active !== 'boolean') throw bad('active must be true or false');
      const active = (b.active as boolean | undefined) ?? cur.active;
      if (active && !cur.active) await this.assertNoOverlap(c, cur.court_id, start, end, id);

      await c.query(`UPDATE court_slots SET start_at=$2, end_at=$3, price=$4, active=$5 WHERE id=$1`, [id, start, end, price, active]);
    });
    return this.get(id);
  }

  /** Deletes the slot. If old (cancelled/finished) bookings still point to it, it is just switched off. */
  async remove(id: string) {
    if (!isUuid(id)) throw new HttpError(404, 'Slot not found');
    return this.db.tx(async (c) => {
      const cur = (await c.query(`SELECT * FROM court_slots WHERE id=$1 FOR UPDATE`, [id])).rows[0];
      if (!cur) throw new HttpError(404, 'Slot not found');
      await this.assertNotBooked(c, cur, 'This slot is booked. Cancel the booking first (POST /admin/bookings/:id/cancel).');
      const used = await c.query(`SELECT 1 FROM bookings WHERE slot_id=$1 LIMIT 1`, [id]);
      if (used.rowCount) {
        await c.query(`UPDATE court_slots SET active=false WHERE id=$1`, [id]);
        return { deleted: false, deactivated: true };
      }
      await c.query(`DELETE FROM court_slots WHERE id=$1`, [id]);
      return { deleted: true };
    });
  }

  async get(id: string) {
    const r = (await this.db.query(`${SELECT_SLOT} WHERE s.id = $1`, [id])).rows[0];
    if (!r) throw new HttpError(404, 'Slot not found');
    return slotDto(r);
  }

  /* ------------------------------ helpers ------------------------------ */

  private async lockCourt(c: Tx, courtId: string): Promise<{ price: number }> {
    const court = (await c.query(`SELECT id, price FROM courts WHERE id=$1 FOR UPDATE`, [courtId])).rows[0];
    if (!court) throw new HttpError(404, 'Court not found');
    return court;
  }

  private async assertNoOverlap(c: Tx, courtId: string, start: Date, end: Date, exceptId?: string) {
    const r = await c.query(
      `SELECT start_at, end_at FROM court_slots
       WHERE court_id=$1 AND active AND start_at < $3 AND end_at > $2 AND ($4::uuid IS NULL OR id <> $4) LIMIT 1`,
      [courtId, start, end, exceptId ?? null]);
    if (r.rowCount) {
      const x = r.rows[0];
      throw new HttpError(409, `Overlaps an existing slot (${fmtTime(new Date(x.start_at))} – ${fmtTime(new Date(x.end_at))} on ${localDate(new Date(x.start_at))})`);
    }
  }

  private async assertNotBooked(c: Tx, slot: any, message: string) {
    const r = await c.query(
      `SELECT 1 FROM bookings WHERE court_id=$1 AND status <> 'cancelled' AND start_at < $3 AND end_at > $2 LIMIT 1`,
      [slot.court_id, slot.start_at, slot.end_at]);
    if (r.rowCount) throw new HttpError(409, message);
  }
}
