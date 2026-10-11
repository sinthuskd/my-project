import { Injectable } from '@nestjs/common';
import { asObject, bad, intParam, isUuid, parseHM, pick, setClause, Spec } from '../admin/admin.util';
import { HttpError } from '../common/http-error';
import { fromLocal, isValidDateStr } from '../common/time';
import { Db } from '../db/db.service';

const AUTO_EXPIRE_MS = 30 * 60_000; // beacon closes 30 min before the match

const SPECS: Spec[] = [
  { key: 'sport', col: 'sport', kind: 'str', req: true, len: 60 },
  { key: 'format', col: 'format', kind: 'enum', values: ['singles', 'doubles', 'any'] },
  { key: 'skillLevel', col: 'skill_level', kind: 'enum', values: ['beginner', 'intermediate', 'advanced', 'all'] },
  { key: 'style', col: 'style', kind: 'enum', values: ['casual', 'competitive'] },
  { key: 'feeSplit', col: 'fee_split', kind: 'enum', values: ['split', 'host_pays', 'bring_gear'] },
  { key: 'verifiedOnly', col: 'verified_only', kind: 'bool' },
  { key: 'spots', col: 'spots', kind: 'int', min: 1, max: 10 },
  { key: 'note', col: 'note', kind: 'str', len: 300 },
  { key: 'autoExpire', col: 'auto_expire', kind: 'bool' },
  { key: 'notify', col: 'notify', kind: 'bool' },
];

const SELECT = `
  SELECT b.*, u.full_name AS host_name, u.fairplay AS host_fairplay,
         (SELECT count(*) FROM beacon_responses r WHERE r.beacon_id = b.id) AS joined,
         bk.ref AS booking_ref, v.name AS venue_name, ct.name AS court_name,
         EXISTS (SELECT 1 FROM beacon_responses r WHERE r.beacon_id = b.id AND r.user_id = $1) AS i_joined
  FROM match_beacons b
  JOIN users u ON u.id = b.host_id
  LEFT JOIN bookings bk ON bk.id = b.booking_id
  LEFT JOIN venues v ON v.id = bk.venue_id
  LEFT JOIN courts ct ON ct.id = bk.court_id`;

/** DB row -> JSON the app uses. */
function shape(r: any, me: string) {
  const closesAt = r.auto_expire ? new Date(new Date(r.start_at).getTime() - AUTO_EXPIRE_MS) : new Date(r.start_at);
  const expired = closesAt <= new Date();
  return {
    id: r.id,
    hostId: r.host_id,
    hostName: r.host_name,
    hostFairplay: r.host_fairplay,
    isMine: r.host_id === me,
    iJoined: r.i_joined,
    sport: r.sport,
    format: r.format,
    skillLevel: r.skill_level,
    style: r.style,
    feeSplit: r.fee_split,
    verifiedOnly: r.verified_only,
    startAt: r.start_at,
    closesAt,
    spots: r.spots,
    joined: r.joined,
    spotsLeft: Math.max(0, r.spots - r.joined),
    note: r.note,
    autoExpire: r.auto_expire,
    notify: r.notify,
    status: r.status === 'open' && expired ? 'expired' : r.status,
    booking: r.booking_id ? { id: r.booking_id, ref: r.booking_ref, venue: r.venue_name, court: r.court_name } : null,
    createdAt: r.created_at,
  };
}

@Injectable()
export class BeaconsService {
  constructor(private readonly db: Db) {}

  /* ------------------------------ time + booking helpers ------------------------------ */

  /** Body gives either {date:"YYYY-MM-DD", startTime:"HH:mm"} (Colombo time) or {startAt: ISO string}. */
  private startFrom(b: Record<string, unknown>): Date {
    if (b.startAt !== undefined) {
      const d = new Date(String(b.startAt));
      if (Number.isNaN(d.getTime())) throw bad('startAt must be a valid date-time');
      return d;
    }
    if (!isValidDateStr(b.date)) throw bad('date must be YYYY-MM-DD');
    const t = parseHM(b.startTime, 'startTime');
    return fromLocal(b.date, t.h, t.m);
  }

  private async checkBooking(userId: string, bookingId: unknown, sport: string) {
    if (!isUuid(bookingId)) throw bad('bookingId is invalid');
    const bk = await this.db.one(
      `SELECT b.id, b.start_at, c.sport FROM bookings b JOIN courts c ON c.id = b.court_id
       WHERE b.id = $1 AND b.user_id = $2 AND b.status = 'confirmed'`, [bookingId, userId]);
    if (!bk) throw new HttpError(404, 'Booking not found (it must be one of your confirmed bookings)');
    if (bk.sport !== sport) throw bad(`That booking is for ${bk.sport}, not ${sport}`);
    return bk;
  }

