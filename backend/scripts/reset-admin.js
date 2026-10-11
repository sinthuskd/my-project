// Resets the admin account so it matches ADMIN_EMAIL / ADMIN_PASSWORD in backend/.env
// Run from the backend folder:   npm run build && node scripts/reset-admin.js
const { loadEnvFile } = require('../dist/common/env');
loadEnvFile();
const { hashPassword, verifyPassword } = require('../dist/common/security');
const { Pool } = require('pg');

(async () => {
  const email = (process.env.ADMIN_EMAIL || '').trim().toLowerCase();
  const password = process.env.ADMIN_PASSWORD || '';
  if (!email || password.length < 8) {
    console.log('Set ADMIN_EMAIL and ADMIN_PASSWORD (8+ chars) in .env first');
    process.exit(1);
  }

  const pool = new Pool({
    connectionString:
      process.env.DATABASE_URL || 'postgres://sportsbook:sportsbook@localhost:5432/sportsbook',
    ssl: process.env.PGSSL === 'true' ? { rejectUnauthorized: false } : undefined,
  });

  const hash = await hashPassword(password);
  const r = await pool.query(
    `UPDATE users SET password_hash = $1, role = 'admin', phone_verified = true WHERE email = $2`,
    [hash, email],
  );
  const row = (
    await pool.query('SELECT email, role, password_hash FROM users WHERE email = $1', [email])
  ).rows[0];

  console.log('email:', email);
  console.log('rows updated:', r.rowCount);
  console.log(
    'role:', row?.role,
    '| password matches .env:', row ? await verifyPassword(password, row.password_hash) : false,
  );
  await pool.end();
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});