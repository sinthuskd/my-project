# SportsBook Backend (NestJS + PostgreSQL)

Register → SMS OTP → Login → Profile, plus an **admin panel API** (facilities, courts, slots, prices, dashboard), courts / venues / search, bookings, wallet and the Digital Match Pass.
Everything is stored in **PostgreSQL**.

## 1. Start PostgreSQL

**Option A – Docker (easiest)**
```bash
cd backend
docker compose up -d db
```

**Option B – PostgreSQL already installed** (psql as a superuser):
```sql
CREATE USER sportsbook WITH PASSWORD 'sportsbook';
CREATE DATABASE sportsbook OWNER sportsbook;
```
Or use any hosted Postgres (Neon, Supabase, Render, RDS ...) and put its URL in `DATABASE_URL`
(add `PGSSL=true` if it needs TLS).

## 2. Run the backend (Node 18+)

```bash
cd backend
cp .env.example .env        # Windows cmd: copy .env.example .env   (then set your own JWT_SECRET)
npm install
npm run start:dev
```
On first start it **creates the tables** (`db/migrations/001_init.sql`). The project ships with **no dummy data**:
add your real sports, venues and courts (see "Adding your data" below).
You will see:
```
[db] applied migrations: 001_init.sql
SportsBook backend running
  Local:    http://localhost:3000/health
  Network:  http://192.168.1.5:3000   <- use this for a real phone
```
Everything in one go with Docker: `docker compose up --build` (API + Postgres).

Useful commands

| Command | What it does |
|---|---|
| `npm run migrate` | apply new SQL files from `db/migrations/` |
| `npm run seed` | (re)load the venues & courts you put in `src/db/seed-data.ts` (never touches users/bookings) |
| `npm run db:reset` | **deletes everything**, recreates empty tables (then loads `seed-data.ts` if you filled it) |
| `npm run smoke` | tests the running API end to end (register → OTP → book → cancel) |

Check without the app: open http://localhost:3000/health → `{"status":"ok","database":"ok"}`, then run `npm run smoke`.

### Admin: add your real data (recommended)

The admin creates everything through the API, no SQL needed (see **Admin panel API** below):
sports → facilities (places) → courts → slots (time + price). Customers only see and book what the admin created.

1. Set `ADMIN_EMAIL` / `ADMIN_PASSWORD` in `.env` (the admin account is created when the server starts, or run `npm run create-admin`).
2. `POST /admin/auth/login`, then call the `/admin/...` endpoints with `Authorization: Bearer <token>`.
3. `npm run smoke:admin` runs the whole flow as a test.

**Admin inside the Flutter app:** there is no separate web panel any more. Log in on the normal app login screen with the admin
email + password (`ADMIN_EMAIL` / `ADMIN_PASSWORD`). Accounts with role `admin` open the in-app admin panel
(Dashboard, Facilities + courts, Slots, Bookings, Sports, Customers) instead of the customer app. Customers log in the same way and see the normal app.

### Adding your data (seed file, optional)

Two ways:
1. Fill `SPORTS_SEED` and `VENUES_SEED` in `src/db/seed-data.ts` (an example is at the bottom of that file), then run `npm run seed`.
2. Insert rows directly into PostgreSQL: `sports`, `venues`, `courts`, `venue_photos`, `venue_amenities`, `venue_facilities`.

`AUTO_SEED=true` in `.env` loads `seed-data.ts` automatically when the venues table is empty.

## 3. Connect the Flutter app

The app already talks to this backend for register / OTP / login / profile (`lib/services/auth_service.dart`).
Default URLs: Chrome/Windows/iOS sim `http://127.0.0.1:3000`, Android emulator `http://10.0.2.2:3000`.
Real phone (same Wi-Fi): `flutter run --dart-define=API_URL=http://<Network URL printed above>`

## Database tables

`users` · `sports` · `venues` · `venue_photos` · `venue_amenities` · `venue_facilities` · `courts` ·
`bookings` · `booking_players` · `wallet_transactions` (+ `schema_migrations`).
Double booking is impossible: the court row is locked inside a transaction while a booking is checked and saved.
Venues are open `open_hour`–`close_hour` (default 06:00–22:00, Colombo time). Prices are LKR per hour, with an optional cheaper `offpeak_price` from 9 PM.

## API

Errors are always `{ "statusCode": 400, "message": "..." }`. Send `Authorization: Bearer <accessToken>` where **Auth = yes**.
Times are Colombo time (UTC+5:30).

### Auth
| Method & path | Auth | Notes |
|---|---|---|
| `POST /auth/register` | – | `{fullName, phone, email, password, sports[]}` → OTP challenge (`devOtp` in dev mode) |
| `POST /auth/verify-otp` | – | `{phone, code}` → `{accessToken, user}` |
| `POST /auth/resend-otp` | – | `{phone}` |
| `POST /auth/login` | – | `{identifier (email or mobile), password}` → `{accessToken, user}`; 403 `PHONE_NOT_VERIFIED` if OTP not done |
| `GET /auth/me` | yes | profile (matches played, court time, saved LKR, wallet, tier) |

### Browse (public) – response shapes match the Flutter models
| Method & path | Matches | Notes |
|---|---|---|
| `GET /categories` | `SportCategory` | `[{name, venues, icon}]` |
| `GET /courts?sport=Badminton&lat=&lng=` | `Court` (home cards) | `nextAvailable` is calculated from real bookings |
| `GET /venues/:id` | `Venue` | courts with live `status` (`availableNow` / `nextSlot` / `booked`), amenities, photos, guidelines |
| `GET /listings?...` | `CourtListing` (search results) | `{count, items[]}`, see filters below |
| `GET /courts/:courtId/slots?date=YYYY-MM-DD` | – | open slots the admin created that day: `{id, time, endTime, durationMinutes, price}` |

