import { Pool } from 'pg';
import { AppConfig } from '../common/env';
import { hashPassword } from '../common/security';

/**
 * Creates (or promotes) the first admin from ADMIN_EMAIL / ADMIN_PASSWORD in .env.
 * An existing account keeps its password; it is only given the admin role.
 * Returns a short message, or null when ADMIN_EMAIL / ADMIN_PASSWORD are not set.
 */
export async function ensureAdmin(pool: Pool, cfg: AppConfig): Promise<string | null> {
  if (!cfg.adminEmail || !cfg.adminPassword) return null;
  if (cfg.adminPassword.length < 8) throw new Error('ADMIN_PASSWORD must be at least 8 characters');

  const existing = (await pool.query('SELECT id, role FROM users WHERE email = $1', [cfg.adminEmail])).rows[0];
  if (existing) {
    if (existing.role === 'admin') return `admin ${cfg.adminEmail} is ready`;
    await pool.query(`UPDATE users SET role = 'admin', phone_verified = true WHERE id = $1`, [existing.id]);
    return `existing account ${cfg.adminEmail} is now an admin`;
  }
  try {
    await pool.query(
      `INSERT INTO users(full_name, email, phone, password_hash, sports, phone_verified, role)
       VALUES ($1, $2, $3, $4, '{}', true, 'admin')`,
      [cfg.adminName, cfg.adminEmail, cfg.adminPhone, await hashPassword(cfg.adminPassword)],
    );
  } catch (e: any) {
    if (e?.code === '23505') throw new Error(`Cannot create admin: phone ${cfg.adminPhone} is already used. Set ADMIN_PHONE in .env`);
    throw e;
  }
  return `admin ${cfg.adminEmail} created`;
}
