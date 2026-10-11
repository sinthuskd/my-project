import { Pool } from 'pg';
import { SPORTS_SEED, VENUES_SEED } from './seed-data';

/** Idempotent: safe to run many times (upserts the catalogue from seed-data.ts). Never touches users/bookings. */
export async function seed(pool: Pool): Promise<void> {
  const c = await pool.connect();
  try {
    await c.query('BEGIN');
    for (const [i, s] of SPORTS_SEED.entries()) {
      await c.query(
        `INSERT INTO sports(name, icon, position) VALUES ($1,$2,$3)
         ON CONFLICT (name) DO UPDATE SET icon = EXCLUDED.icon, position = EXCLUDED.position`,
        [s.name, s.icon, i],
      );
    }
    for (const v of VENUES_SEED) {
      await c.query(
        `INSERT INTO venues(id,name,address,area,lat,lng,distance_km,rating,reviews,surface_label,image_asset,gate,open_hour,close_hour,guidelines)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)
         ON CONFLICT (id) DO UPDATE SET name=EXCLUDED.name, address=EXCLUDED.address, area=EXCLUDED.area,
           lat=EXCLUDED.lat, lng=EXCLUDED.lng, distance_km=EXCLUDED.distance_km, rating=EXCLUDED.rating,
           reviews=EXCLUDED.reviews, surface_label=EXCLUDED.surface_label, image_asset=EXCLUDED.image_asset,
           gate=EXCLUDED.gate, open_hour=EXCLUDED.open_hour, close_hour=EXCLUDED.close_hour, guidelines=EXCLUDED.guidelines`,
        [v.id, v.name, v.address, v.area, v.lat, v.lng, v.distanceKm, v.rating, v.reviews, v.surfaceLabel,
         v.image, v.gate, v.openHour ?? 6, v.closeHour ?? 22, v.guidelines],
      );
      await c.query('DELETE FROM venue_photos WHERE venue_id=$1', [v.id]);
      for (const [i, p] of v.photos.entries()) {
        await c.query('INSERT INTO venue_photos(venue_id,position,asset) VALUES ($1,$2,$3)', [v.id, i, p]);
      }
      await c.query('DELETE FROM venue_amenities WHERE venue_id=$1', [v.id]);
      for (const [i, a] of v.amenities.entries()) {
        await c.query('INSERT INTO venue_amenities(venue_id,position,icon,title,subtitle) VALUES ($1,$2,$3,$4,$5)', [v.id, i, ...a]);
      }
      await c.query('DELETE FROM venue_facilities WHERE venue_id=$1', [v.id]);
      for (const f of v.facilities) {
        await c.query('INSERT INTO venue_facilities(venue_id,facility) VALUES ($1,$2)', [v.id, f]);
      }
      for (const [i, k] of v.courts.entries()) {
        await c.query(
          `INSERT INTO courts(id,venue_id,sport,name,tag,listing_tag,description,surface,environment,price,offpeak_price,image_asset,top_pick,instant_lock,certified,amenity_tags,position)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)
           ON CONFLICT (id) DO UPDATE SET sport=EXCLUDED.sport, name=EXCLUDED.name, tag=EXCLUDED.tag, listing_tag=EXCLUDED.listing_tag,
             description=EXCLUDED.description, surface=EXCLUDED.surface, environment=EXCLUDED.environment,
             price=EXCLUDED.price, offpeak_price=EXCLUDED.offpeak_price, image_asset=EXCLUDED.image_asset,
             top_pick=EXCLUDED.top_pick, instant_lock=EXCLUDED.instant_lock, certified=EXCLUDED.certified,
             amenity_tags=EXCLUDED.amenity_tags, position=EXCLUDED.position`,
          [k.id, v.id, k.sport, k.name, k.tag, k.listingTag ?? null, k.description, k.surface, k.environment ?? 'indoor', k.price,
           k.offpeak ?? null, k.image ?? v.image, k.topPick ?? false, k.instantLock ?? false, k.certified ?? null,
           JSON.stringify(k.tags ?? []), i],
        );
      }
    }
    await c.query('COMMIT');
  } catch (e) {
    await c.query('ROLLBACK');
    throw e;
  } finally {
    c.release();
  }
}
