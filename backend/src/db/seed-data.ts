/**
 * Your REAL catalogue goes here (sports, venues, courts).
 * Both lists are empty on purpose: the project ships without dummy data.
 *
 * How to use:
 *   1. Fill SPORTS_SEED and VENUES_SEED below (example at the bottom of this file).
 *   2. Run  npm run seed   (safe to run many times; it never touches users/bookings).
 *   Or insert rows directly into PostgreSQL (tables: sports, venues, courts, venue_photos,
 *   venue_amenities, venue_facilities).
 */

export interface SportSeed {
  name: string;
  icon: string; // Flutter icon name, e.g. 'sports_tennis'
}

export type Tag = { icon: string; label: string };

export interface CourtSeed {
  id: string; sport: string; name: string; tag: string; listingTag?: string; description: string; surface: string;
  environment?: 'indoor' | 'outdoor' | 'rooftop'; price: number; offpeak?: number;
  image?: string; topPick?: boolean; instantLock?: boolean; certified?: string; tags?: Tag[];
}

export interface VenueSeed {
  id: string; name: string; address: string; area: string; lat: number; lng: number; distanceKm: number;
  rating: number; reviews: number; surfaceLabel: string; image: string; gate: string;
  openHour?: number; closeHour?: number;
  photos: string[];
  amenities: [string, string, string][]; // [icon, title, subtitle]
  facilities: string[];
  guidelines: string[];
  courts: CourtSeed[];
}

export const SPORTS_SEED: SportSeed[] = [];

export const VENUES_SEED: VenueSeed[] = [];

/* Example of ONE venue (copy it into VENUES_SEED and replace the values):

{
  id: 'venue-1', name: 'Venue name', address: 'Street, City', area: 'Area',
  lat: 0, lng: 0, distanceKm: 0, rating: 0, reviews: 0,
  surfaceLabel: 'Indoor Wood', image: 'assets/images/your_image.jpg', gate: 'Main Gate',
  photos: ['assets/images/your_image.jpg'],
  amenities: [['local_parking', 'Free Parking', 'Secure spots']],
  facilities: ['On-premise Free Parking'],
  guidelines: ['**Non-marking shoes** mandatory.'],
  courts: [
    { id: 'venue-1-c1', sport: 'Badminton', name: 'Court 1', tag: 'Standard', description: 'Indoor court',
      surface: 'Wooden Parquet', price: 2000 },
  ],
},
*/
