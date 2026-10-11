import { Controller, Get, Param, Query } from '@nestjs/common';
import { HttpError } from '../common/http-error';
import { addDays, isValidDateStr, localDate } from '../common/time';
import { CatalogService } from './catalog.service';

const num = (v: unknown): number | undefined => {
  if (v === undefined || v === '') return undefined;
  const n = Number(v);
  if (!Number.isFinite(n)) throw new HttpError(400, `Invalid number: ${String(v)}`);
  return n;
};
const list = (v: unknown): string[] =>
  typeof v === 'string' ? v.split(',').map((s) => s.trim()).filter(Boolean) : [];

function dateParam(v: unknown): string {
  const today = localDate(new Date());
  if (v === undefined || v === '') return today;
  if (!isValidDateStr(v)) throw new HttpError(400, 'date must be YYYY-MM-DD');
  if (v < today || v > addDays(today, 60)) throw new HttpError(400, 'date must be within the next 60 days');
  return v;
}

/** Public (no login) browsing endpoints. */
@Controller()
export class CatalogController {
  constructor(private readonly catalog: CatalogService) {}

  /** Home chips: [{name, venues, icon}] */
  @Get('categories')
  categories() {
    return this.catalog.categories();
  }

  /** Home dashboard cards. ?sport=Badminton&lat=&lng= */
  @Get('courts')
  courts(@Query() q: Record<string, string>) {
    return this.catalog.venueCards(q.sport || undefined, num(q.lat), num(q.lng));
  }

  /** Venue detail screen */
  @Get('venues/:id')
  venue(@Param('id') id: string, @Query() q: Record<string, string>) {
    return this.catalog.venue(id, num(q.lat), num(q.lng));
  }

  /**
   * Open slots (created by the admin) of one court on a day. ?date=2026-10-12
   * Each slot has {id, time, endTime, durationMinutes, price}; book it with POST /bookings {slotId}.
   */
  @Get('courts/:id/slots')
  slots(@Param('id') id: string, @Query() q: Record<string, string>) {
    return this.catalog.courtSlots(id, dateParam(q.date));
  }

  /**
   * Search results. Query params (all optional):
   *  q, sport, date (YYYY-MM-DD, default today), timeWindow = any|morning|afternoon|evening,
   *  radiusKm, environment = indoor|outdoor|rooftop|all, surfaces=a,b, minRate, maxRate,
   *  facilities=a,b, lat, lng, sort = distance|price|rating
   */
  @Get('listings')
  listings(@Query() q: Record<string, string>) {
    const window = q.timeWindow || 'any';
    if (!['any', 'morning', 'afternoon', 'evening'].includes(window)) throw new HttpError(400, 'Invalid timeWindow');
    const environment = q.environment || 'all';
    if (!['indoor', 'outdoor', 'rooftop', 'all'].includes(environment)) throw new HttpError(400, 'Invalid environment');
    return this.catalog.listings({
      q: q.q?.trim() || undefined,
      sport: q.sport || undefined,
      date: dateParam(q.date),
      window,
      radiusKm: num(q.radiusKm),
      environment,
      surfaces: list(q.surfaces),
      minRate: num(q.minRate),
      maxRate: num(q.maxRate),
      facilities: list(q.facilities),
      lat: num(q.lat),
      lng: num(q.lng),
      sort: q.sort || 'distance',
    });
  }
}
