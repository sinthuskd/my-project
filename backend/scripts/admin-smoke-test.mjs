// Tests the ADMIN panel API end to end:  npm run smoke:admin
// Needs the server running with ADMIN_EMAIL / ADMIN_PASSWORD set in .env (pass them again here):
//   ADMIN_EMAIL=admin@sportsbook.lk ADMIN_PASSWORD=... npm run smoke:admin
// It creates a "Smoke Arena" (facility + court + slots), checks that a customer sees and can book the slot,
// then deletes everything it created.
const BASE = process.argv[2] || process.env.API_URL || 'http://127.0.0.1:3000';
const ADMIN_EMAIL = process.env.ADMIN_EMAIL;
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD;

let failed = 0;
const ok = (n) => console.log(`  ✔ ${n}`);
const fail = (n, i) => { failed++; console.log(`  ✘ ${n}\n      ${i}`); };
const expect = (n, c, i) => (c ? ok(n) : fail(n, i));

async function call(method, path, body, token) {
  const res = await fetch(BASE + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  let data = {};
  try { data = await res.json(); } catch {}
  return { status: res.status, data };
}

if (!ADMIN_EMAIL || !ADMIN_PASSWORD) {
  console.log('Set ADMIN_EMAIL and ADMIN_PASSWORD (same values as backend/.env) and run again.');
  process.exit(1);
}

const pad = (n) => String(n).padStart(2, '0');
const colombo = (offsetDays) => {
  const t = new Date(Date.now() + 5.5 * 3600e3 + offsetDays * 24 * 3600e3);
  return `${t.getUTCFullYear()}-${pad(t.getUTCMonth() + 1)}-${pad(t.getUTCDate())}`;
};
const tomorrow = colombo(1);
console.log(`Testing admin API at ${BASE}\n`);

let r = await call('POST', '/admin/auth/login', { email: ADMIN_EMAIL, password: 'wrong-password-x' });
expect('admin login with wrong password -> 401', r.status === 401, JSON.stringify(r));
r = await call('POST', '/admin/auth/login', { email: ADMIN_EMAIL, password: ADMIN_PASSWORD });
expect('admin login -> token', r.status === 200 && r.data.accessToken && r.data.user?.role === 'admin', JSON.stringify(r));
const A = r.data.accessToken;

r = await call('GET', '/admin/dashboard');
expect('dashboard without token -> 401', r.status === 401, JSON.stringify(r));

// a normal customer must not get in
const rnd = Math.floor(Math.random() * 1e7).toString().padStart(7, '0');
const phone = '77' + rnd, email = `adminsmoke${rnd}@example.com`, password = 'Smoke#Test1';
r = await call('POST', '/auth/register', { fullName: 'Smoke Customer', phone, email, password, sports: ['Badminton'] });
const otp = r.data.devOtp;
r = await call('POST', '/auth/verify-otp', { phone, code: otp });
const U = r.data.accessToken;
expect('customer registered (OTP_DEV_MODE=true needed)', !!U, JSON.stringify(r));
r = await call('GET', '/admin/dashboard', null, U);
expect('customer token on admin API -> 403', r.status === 403, JSON.stringify(r));
r = await call('POST', '/admin/auth/login', { email, password });
expect('customer cannot use admin login -> 401', r.status === 401, JSON.stringify(r));

r = await call('GET', '/admin/dashboard', null, A);
expect('GET /admin/dashboard', r.status === 200 && r.data.totals && r.data.bookings && Array.isArray(r.data.last7Days), JSON.stringify(r).slice(0, 300));

// sport
const sport = `SmokeSport${rnd}`;
r = await call('POST', '/admin/sports', { name: sport, icon: 'sports_tennis' }, A);
expect('POST /admin/sports', r.status === 201 && r.data.name === sport, JSON.stringify(r));
r = await call('POST', '/admin/sports', { name: sport }, A);
expect('duplicate sport -> 409', r.status === 409, JSON.stringify(r));

// facility (place)
r = await call('POST', '/admin/venues', { name: 'Smoke Arena', address: '1 Test Road', area: 'Colombo 03', imageAsset: 'assets/images/court_royal.jpg', openHour: 6, closeHour: 22, facilities: ['On-premise Free Parking'] }, A);
expect('POST /admin/venues (create facility)', r.status === 201 && r.data.id && r.data.facilities?.length === 1, JSON.stringify(r));
const venueId = r.data.id;
r = await call('POST', '/admin/venues', { name: 'x' }, A);
expect('facility without address -> 400', r.status === 400, JSON.stringify(r));
r = await call('PUT', `/admin/venues/${venueId}`, { area: 'Colombo 07' }, A);
expect('PUT /admin/venues/:id (update)', r.status === 200 && r.data.area === 'Colombo 07' && r.data.name === 'Smoke Arena', JSON.stringify(r));

// court
r = await call('POST', `/admin/venues/${venueId}/courts`, { sport, name: 'Court 1', price: 2000, surface: 'Wooden Parquet', environment: 'indoor' }, A);
expect('POST /admin/venues/:id/courts', r.status === 201 && r.data.id, JSON.stringify(r));
const courtId = r.data.id;
r = await call('POST', `/admin/venues/${venueId}/courts`, { sport: 'NoSuchSport', name: 'C', price: 100 }, A);
expect('court with unknown sport -> 400', r.status === 400, JSON.stringify(r));

// slots
r = await call('POST', `/admin/courts/${courtId}/slots`, { date: tomorrow, startTime: '18:00', endTime: '19:00', price: 2500 }, A);
expect('POST slot 18:00-19:00 @ 2500', r.status === 201 && r.data.price === 2500 && r.data.status === 'open', JSON.stringify(r));
const slotId = r.data.id;
r = await call('POST', `/admin/courts/${courtId}/slots`, { date: tomorrow, startTime: '18:30', endTime: '19:30' }, A);
expect('overlapping slot -> 409', r.status === 409, JSON.stringify(r));
r = await call('POST', `/admin/courts/${courtId}/slots`, { date: tomorrow, startTime: '20:00', endTime: '21:00' }, A);
expect('slot without price uses court rate (2000/h)', r.status === 201 && r.data.price === 2000, JSON.stringify(r));
const slot2 = r.data.id;
r = await call('POST', `/admin/courts/${courtId}/slots/bulk`, { fromDate: tomorrow, toDate: tomorrow, startTime: '06:00', endTime: '09:00', slotMinutes: 60, price: 1500 }, A);
expect('bulk slots 06:00-09:00 x 60min', r.status === 200 && r.data.created === 3, JSON.stringify(r));
r = await call('POST', `/admin/courts/${courtId}/slots/bulk`, { fromDate: tomorrow, toDate: tomorrow, startTime: '06:00', endTime: '09:00', slotMinutes: 60 }, A);
expect('bulk again skips existing', r.status === 200 && r.data.created === 0 && r.data.skipped === 3, JSON.stringify(r));
r = await call('PUT', `/admin/slots/${slot2}`, { price: 2100 }, A);
expect('PUT /admin/slots/:id (price)', r.status === 200 && r.data.price === 2100, JSON.stringify(r));
r = await call('GET', `/admin/slots?courtId=${courtId}&date=${tomorrow}`, null, A);
expect('GET /admin/slots', r.status === 200 && r.data.count === 5, JSON.stringify(r).slice(0, 300));

// what the customer sees
r = await call('GET', `/courts/${courtId}/slots?date=${tomorrow}`);
expect('customer sees the 5 admin slots with prices', r.status === 200 && r.data.slots.length === 5 && r.data.slots.some((s) => s.id === slotId && s.price === 2500), JSON.stringify(r).slice(0, 300));
r = await call('GET', `/listings?date=${tomorrow}&sport=${encodeURIComponent(sport)}`);
expect('search by sport finds the facility', r.status === 200 && r.data.count === 1 && r.data.items[0].courtId === courtId, JSON.stringify(r).slice(0, 300));
r = await call('GET', `/listings?date=${tomorrow}&sport=${encodeURIComponent(sport)}&timeWindow=morning`);
expect('morning filter shows only morning slots', r.status === 200 && r.data.items[0]?.slots.every((s) => Number(s.time24.slice(0, 2)) < 12), JSON.stringify(r).slice(0, 300));
r = await call('GET', `/listings?date=${tomorrow}&q=Smoke%20Arena`);
expect('text search by name', r.status === 200 && r.data.count >= 1, JSON.stringify(r).slice(0, 300));

// customer books -> admin sees it
r = await call('POST', '/wallet/topup', { amount: 10000 }, U);
expect('wallet topup (dev)', r.status === 200, JSON.stringify(r));
r = await call('POST', '/bookings', { slotId }, U);
expect('customer books slot @ 2500', r.status === 201 && r.data.totalLkr === 2500, JSON.stringify(r));
const bookingId = r.data.id;
r = await call('POST', '/bookings', { slotId }, U);
expect('booked slot cannot be booked again -> 409', r.status === 409, JSON.stringify(r));
r = await call('GET', `/courts/${courtId}/slots?date=${tomorrow}`);
expect('booked slot disappears for customers', r.status === 200 && r.data.slots.length === 4 && !r.data.slots.some((s) => s.id === slotId), JSON.stringify(r).slice(0, 300));
r = await call('PUT', `/admin/slots/${slotId}`, { price: 1 }, A);
expect('booked slot cannot be edited -> 409', r.status === 409, JSON.stringify(r));
r = await call('DELETE', `/admin/slots/${slotId}`, null, A);
expect('booked slot cannot be deleted -> 409', r.status === 409, JSON.stringify(r));
r = await call('GET', `/admin/bookings?venueId=${venueId}`, null, A);
expect('GET /admin/bookings shows it', r.status === 200 && r.data.total === 1 && r.data.items[0].user.email === email, JSON.stringify(r).slice(0, 300));
r = await call('GET', '/admin/dashboard', null, A);
expect('dashboard counts the booking', r.status === 200 && r.data.bookings.upcoming >= 1 && r.data.revenueLkr.collected >= 2500, JSON.stringify(r).slice(0, 300));
r = await call('POST', `/admin/bookings/${bookingId}/cancel`, null, A);
expect('admin cancels booking (refund)', r.status === 200 && r.data.status === 'cancelled' && r.data.paymentStatus === 'refunded', JSON.stringify(r));
r = await call('GET', '/wallet', null, U);
expect('customer wallet refunded', r.status === 200 && r.data.balance === 10000, JSON.stringify(r));
r = await call('GET', `/courts/${courtId}/slots?date=${tomorrow}`);
expect('slot is open again after cancel', r.status === 200 && r.data.slots.length === 5, JSON.stringify(r).slice(0, 200));

// clean up what this test created
r = await call('DELETE', `/admin/venues/${venueId}`, null, A);
expect('delete facility with only cancelled booking -> 409 (history kept)', r.status === 409, JSON.stringify(r));
r = await call('PUT', `/admin/venues/${venueId}`, { active: false }, A);
expect('hide facility instead (active=false)', r.status === 200 && r.data.active === false, JSON.stringify(r));
r = await call('GET', `/listings?date=${tomorrow}&sport=${encodeURIComponent(sport)}`);
expect('hidden facility disappears from search', r.status === 200 && r.data.count === 0, JSON.stringify(r).slice(0, 200));

console.log(failed ? `\n${failed} check(s) FAILED` : '\nAll admin checks passed ✔  (the hidden "Smoke Arena" can be deleted from the admin panel later)');
process.exit(failed ? 1 : 0);
