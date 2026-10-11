import { Injectable } from '@nestjs/common';
import { randomBytes } from 'crypto';
import { HttpError } from '../common/http-error';
import { Db } from '../db/db.service';
import { asObject, bad, pick, setClause, Spec } from './admin.util';

const VENUE_SPECS: Spec[] = [
  { key: 'name', col: 'name', kind: 'str', req: true, len: 120 },
  { key: 'address', col: 'address', kind: 'str', req: true, len: 250 },
  { key: 'area', col: 'area', kind: 'str', req: true, len: 120 },
  { key: 'lat', col: 'lat', kind: 'nnum', min: -90, max: 90 },
  { key: 'lng', col: 'lng', kind: 'nnum', min: -180, max: 180 },
  { key: 'distanceKm', col: 'distance_km', kind: 'num', min: 0, max: 9999 },
  { key: 'rating', col: 'rating', kind: 'num', min: 0, max: 5 },
  { key: 'reviews', col: 'reviews', kind: 'int', min: 0 },
  { key: 'surfaceLabel', col: 'surface_label', kind: 'str', len: 80 },
  { key: 'imageAsset', col: 'image_asset', kind: 'str', len: 300 },
  { key: 'gate', col: 'gate', kind: 'str', len: 80 },
  { key: 'openHour', col: 'open_hour', kind: 'int', min: 0, max: 23 },
  { key: 'closeHour', col: 'close_hour', kind: 'int', min: 1, max: 24 },
  { key: 'guidelines', col: 'guidelines', kind: 'strarr' },
  { key: 'active', col: 'active', kind: 'bool' },
];

const COURT_SPECS: Spec[] = [
  { key: 'sport', col: 'sport', kind: 'str', req: true, len: 60 },
  { key: 'name', col: 'name', kind: 'str', req: true, len: 120 },
  { key: 'tag', col: 'tag', kind: 'str', len: 80 },
  { key: 'listingTag', col: 'listing_tag', kind: 'nstr', len: 80 },
  { key: 'description', col: 'description', kind: 'str', len: 500 },
  { key: 'surface', col: 'surface', kind: 'str', len: 80 },
  { key: 'environment', col: 'environment', kind: 'enum', values: ['indoor', 'outdoor', 'rooftop'] },
  { key: 'price', col: 'price', kind: 'int', req: true, min: 0, max: 10_000_000 },
  { key: 'imageAsset', col: 'image_asset', kind: 'nstr', len: 300 },
  { key: 'topPick', col: 'top_pick', kind: 'bool' },
  { key: 'instantLock', col: 'instant_lock', kind: 'bool' },
  { key: 'certified', col: 'certified', kind: 'nstr', len: 80 },
  { key: 'amenityTags', col: 'amenity_tags', kind: 'tags' },
  { key: 'position', col: 'position', kind: 'int', min: 0, max: 9999 },
  { key: 'active', col: 'active', kind: 'bool' },
];

const newId = (prefix: string) => `${prefix}-${randomBytes(4).toString('hex')}`;

const courtDto = (c: any) => ({
  id: c.id, venueId: c.venue_id, sport: c.sport, name: c.name, tag: c.tag, listingTag: c.listing_tag,
  description: c.description, surface: c.surface, environment: c.environment,
  price: c.price, imageAsset: c.image_asset, topPick: c.top_pick, instantLock: c.instant_lock,
  certified: c.certified, amenityTags: c.amenity_tags, position: c.position, active: c.active,
  ...(c.upcoming_slots !== undefined ? { upcomingSlots: c.upcoming_slots } : {}),
  ...(c.venue_name !== undefined ? { venueName: c.venue_name } : {}),
});

const venueDto = (v: any) => ({
  id: v.id, name: v.name, address: v.address, area: v.area, lat: v.lat, lng: v.lng,
  distanceKm: v.distance_km, rating: v.rating, reviews: v.reviews, surfaceLabel: v.surface_label,
  imageAsset: v.image_asset, gate: v.gate, openHour: v.open_hour, closeHour: v.close_hour,
  guidelines: v.guidelines, active: v.active,
  ...(v.court_count !== undefined ? { courtCount: v.court_count, upcomingSlots: v.upcoming_slots } : {}),
});

