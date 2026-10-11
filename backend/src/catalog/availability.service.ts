import { Injectable } from '@nestjs/common';
import { Db } from '../db/db.service';
import { dayLabel, fmt24, fmtTime, MINUTE } from '../common/time';

/** A bookable slot created by an admin (table court_slots) that nobody has booked yet. */
export interface FreeSlot { id: string; courtId: string; start: Date; end: Date; price: number }

const NOT_BOOKED = `NOT EXISTS (
  SELECT 1 FROM bookings b
  WHERE b.court_id = s.court_id AND b.status <> 'cancelled' AND b.start_at < s.end_at AND b.end_at > s.start_at)`;

const toFree = (r: any): FreeSlot => ({
  id: r.id, courtId: r.court_id, start: new Date(r.start_at), end: new Date(r.end_at), price: r.price,
});

export const slotDto = (s: FreeSlot) => ({
  id: s.id,
  slotId: s.id,
  startAt: s.start.toISOString(),
  endAt: s.end.toISOString(),
  time: fmtTime(s.start, true),
  time24: fmt24(s.start),
  endTime: fmtTime(s.end, true),
  endTime24: fmt24(s.end),
  durationMinutes: Math.round((s.end.getTime() - s.start.getTime()) / MINUTE),
  price: s.price,
});

@Injectable()
export class AvailabilityService {
  constructor(private readonly db: Db) {}

  /** Free admin slots of the given courts that start in [from, to), earliest first. */
  async freeSlots(courtIds: string[], from: Date, to: Date): Promise<FreeSlot[]> {
    if (!courtIds.length) return [];
    const r = await this.db.query(
      `SELECT s.id, s.court_id, s.start_at, s.end_at, s.price
       FROM court_slots s
       WHERE s.court_id = ANY($1) AND s.active AND s.start_at >= $2 AND s.start_at < $3 AND ${NOT_BOOKED}
       ORDER BY s.start_at`,
      [courtIds, from, to],
    );
    return r.rows.map(toFree);
  }

  /** The earliest free slot of each court (looking up to 60 days ahead). */
  async nextFreeByCourt(courtIds: string[], now = new Date()): Promise<Map<string, FreeSlot>> {
    const out = new Map<string, FreeSlot>();
    if (!courtIds.length) return out;
    const r = await this.db.query(
      `SELECT DISTINCT ON (s.court_id) s.id, s.court_id, s.start_at, s.end_at, s.price
       FROM court_slots s
       WHERE s.court_id = ANY($1) AND s.active AND s.start_at > $2 AND s.start_at < $2::timestamptz + interval '60 days'
         AND ${NOT_BOOKED}
       ORDER BY s.court_id, s.start_at`,
      [courtIds, now],
    );
    for (const row of r.rows) out.set(row.court_id, toFree(row));
    return out;
  }

  /** Earliest free slot across several courts as a label ("4:00 PM", "Tomorrow 6:00 AM", "12 Oct 6:00 PM"), or null. */
  async nextAvailableLabel(courtIds: string[], now = new Date()): Promise<string | null> {
    const next = await this.nextFreeByCourt(courtIds, now);
    let best: FreeSlot | null = null;
    for (const s of next.values()) if (!best || s.start < best.start) best = s;
    return best ? dayLabel(best.start, now) : null;
  }
}