  private async checkSport(sport: string) {
    if (!(await this.db.one('SELECT 1 FROM sports WHERE name = $1', [sport]))) throw bad(`Unknown sport "${sport}"`);
  }

  /* ------------------------------ CREATE ------------------------------ */

  /** Body: {sport, date, startTime, spots?, format?, skillLevel?, style?, feeSplit?, verifiedOnly?, note?, bookingId?, autoExpire?, notify?} */
  async create(userId: string, body: unknown) {
    const b = asObject(body);
    const v = pick(b, SPECS, false);
    await this.checkSport(v.sport as string);

    let start: Date;
    if (b.bookingId !== undefined && b.bookingId !== null && b.date === undefined && b.startAt === undefined) {
      start = new Date((await this.checkBooking(userId, b.bookingId, v.sport as string)).start_at);
    } else {
      start = this.startFrom(b);
      if (b.bookingId) await this.checkBooking(userId, b.bookingId, v.sport as string);
    }
    if (start <= new Date()) throw bad('That time has already passed');

    const cols = { ...v, host_id: userId, start_at: start, booking_id: b.bookingId ?? null };
    const keys = Object.keys(cols);
    const row = await this.db.one<{ id: string }>(
      `INSERT INTO match_beacons (${keys.join(',')}) VALUES (${keys.map((_, i) => `$${i + 1}`).join(',')}) RETURNING id`,
      keys.map((k) => (cols as any)[k]));
    return this.get(userId, row!.id);
  }

  /* ------------------------------ READ ------------------------------ */

  /**
   * Beacons from other players that you can still join.
   * Query: sport, skillLevel, format, date (YYYY-MM-DD), limit, offset
   */
  async listOpen(userId: string, q: Record<string, string>) {
    const where = [`b.host_id <> $2`, `b.status = 'open'`,
      `(CASE WHEN b.auto_expire THEN b.start_at - interval '30 minutes' ELSE b.start_at END) > now()`];
    const params: unknown[] = [userId, userId];
    const add = (sql: string, v: unknown) => { params.push(v); where.push(sql.replace('?', `$${params.length}`)); };
    if (q.sport) add('b.sport = ?', q.sport);
    if (q.format) add(`(b.format = ? OR b.format = 'any')`, q.format);
    if (q.skillLevel) add(`(b.skill_level = ? OR b.skill_level = 'all')`, q.skillLevel);
    if (q.date) {
      if (!isValidDateStr(q.date)) throw bad('date must be YYYY-MM-DD');
      add('b.start_at >= ?', fromLocal(q.date, 0));
      add('b.start_at < ?', fromLocal(q.date, 24));
    }
    const limit = intParam(q.limit, 30, 1, 100);
    const offset = intParam(q.offset, 0, 0, 100000);
    // $1 in SELECT = viewer id (for i_joined); $2 = host filter
    const rows = (await this.db.query(
      `${SELECT} WHERE ${where.join(' AND ')} ORDER BY b.start_at ASC LIMIT ${limit} OFFSET ${offset}`, params)).rows;
    return { items: rows.map((r) => shape(r, userId)) };
  }

  /** Beacons I created (status=open|full|cancelled|all, default all). */
  async listMine(userId: string, status = 'all') {
    const rows = (await this.db.query(
      `${SELECT} WHERE b.host_id = $1 ${status !== 'all' ? 'AND b.status = $2' : ''} ORDER BY b.start_at DESC`,
      status !== 'all' ? [userId, status] : [userId])).rows;
    return { items: rows.map((r) => shape(r, userId)) };
  }

  /** Beacons I responded to. */
  async listJoined(userId: string) {
    const rows = (await this.db.query(
      `${SELECT} WHERE EXISTS (SELECT 1 FROM beacon_responses r WHERE r.beacon_id = b.id AND r.user_id = $1)
       ORDER BY b.start_at DESC`, [userId])).rows;
    return { items: rows.map((r) => shape(r, userId)) };
  }

  async get(userId: string, id: string) {
    if (!isUuid(id)) throw new HttpError(404, 'Beacon not found');
    const r = await this.db.one(`${SELECT} WHERE b.id = $2`, [userId, id]);
    if (!r) throw new HttpError(404, 'Beacon not found');
    const out: any = shape(r, userId);
    // only the host sees who responded
    if (r.host_id === userId) {
      out.responders = (await this.db.query(
        `SELECT u.id, u.full_name AS name, u.fairplay, r.created_at AS "joinedAt"
         FROM beacon_responses r JOIN users u ON u.id = r.user_id WHERE r.beacon_id = $1 ORDER BY r.created_at`, [id])).rows;
    }
    return out;
  }