/** CRUD for sports, facilities (venues = "place") and courts. */
@Injectable()
export class AdminCatalogService {
  constructor(private readonly db: Db) {}

  /* ------------------------------ sports ------------------------------ */

  async listSports() {
    const r = await this.db.query(
      `SELECT s.name, s.icon, s.position, count(c.id) AS courts
       FROM sports s LEFT JOIN courts c ON c.sport = s.name
       GROUP BY s.name, s.icon, s.position ORDER BY s.position, s.name`);
    return r.rows.map((x) => ({ name: x.name, icon: x.icon, position: x.position, courts: x.courts }));
  }

  async createSport(body: unknown) {
    const b = asObject(body);
    const name = typeof b.name === 'string' ? b.name.trim() : '';
    if (name.length < 2 || name.length > 40) throw bad('name must be 2-40 characters');
    const icon = typeof b.icon === 'string' && b.icon.trim() ? b.icon.trim().slice(0, 60) : 'sports';
    try {
      await this.db.query(
        `INSERT INTO sports(name, icon, position) VALUES ($1, $2, (SELECT COALESCE(MAX(position) + 1, 0) FROM sports))`, [name, icon]);
    } catch (e: any) {
      if (e?.code === '23505') throw new HttpError(409, 'This sport already exists');
      throw e;
    }
    return { name, icon };
  }

  async updateSport(name: string, body: unknown) {
    const v = pick(asObject(body), [
      { key: 'icon', col: 'icon', kind: 'str', req: true, len: 60 },
      { key: 'position', col: 'position', kind: 'int', min: 0, max: 999 },
    ], true);
    if (!Object.keys(v).length) throw bad('Nothing to update (icon, position)');
    const { sql, params } = setClause(v);
    const r = await this.db.query(`UPDATE sports SET ${sql} WHERE name = $1 RETURNING name, icon, position`, [name, ...params]);
    if (!r.rowCount) throw new HttpError(404, 'Sport not found');
    return r.rows[0];
  }

  async deleteSport(name: string) {
    try {
      const r = await this.db.query(`DELETE FROM sports WHERE name = $1`, [name]);
      if (!r.rowCount) throw new HttpError(404, 'Sport not found');
    } catch (e: any) {
      if (e?.code === '23503') throw new HttpError(409, 'Courts still use this sport. Delete or change those courts first.');
      throw e;
    }
    return { deleted: true };
  }

  /* ------------------------------ venues (facilities) ------------------------------ */

  async listVenues(q: Record<string, string>) {
    const where: string[] = [];
    const p: unknown[] = [];
    if (q.active === 'true' || q.active === 'false') { p.push(q.active === 'true'); where.push(`v.active = $${p.length}`); }
    if (q.q?.trim()) { p.push(`%${q.q.trim().toLowerCase()}%`); where.push(`lower(v.name || ' ' || v.address || ' ' || v.area) LIKE $${p.length}`); }
    const r = await this.db.query(
      `SELECT v.*,
         (SELECT count(*) FROM courts c WHERE c.venue_id = v.id) AS court_count,
         (SELECT count(*) FROM court_slots s JOIN courts c ON c.id = s.court_id
            WHERE c.venue_id = v.id AND s.active AND s.start_at > now()) AS upcoming_slots
       FROM venues v ${where.length ? 'WHERE ' + where.join(' AND ') : ''} ORDER BY v.name`, p);
    return r.rows.map(venueDto);
  }

  async getVenue(id: string) {
    const v = await this.db.one(`SELECT * FROM venues WHERE id = $1`, [id]);
    if (!v) throw new HttpError(404, 'Facility not found');
    const [photos, amenities, facilities, courts] = await Promise.all([
      this.db.query(`SELECT asset FROM venue_photos WHERE venue_id=$1 ORDER BY position`, [id]),
      this.db.query(`SELECT icon, title, subtitle FROM venue_amenities WHERE venue_id=$1 ORDER BY position`, [id]),
      this.db.query(`SELECT facility FROM venue_facilities WHERE venue_id=$1 ORDER BY facility`, [id]),
      this.db.query(
        `SELECT c.*, (SELECT count(*) FROM court_slots s WHERE s.court_id = c.id AND s.active AND s.start_at > now()) AS upcoming_slots
         FROM courts c WHERE c.venue_id=$1 ORDER BY c.position, c.name`, [id]),
    ]);
    return {
      ...venueDto(v),
      photos: photos.rows.map((x) => x.asset),
      amenities: amenities.rows,
      facilities: facilities.rows.map((x) => x.facility),
      courts: courts.rows.map(courtDto),
    };
  }

