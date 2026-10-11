import { Injectable } from '@nestjs/common';
import { HttpError } from '../common/http-error';
import { addDays, dayLabel, fromLocal, localDate, localHM, MINUTE } from '../common/time';
import { Db } from '../db/db.service';
import { AvailabilityService, slotDto } from './availability.service';

const WINDOWS: Record<string, [number, number]> = {
  any: [0, 24], morning: [6, 12], afternoon: [12, 17], evening: [17, 22],
};

export interface ListingQuery {
  q?: string; sport?: string; date: string; window: string; radiusKm?: number;
  environment: string; surfaces: string[]; minRate?: number; maxRate?: number; facilities: string[];
  lat?: number; lng?: number; sort: string;
}

function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number) {
  const r = (d: number) => (d * Math.PI) / 180;
  const a = Math.sin(r(lat2 - lat1) / 2) ** 2 + Math.cos(r(lat1)) * Math.cos(r(lat2)) * Math.sin(r(lng2 - lng1) / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.sqrt(a));
}

const round1 = (n: number) => Math.round(n * 10) / 10;

@Injectable()
export class CatalogService {
  constructor(private readonly db: Db, private readonly avail: AvailabilityService) {}

  /* ------------------------------ categories ------------------------------ */

  async categories() {
    const r = await this.db.query(
      `SELECT s.name, s.icon, count(DISTINCT c.venue_id) AS venues
       FROM sports s
       JOIN courts c ON c.sport = s.name AND c.active
       JOIN venues v ON v.id = c.venue_id AND v.active
       GROUP BY s.name, s.icon, s.position ORDER BY s.position`,
    );
    return r.rows.map((x) => ({ name: x.name, venues: x.venues, icon: x.icon }));
  }

  /* ------------------------------ dashboard court cards ------------------------------ */

  /** One card per venue (shape of the Flutter `Court` model). */
  async venueCards(sport?: string, lat?: number, lng?: number) {
    const vr = await this.db.query(`SELECT * FROM venues WHERE active ORDER BY distance_km, name`);
    const cr = await this.db.query(
      `SELECT * FROM courts WHERE active ${sport ? 'AND sport = $1' : ''} ORDER BY venue_id, position`,
      sport ? [sport] : [],
    );
    const allSports = await this.db.query(`SELECT venue_id, array_agg(DISTINCT sport) AS sports FROM courts WHERE active GROUP BY venue_id`);
    const sportsByVenue = new Map(allSports.rows.map((x) => [x.venue_id, x.sports as string[]]));
    const nextByCourt = await this.avail.nextFreeByCourt(cr.rows.map((c) => c.id));
    const out: any[] = [];
    for (const v of vr.rows) {
      const courts = cr.rows.filter((c) => c.venue_id === v.id);
      if (!courts.length) continue;
      let next: Date | null = null;
      for (const c of courts) {
        const n = nextByCourt.get(c.id);
        if (n && (!next || n.start < next)) next = n.start;
      }
      out.push({
        id: v.id,
        name: v.name,
        address: v.address,
        surface: v.surface_label,
        sports: sportsByVenue.get(v.id) ?? [],
        rating: v.rating,
        reviews: v.reviews,
        distanceKm: this.distance(v, lat, lng),
        nextAvailable: next ? dayLabel(next) : 'No slots open',
        pricePerHour: Math.min(...courts.map((c) => c.price)),
        imageAsset: v.image_asset,
      });
    }
    return out.sort((a, b) => a.distanceKm - b.distanceKm);
  }

  /* ------------------------------ venue detail ------------------------------ */

  async venue(id: string, lat?: number, lng?: number) {
    const v = await this.db.one(`SELECT * FROM venues WHERE id = $1 AND active`, [id]);
    if (!v) throw new HttpError(404, 'Venue not found');
    const [photos, amenities, courts] = await Promise.all([
      this.db.query(`SELECT asset FROM venue_photos WHERE venue_id=$1 ORDER BY position`, [id]),
      this.db.query(`SELECT icon, title, subtitle FROM venue_amenities WHERE venue_id=$1 ORDER BY position`, [id]),
      this.db.query(`SELECT * FROM courts WHERE venue_id=$1 AND active ORDER BY position`, [id]),
    ]);

    const now = new Date();
    const nextByCourt = await this.avail.nextFreeByCourt(courts.rows.map((c) => c.id), now);

    const courtDtos = courts.rows.map((c) => {
      const next = nextByCourt.get(c.id);
      let status: 'nextSlot' | 'availableNow' | 'booked';
      let statusText: string;
      if (!next) {
        status = 'booked';
        statusText = 'No slots open';
      } else if (next.start.getTime() - now.getTime() <= 60 * MINUTE) {
        status = 'availableNow';
        statusText = `Available at ${dayLabel(next.start, now)}`;
      } else {
        status = 'nextSlot';
        statusText = `Next Slot: ${dayLabel(next.start, now)}`;
      }
      return {
        id: c.id, name: c.name, tag: c.tag, description: c.description, sport: c.sport,
        price: c.price, status, statusText,
        nextSlot: next ? slotDto(next) : null,
      };
    });

    return {
      id: v.id, name: v.name, address: v.address, area: v.area,
      distanceKm: this.distance(v, lat, lng), rating: v.rating, reviews: v.reviews,
      startingRate: courts.rows.length ? Math.min(...courts.rows.map((c) => c.price)) : 0,
      photos: photos.rows.map((p) => p.asset),
      courts: courtDtos,
      amenities: amenities.rows,
      guidelines: v.guidelines,
      openHour: v.open_hour, closeHour: v.close_hour,
    };
  }