  /* ------------------------------ UPDATE ------------------------------ */

  /** Host only. Any field from create can be sent (partial). Also accepts status: "cancelled" | "open". */
  async update(userId: string, id: string, body: unknown) {
    const b = asObject(body);
    const cur = await this.owned(userId, id);
    const v = pick(b, SPECS, true);
    if (v.sport) await this.checkSport(v.sport as string);

    if (b.date !== undefined || b.startTime !== undefined || b.startAt !== undefined) {
      const start = this.startFrom({ date: b.date, startTime: b.startTime, startAt: b.startAt });
      if (start <= new Date()) throw bad('That time has already passed');
      v.start_at = start;
    }
    if (b.bookingId !== undefined) {
      if (b.bookingId === null) v.booking_id = null;
      else { await this.checkBooking(userId, b.bookingId, (v.sport as string) ?? cur.sport); v.booking_id = b.bookingId; }
    }
    if (b.status !== undefined) {
      if (b.status !== 'cancelled' && b.status !== 'open') throw bad('status can only be set to cancelled or open');
      v.status = b.status;
    }

    const joined = (await this.db.one<{ n: number }>('SELECT count(*) AS n FROM beacon_responses WHERE beacon_id=$1', [id]))!.n;
    const spots = (v.spots as number | undefined) ?? cur.spots;
    if (spots < joined) throw bad(`${joined} player(s) already joined, spots cannot be less than that`);
    if ((v.status !== 'cancelled' && cur.status !== 'cancelled') || v.status === 'open') v.status = joined >= spots ? 'full' : 'open';

    if (!Object.keys(v).length) throw bad('Nothing to update');
    const { sql, params } = setClause({ ...v, updated_at: new Date() });
    await this.db.query(`UPDATE match_beacons SET ${sql} WHERE id = $1`, [id, ...params]);
    return this.get(userId, id);
  }

  /* ------------------------------ DELETE ------------------------------ */

  async remove(userId: string, id: string) {
    await this.owned(userId, id);
    await this.db.query('DELETE FROM match_beacons WHERE id = $1', [id]);
    return { ok: true };
  }

  /* ------------------------------ join / leave ------------------------------ */

  async join(userId: string, id: string) {
    if (!isUuid(id)) throw new HttpError(404, 'Beacon not found');
    await this.db.tx(async (c) => {
      const bc = (await c.query('SELECT * FROM match_beacons WHERE id = $1 FOR UPDATE', [id])).rows[0];
      if (!bc) throw new HttpError(404, 'Beacon not found');
      if (bc.host_id === userId) throw bad('You cannot join your own beacon');
      const closes = new Date(bc.start_at).getTime() - (bc.auto_expire ? AUTO_EXPIRE_MS : 0);
      if (bc.status === 'cancelled') throw new HttpError(409, 'This beacon was cancelled');
      if (closes <= Date.now()) throw new HttpError(409, 'This beacon has expired');
      if (bc.status === 'full') throw new HttpError(409, 'No spots left');
      const ins = await c.query('INSERT INTO beacon_responses (beacon_id, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING', [id, userId]);
      if (!ins.rowCount) throw new HttpError(409, 'You already joined this beacon');
      const n = (await c.query('SELECT count(*) AS n FROM beacon_responses WHERE beacon_id = $1', [id])).rows[0].n as number;
      if (n >= bc.spots) await c.query(`UPDATE match_beacons SET status='full', updated_at=now() WHERE id=$1`, [id]);
    });
    return this.get(userId, id);
  }

  async leave(userId: string, id: string) {
    if (!isUuid(id)) throw new HttpError(404, 'Beacon not found');
    await this.db.tx(async (c) => {
      const bc = (await c.query('SELECT status FROM match_beacons WHERE id = $1 FOR UPDATE', [id])).rows[0];
      if (!bc) throw new HttpError(404, 'Beacon not found');
      const del = await c.query('DELETE FROM beacon_responses WHERE beacon_id=$1 AND user_id=$2', [id, userId]);
      if (!del.rowCount) throw new HttpError(404, 'You have not joined this beacon');
      if (bc.status === 'full') await c.query(`UPDATE match_beacons SET status='open', updated_at=now() WHERE id=$1`, [id]);
    });
    return this.get(userId, id);
  }

  /* ------------------------------ helpers ------------------------------ */

  private async owned(userId: string, id: string) {
    if (!isUuid(id)) throw new HttpError(404, 'Beacon not found');
    const r = await this.db.one('SELECT * FROM match_beacons WHERE id = $1', [id]);
    if (!r) throw new HttpError(404, 'Beacon not found');
    if (r.host_id !== userId) throw new HttpError(403, 'Only the host can change this beacon');
    return r;
  }
}