  async createVenue(body: unknown) {
    const b = asObject(body);
    const v = pick(b, VENUE_SPECS, false);
    const children = this.venueChildren(b);
    const image = (v.image_asset as string | undefined) || children.photos?.[0];
    if (!image) throw bad('imageAsset (or at least one photo) is required');
    v.image_asset = image;
    this.checkHours((v.open_hour as number | undefined) ?? 6, (v.close_hour as number | undefined) ?? 22);

    const id = newId('venue');
    await this.db.tx(async (c) => {
      const cols = ['id', ...Object.keys(v)];
      await c.query(
        `INSERT INTO venues(${cols.join(',')}) VALUES (${cols.map((_, i) => `$${i + 1}`).join(',')})`,
        [id, ...Object.values(v)]);
      await this.writeChildren(c, id, children);
    });
    return this.getVenue(id);
  }

  async updateVenue(id: string, body: unknown) {
    const b = asObject(body);
    const v = pick(b, VENUE_SPECS, true);
    const children = this.venueChildren(b);
    await this.db.tx(async (c) => {
      const cur = (await c.query(`SELECT open_hour, close_hour FROM venues WHERE id=$1 FOR UPDATE`, [id])).rows[0];
      if (!cur) throw new HttpError(404, 'Facility not found');
      this.checkHours((v.open_hour as number | undefined) ?? cur.open_hour, (v.close_hour as number | undefined) ?? cur.close_hour);
      if (Object.keys(v).length) {
        const { sql, params } = setClause(v);
        await c.query(`UPDATE venues SET ${sql} WHERE id = $1`, [id, ...params]);
      }
      await this.writeChildren(c, id, children);
    });
    return this.getVenue(id);
  }

  async deleteVenue(id: string) {
    try {
      const r = await this.db.query(`DELETE FROM venues WHERE id = $1`, [id]);
      if (!r.rowCount) throw new HttpError(404, 'Facility not found');
    } catch (e: any) {
      if (e?.code === '23503') {
        throw new HttpError(409, 'This facility has bookings, so it cannot be deleted. Set active=false to hide it from users instead.');
      }
      throw e;
    }
    return { deleted: true };
  }

  private checkHours(open: number, close: number) {
    if (close <= open) throw bad('closeHour must be after openHour');
  }

  private venueChildren(b: Record<string, unknown>) {
    const arr = pick(b, [
      { key: 'photos', col: 'photos', kind: 'strarr' },
      { key: 'facilities', col: 'facilities', kind: 'strarr' },
    ], true) as { photos?: string[]; facilities?: string[] };
    let amenities: { icon: string; title: string; subtitle: string }[] | undefined;
    if (b.amenities !== undefined) {
      const a = b.amenities;
      if (!Array.isArray(a) || a.length > 30 || a.some((x) => !x || typeof x.icon !== 'string' || typeof x.title !== 'string' || x.title.trim() === '')) {
        throw bad('amenities must be a list of {icon, title, subtitle}');
      }
      amenities = a.map((x) => ({ icon: x.icon, title: x.title.trim(), subtitle: typeof x.subtitle === 'string' ? x.subtitle : '' }));
    }
    return { photos: arr.photos, facilities: arr.facilities, amenities };
  }

