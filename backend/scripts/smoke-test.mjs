// Tests the running backend WITHOUT Flutter:  npm run smoke
// Needs the server running with OTP_DEV_MODE=true (the default in .env.example).
const BASE = process.argv[2] || process.env.API_URL || 'http://127.0.0.1:3000';

let failed = 0;
const ok = (name) => console.log(`  ✔ ${name}`);
const fail = (name, info) => { failed++; console.log(`  ✘ ${name}\n      ${info}`); };

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
function expect(name, cond, info) { cond ? ok(name) : fail(name, info); }

const rnd = Math.floor(Math.random() * 1e7).toString().padStart(7, '0');
const phone = '77' + rnd;
const email = `smoke${rnd}@example.com`;
const password = 'Smoke#Test1';

console.log(`Testing ${BASE}\n`);

let r;
try {
  r = await call('GET', '/health');
} catch (e) {
  console.log(`  ✘ Cannot reach ${BASE}\n      ${e.cause?.message || e.message}\n      -> Is the backend running? (npm run start:dev)`);
  process.exit(1);
}
expect('GET /health (server + PostgreSQL)', r.status === 200 && r.data.status === 'ok' && r.data.database === 'ok', JSON.stringify(r));

r = await call('POST', '/auth/register', { fullName: 'Smoke Tester', phone, email, password, sports: ['Badminton', 'Tennis'] });
expect('POST /auth/register -> 201', r.status === 201, JSON.stringify(r));
const otp = r.data.devOtp;
expect('devOtp returned (OTP_DEV_MODE=true)', /^\d{6}$/.test(otp || ''), 'Set OTP_DEV_MODE=true in backend/.env, or read the code from the backend terminal');

r = await call('POST', '/auth/login', { identifier: email, password });
expect('login before OTP -> 403 PHONE_NOT_VERIFIED', r.status === 403 && r.data.code === 'PHONE_NOT_VERIFIED', JSON.stringify(r));

r = await call('POST', '/auth/verify-otp', { phone, code: otp === '000000' ? '111111' : '000000' });
expect('wrong OTP -> 400', r.status === 400, JSON.stringify(r));

r = await call('POST', '/auth/verify-otp', { phone, code: otp });
expect('verify-otp -> 200 + token + user', r.status === 200 && r.data.accessToken && r.data.user?.email === email, JSON.stringify(r));

r = await call('POST', '/auth/login', { identifier: email, password: 'wrong-password' });
expect('login wrong password -> 401', r.status === 401, JSON.stringify(r));

r = await call('POST', '/auth/login', { identifier: email, password });
expect('login -> 200 + token', r.status === 200 && !!r.data.accessToken, JSON.stringify(r));
const token = r.data.accessToken;

r = await call('POST', '/auth/login', { identifier: phone, password });
expect('login with mobile number -> 200', r.status === 200, JSON.stringify(r));

r = await call('GET', '/auth/me', null, token);
expect('GET /auth/me -> profile', r.status === 200 && r.data.fullName === 'Smoke Tester' && r.data.phoneVerified === true, JSON.stringify(r));

r = await call('GET', '/auth/me');
expect('GET /auth/me without token -> 401', r.status === 401, JSON.stringify(r));

r = await call('POST', '/auth/register', { fullName: 'Smoke Tester', phone, email, password, sports: ['Tennis'] });
expect('register again -> 409', r.status === 409, JSON.stringify(r));

// ---------------- catalogue (public) ----------------
// The project has NO dummy data: these checks adapt to whatever is in your database.
r = await call('GET', '/categories');
expect('GET /categories', r.status === 200 && Array.isArray(r.data), JSON.stringify(r));
r = await call('GET', '/courts');
expect('GET /courts', r.status === 200 && Array.isArray(r.data), JSON.stringify(r).slice(0, 300));
const cards = Array.isArray(r.data) ? r.data : [];

