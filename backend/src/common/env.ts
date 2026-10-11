import { existsSync, readFileSync } from 'fs';
import { resolve } from 'path';

export interface AppConfig {
  port: number;
  jwtSecret: string;
  tokenTtlSeconds: number;
  otpDevMode: boolean;
  databaseUrl: string;
  pgSsl: boolean;
  autoMigrate: boolean;
  autoSeed: boolean;
  allowDevTopup: boolean;
  paymentOtp: boolean;
  production: boolean;
  adminEmail: string;
  adminPassword: string;
  adminName: string;
  adminPhone: string;
}

/** Tiny .env loader (no dependency). Real environment variables win. */
export function loadEnvFile(path = '.env'): void {
  const file = resolve(process.cwd(), path);
  if (!existsSync(file)) return;
  for (const raw of readFileSync(file, 'utf8').split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq < 1) continue;
    const key = line.slice(0, eq).trim();
    let value = line.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (process.env[key] === undefined) process.env[key] = value;
  }
}

const flag = (v: string | undefined, dflt: boolean) =>
  v === undefined || v === '' ? dflt : v.toLowerCase() === 'true';

let cached: AppConfig | undefined;

export function loadConfig(): AppConfig {
  if (cached) return cached;
  const production = process.env.NODE_ENV === 'production';

  let jwtSecret = process.env.JWT_SECRET;
  if (!jwtSecret) {
    if (production) throw new Error('JWT_SECRET must be set in production');
    console.warn('[config] JWT_SECRET not set -> using insecure dev secret. Copy .env.example to .env');
    jwtSecret = 'dev-only-secret-change-me';
  }

  const devFlag = (process.env.OTP_DEV_MODE ?? (production ? 'false' : 'true')).toLowerCase() === 'true';
  if (production && devFlag) {
    console.warn('[config] OTP_DEV_MODE ignored in production');
  }

  const days = Number(process.env.TOKEN_TTL_DAYS) || 7;

  cached = {
    port: Number(process.env.PORT) || 3000,
    jwtSecret,
    tokenTtlSeconds: days * 24 * 60 * 60,
    otpDevMode: production ? false : devFlag,
    databaseUrl:
      process.env.DATABASE_URL || 'postgres://sportsbook:sportsbook@localhost:5432/sportsbook',
    pgSsl: flag(process.env.PGSSL, false),
    autoMigrate: flag(process.env.AUTO_MIGRATE, true),
    autoSeed: flag(process.env.AUTO_SEED, false),
    allowDevTopup: flag(process.env.ALLOW_DEV_TOPUP, !production),
    paymentOtp: flag(process.env.PAYMENT_OTP, true),
    production,
    adminEmail: (process.env.ADMIN_EMAIL || '').trim().toLowerCase(),
    adminPassword: process.env.ADMIN_PASSWORD || '',
    adminName: (process.env.ADMIN_NAME || 'Administrator').trim(),
    adminPhone: (process.env.ADMIN_PHONE || '+94700000000').trim(),
  };
  return cached;
}