  /** Lists that are sent replace the stored list; lists that are not sent stay untouched. */
  private async writeChildren(
    c: { query: (t: string, p?: unknown[]) => Promise<any> }, id: string,
    ch: { photos?: string[]; facilities?: string[]; amenities?: { icon: string; title: string; subtitle: string }[] },
  ) {
    if (ch.photos) {
      await c.query(`DELETE FROM venue_photos WHERE venue_id=$1`, [id]);
      for (const [i, a] of ch.photos.entries()) await c.query(`INSERT INTO venue_photos(venue_id,position,asset) VALUES ($1,$2,$3)`, [id, i, a]);
    }
    if (ch.amenities) {
      await c.query(`DELETE FROM venue_amenities WHERE venue_id=$1`, [id]);
      for (const [i, a] of ch.amenities.entries()) {
        await c.query(`INSERT INTO venue_amenities(venue_id,position,icon,title,subtitle) VALUES ($1,$2,$3,$4,$5)`, [id, i, a.icon, a.title, a.subtitle]);
      }
    }
    if (ch.facilities) {
      await c.query(`DELETE FROM venue_facilities WHERE venue_id=$1`, [id]);
      for (const f of new Set(ch.facilities)) await c.query(`INSERT INTO venue_facilities(venue_id,facility) VALUES ($1,$2)`, [id, f]);
    }
  }

  /* ------------------------------ courts ------------------------------ */

  async listCourts(q: Record<string, string>) {
    const p: unknown[] = [];
    const where: string[] = [];
    if (q.venueId) { p.push(q.venueId); where.push(`c.venue_id = $${p.length}`); }
    if (q.sport) { p.push(q.sport); where.push(`c.sport = $${p.length}`); }
    const r = await this.db.query(
      `SELECT c.*, v.name AS venue_name,
         (SELECT count(*) FROM court_slots s WHERE s.court_id = c.id AND s.active AND s.start_at > now()) AS upcoming_slots
       FROM courts c JOIN venues v ON v.id = c.venue_id
       ${where.length ? 'WHERE ' + where.join(' AND ') : ''} ORDER BY v.name, c.position, c.name`, p);
    return r.rows.map(courtDto);
  }

  async getCourt(id: string) {
    const r = await this.db.one(
      `SELECT c.*, v.name AS venue_name,
         (SELECT count(*) FROM court_slots s WHERE s.court_id = c.id AND s.active AND s.start_at > now()) AS upcoming_slots
       FROM courts c JOIN venues v ON v.id = c.venue_id WHERE c.id = $1`, [id]);
    if (!r) throw new HttpError(404, 'Court not found');
    return courtDto(r);
  }

  async createCourt(venueId: string, body: unknown) {
    const v = pick(asObject(body), COURT_SPECS, false);
    const venue = await this.db.one(`SELECT id, image_asset FROM venues WHERE id = $1`, [venueId]);
    if (!venue) throw new HttpError(404, 'Facility not found');
    await this.assertSport(v.sport as string);
    if (!v.image_asset) v.image_asset = venue.image_asset;

    const id = newId(venueId);
    const cols = ['id', 'venue_id', ...Object.keys(v)];
    await this.db.query(
      `INSERT INTO courts(${cols.join(',')}) VALUES (${cols.map((_, i) => `$${i + 1}`).join(',')})`,
      [id, venueId, ...Object.values(v)]);
    return this.getCourt(id);
  }

  async updateCourt(id: string, body: unknown) {
    const v = pick(asObject(body), COURT_SPECS, true);
    if (typeof v.sport === 'string') await this.assertSport(v.sport);
    if (Object.keys(v).length) {
      const { sql, params } = setClause(v);
      const r = await this.db.query(`UPDATE courts SET ${sql} WHERE id = $1`, [id, ...params]);
      if (!r.rowCount) throw new HttpError(404, 'Court not found');
    }
    return this.getCourt(id);
  }

  async deleteCourt(id: string) {
    try {
      const r = await this.db.query(`DELETE FROM courts WHERE id = $1`, [id]);
      if (!r.rowCount) throw new HttpError(404, 'Court not found');
    } catch (e: any) {
      if (e?.code === '23503') {
        throw new HttpError(409, 'This court has bookings, so it cannot be deleted. Set active=false to hide it from users instead.');
      }
      throw e;
    }
    return { deleted: true };
  }

  private async assertSport(name: string) {
    const s = await this.db.one(`SELECT 1 FROM sports WHERE name = $1`, [name]);
    if (!s) throw bad(`Unknown sport "${name}". Create it first with POST /admin/sports.`);
  }
}