`/listings` filters (all optional): `q`, `sport`, `date`, `timeWindow=any|morning|afternoon|evening`, `radiusKm`,
`environment=indoor|outdoor|rooftop|all`, `surfaces=a,b`, `minRate`, `maxRate`, `facilities=a,b`, `lat`, `lng`,
`sort=distance|price|rating`. Each item lists its first 3 open `slots` (with `id`), `slotCount` and `priceFrom`. Only courts with an open admin slot on that date (and time window) are returned. Map the app's `SearchFilters` like this:
`dayIndex` → `date` (today + N days), `timeWindow` index 0/1/2/3 → `any/morning/evening/afternoon`,
`radius` index 0/1/2/3 → `radiusKm` 2/5/10/(omit), `environment` index 0/1/2/3 → `indoor/outdoor/rooftop/all`,
`surfaces`/`facilities` → comma separated names, `rate` → `minRate`/`maxRate`. The result count for the filter button is `count`.

### Bookings, match pass, wallet (Auth = yes)
| Method & path | Notes |
|---|---|
| `POST /bookings` | `{slotId, paymentMethod:"wallet"\|"pay_at_venue", maxPlayers?}` → booking (time + price come from the slot). 402 if wallet too low, 409 if slot taken |
| `GET /bookings?status=upcoming\|past\|all` | my bookings |
| `GET /bookings/:id` | one booking |
| `POST /bookings/:id/cancel` | free until 2 h before start, wallet refunded |
| `POST /bookings/:id/players` · `DELETE /bookings/:id/players/:playerId` | add / remove a teammate `{name, ready?}` |
| `GET /bookings/:id/pass` · `GET /match-pass` | Digital Match Pass (`MatchPass` model): arena, timeSlot, pin, session, lockers, roster, `qrData`. `/match-pass` = next upcoming booking (404 if none) |
| `GET /wallet` | `{balance, transactions[]}` |
| `POST /wallet/topup` | `{amount}` **dev only** (`ALLOW_DEV_TOPUP=true`). In production connect a payment gateway (PayHere, Stripe ...) |

Finished bookings automatically count towards matches played, court time and money saved the next time the profile is loaded.

## Admin panel API

Login: `POST /admin/auth/login {email, password}` → `{accessToken, user}` (only accounts with role `admin`).
Everything else needs `Authorization: Bearer <accessToken>`; customers get 403. Times are Colombo time. Money is LKR.

| Method & path | What it does |
|---|---|
| `GET /admin/me` | the logged-in admin |
| `GET /admin/dashboard` | totals, open/booked slots, bookings today/upcoming/completed/cancelled, revenue, last 7 days, today's bookings, recent bookings, top facilities |
| `GET/POST /admin/sports` · `PUT/DELETE /admin/sports/:name` | sports `{name, icon}` |
| `GET/POST /admin/venues` · `GET/PUT/DELETE /admin/venues/:id` | **facilities**: `{name, address, area, lat, lng, distanceKm, surfaceLabel, imageAsset, gate, openHour, closeHour, guidelines[], photos[], amenities[{icon,title,subtitle}], facilities[], active}`. `PUT` is partial; lists you send replace the stored list |
| `GET /admin/courts?venueId=` · `POST /admin/venues/:venueId/courts` · `GET/PUT/DELETE /admin/courts/:id` | courts `{sport, name, price (LKR/hour), surface, environment, tag, listingTag, description, imageAsset, topPick, instantLock, certified, amenityTags[], active}` |
| `GET /admin/slots?courtId=&venueId=&date=\|from=&to=&status=open\|booked\|all` | slots with status `open / booked / disabled / expired` and who booked |
| `POST /admin/courts/:courtId/slots` | one slot `{date, startTime:"18:00", endTime:"19:00", price?}` (price defaults to court rate × hours) |
| `POST /admin/courts/:courtId/slots/bulk` | many slots `{fromDate, toDate, daysOfWeek?:[0-6], startTime, endTime, slotMinutes, price?}` (max 500; past or overlapping times are skipped) |
| `PUT/DELETE /admin/slots/:id` | change `{date,startTime,endTime,price,active}` / delete. A slot with a live booking is locked (409) |
| `GET /admin/bookings?status=&venueId=&courtId=&date=&q=&limit=&offset=` · `GET /admin/bookings/:id` | all customers' bookings |
| `POST /admin/bookings/:id/cancel` | cancel any upcoming booking, wallet payments are refunded |
| `GET /admin/users?q=` | customer list (read only) |

Facilities or courts that already have bookings cannot be deleted (409), set `active:false` to hide them from customers.
Existing databases are upgraded automatically (`db/migrations/002_admin.sql`: `users.role`, `court_slots`, `bookings.slot_id`).

## OTP (no SMS gateway yet)

`OTP_DEV_MODE=true` (default in dev): the code is printed in the backend terminal as `[SMS -> +94...]`
and returned to the app (shown on the OTP screen with an **Autofill** button).
For real SMS write a class with a `send(toE164, message)` method (Twilio, Dialog, Notify.lk ...) and use it in
`src/app.module.ts` instead of `ConsoleSmsSender`. In production (`NODE_ENV=production`) `JWT_SECRET` is required and the code is never returned to the app.

## Troubleshooting

* `Cannot use PostgreSQL at ...` on start → Postgres is not running or `DATABASE_URL` is wrong.
* App says "Can't reach the server" → see the URLs in step 3; phone and PC must be on the same Wi-Fi; allow Node through the firewall.
* Want a clean database → `npm run db:reset`.