const pad = (n) => String(n).padStart(2, '0');
const t = new Date(Date.now() + 5.5 * 3600e3 + 24 * 3600e3); // tomorrow, Colombo time
const tomorrow = `${t.getUTCFullYear()}-${pad(t.getUTCMonth() + 1)}-${pad(t.getUTCDate())}`;

r = await call('GET', `/listings?date=${tomorrow}`);
expect('GET /listings (search)', r.status === 200 && typeof r.data.count === 'number' && Array.isArray(r.data.items), JSON.stringify(r).slice(0, 300));

let courtId = null;
let slot = null;
if (cards.length === 0) {
  console.log('  - No venues/courts in the database yet: skipping venue, slots and booking checks.');
  console.log('    (add your real data first, see src/db/seed-data.ts)');
} else {
  r = await call('GET', `/venues/${cards[0].id}`);
  expect('GET /venues/:id', r.status === 200 && Array.isArray(r.data.courts), JSON.stringify(r).slice(0, 300));
  courtId = r.data.courts?.[0]?.id ?? null;
  if (courtId) {
    r = await call('GET', `/courts/${courtId}/slots?date=${tomorrow}`);
    expect('GET /courts/:id/slots', r.status === 200 && Array.isArray(r.data.slots), JSON.stringify(r).slice(0, 300));
    slot = r.data.slots?.[0] ?? null;
    if (!slot) console.log('  - The admin has not created a slot for tomorrow on the first court: booking checks skipped (npm run smoke:admin tests them).');
  }
}

// ---------------- wallet + booking (needs login) ----------------
r = await call('GET', '/bookings');
expect('GET /bookings without token -> 401', r.status === 401, JSON.stringify(r));

if (slot) {
  const TOPUP = 1000000; // big enough for any slot price
  r = await call('POST', '/bookings', { slotId: slot.id }, token);
  expect('book with empty wallet -> 402', r.status === 402, JSON.stringify(r));
  r = await call('POST', '/bookings', { courtId, date: tomorrow, startTime: '18:00' }, token);
  expect('booking without slotId -> 400', r.status === 400, JSON.stringify(r));
  r = await call('POST', '/wallet/topup', { amount: TOPUP }, token);
  expect('POST /wallet/topup (dev)', r.status === 200 && r.data.balance === TOPUP, JSON.stringify(r) + '  (set ALLOW_DEV_TOPUP=true)');
  r = await call('POST', '/bookings', { slotId: slot.id }, token);
  expect('POST /bookings (slot) -> confirmed', r.status === 201 && r.data.status === 'confirmed' && r.data.ref?.startsWith('#SB-COL-') && r.data.totalLkr === slot.price, JSON.stringify(r));
  const bookingId = r.data.id;
  r = await call('POST', '/bookings', { slotId: slot.id }, token);
  expect('same slot again -> 409', r.status === 409, JSON.stringify(r));
  r = await call('GET', '/match-pass', null, token);
  expect('GET /match-pass', r.status === 200 && r.data.arena && r.data.roster?.length === 1 && /^\d{4}$/.test(r.data.pin), JSON.stringify(r));
  r = await call('POST', `/bookings/${bookingId}/players`, { name: 'Test Player' }, token);
  expect('POST /bookings/:id/players', r.status === 201 && r.data.players.length === 2, JSON.stringify(r));
  r = await call('POST', `/bookings/${bookingId}/cancel`, null, token);
  expect('POST /bookings/:id/cancel (refund)', r.status === 200 && r.data.status === 'cancelled' && r.data.paymentStatus === 'refunded', JSON.stringify(r));
  r = await call('GET', '/wallet', null, token);
  expect('wallet refunded to full top-up', r.status === 200 && r.data.balance === TOPUP, JSON.stringify(r));
}

console.log(failed ? `\n${failed} check(s) FAILED` : '\nAll checks passed ✔  Backend is working.');
process.exit(failed ? 1 : 0);