  /* ------------------------------ slots ------------------------------ */

  async courtSlots(courtId: string, date: string) {
    const row = await this.db.one(
      `SELECT c.id, c.name, c.price, v.name AS venue_name
       FROM courts c JOIN venues v ON v.id = c.venue_id WHERE c.id = $1 AND c.active AND v.active`, [courtId]);
    if (!row) throw new HttpError(404, 'Court not found');
    const now = new Date();
    const dayStart = fromLocal(date, 0);
    const from = dayStart > now ? dayStart : now;
    const slots = await this.avail.freeSlots([courtId], from, fromLocal(addDays(date, 1), 0));
    return { courtId, courtName: row.name, venueName: row.venue_name, date, slots: slots.map(slotDto) };
  }

  /* ------------------------------ search results ------------------------------ */

  async listings(q: ListingQuery) {
    const where: string[] = ['c.active', 'v.active'];
    const p: unknown[] = [];
    const add = (v: unknown) => { p.push(v); return `$${p.length}`; };

    if (q.sport) where.push(`c.sport = ${add(q.sport)}`);
    if (q.environment !== 'all') where.push(`c.environment = ${add(q.environment)}`);
    if (q.surfaces.length) where.push(`c.surface = ANY(${add(q.surfaces)})`);
    if (q.minRate != null) where.push(`c.price >= ${add(q.minRate)}`);
    if (q.maxRate != null) where.push(`c.price <= ${add(q.maxRate)}`);
    if (q.facilities.length) {
      where.push(`(SELECT count(*) FROM venue_facilities f WHERE f.venue_id = v.id AND f.facility = ANY(${add(q.facilities)})) = ${q.facilities.length}`);
    }
    // free text: every word must appear in the venue/court text. Sport names and "in" are ignored.
    if (q.q) {
      const sports = (await this.db.query('SELECT lower(name) AS n FROM sports')).rows.map((r) => r.n as string);
      const words = q.q.toLowerCase().split(/[^a-z0-9]+/).filter((w) => w && w !== 'in' && !sports.some((s) => s.split(' ').includes(w)));
      for (const w of words) {
        where.push(`lower(v.name || ' ' || v.address || ' ' || v.area || ' ' || c.name || ' ' || c.sport) LIKE ${add(`%${w}%`)}`);
      }
    }

    const rows = (await this.db.query(
      `SELECT c.*, v.name AS venue_name, v.address, v.area, v.lat, v.lng, v.distance_km, v.rating, v.reviews,
              v.open_hour, v.close_hour
       FROM courts c JOIN venues v ON v.id = c.venue_id
       WHERE ${where.join(' AND ')}`, p,
    )).rows;

    const [wFrom, wTo] = WINDOWS[q.window] ?? WINDOWS.any;
    const now = new Date();
    const dayStart = fromLocal(q.date, 0);
    const allFree = await this.avail.freeSlots(
      rows.map((r) => r.id), dayStart > now ? dayStart : now, fromLocal(addDays(q.date, 1), 0));

    const items: any[] = [];
    for (const r of rows) {
      const distanceKm = this.distance(r, q.lat, q.lng);
      if (q.radiusKm != null && distanceKm > q.radiusKm) continue;

      const free = allFree
        .filter((s) => s.courtId === r.id)
        .filter((s) => { const { h } = localHM(s.start); return h >= wFrom && h < wTo; });
      if (!free.length) continue; // the admin has no open slot for that date / time window

      items.push({
        id: r.id, courtId: r.id, venueId: r.venue_id,
        name: `${r.venue_name} - ${r.name}`,
        area: r.address,
        distanceKm,
        rating: r.rating, reviews: r.reviews,
        imageAsset: r.image_asset,
        topPick: r.top_pick, instantLock: r.instant_lock,
        tag: r.certified ? null : r.listing_tag,
        certified: r.certified,
        amenities: r.amenity_tags,
        slots: free.slice(0, 3).map(slotDto),
        slotCount: free.length,
        priceFrom: Math.min(...free.map((s) => s.price)),
        featuredSlots: r.top_pick,
        rate: r.price,
      });
    }

    const sorters: Record<string, (a: any, b: any) => number> = {
      distance: (a, b) => a.distanceKm - b.distanceKm,
      price: (a, b) => a.rate - b.rate,
      rating: (a, b) => b.rating - a.rating,
    };
    const byKey = sorters[q.sort] ?? sorters.distance;
    if (byKey === sorters.distance) items.sort((a, b) => (b.topPick ? 1 : 0) - (a.topPick ? 1 : 0) || byKey(a, b));
    else items.sort(byKey);

    return { count: items.length, date: q.date, items };
  }

  private distance(v: { lat: number | null; lng: number | null; distance_km: number }, lat?: number, lng?: number) {
    if (lat != null && lng != null && v.lat != null && v.lng != null) return round1(haversineKm(lat, lng, v.lat, v.lng));
    return v.distance_km;
  }
}
