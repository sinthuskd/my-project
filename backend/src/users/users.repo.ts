import { Injectable } from '@nestjs/common';
import { Db } from '../db/db.service';
import { StoredUser } from './user.model';

const COLS = `id, full_name, email, phone, password_hash, sports, phone_verified, role, otp_hash, otp_expires_at,
  otp_attempts, otp_sent_at, matches_played, court_time_hours, saved_lkr, fairplay, wallet_balance, created_at`;

function map(r: any): StoredUser {
  return {
    id: r.id,
    fullName: r.full_name,
    email: r.email,
    phone: r.phone,
    passwordHash: r.password_hash,
    sports: r.sports,
    phoneVerified: r.phone_verified,
    role: r.role,
    otpHash: r.otp_hash,
    otpExpiresAt: r.otp_expires_at ? new Date(r.otp_expires_at).getTime() : null,
    otpAttempts: r.otp_attempts,
    otpSentAt: r.otp_sent_at ? new Date(r.otp_sent_at).getTime() : null,
    matchesPlayed: r.matches_played,
    courtTimeHours: r.court_time_hours,
    savedLkr: r.saved_lkr,
    fairplay: r.fairplay,
    walletBalance: r.wallet_balance,
    createdAt: new Date(r.created_at).toISOString(),
  };
}

/** All SQL for the users table. */
@Injectable()
export class UsersRepo {
  constructor(private readonly db: Db) {}

  async findById(id: string) {
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) return undefined;
    const r = await this.db.one(`SELECT ${COLS} FROM users WHERE id = $1`, [id]);
    return r ? map(r) : undefined;
  }
  async findByEmail(email: string) {
    const r = await this.db.one(`SELECT ${COLS} FROM users WHERE email = $1`, [email.trim().toLowerCase()]);
    return r ? map(r) : undefined;
  }
  async findByPhone(phoneE164: string) {
    const r = await this.db.one(`SELECT ${COLS} FROM users WHERE phone = $1`, [phoneE164]);
    return r ? map(r) : undefined;
  }

  /**
   * Creates the account. Unverified accounts that use the same email/phone are removed first
   * (someone who registered earlier but never finished OTP can start over).
   * Throws a pg error with code 23505 if a *verified* account owns the email/phone (race safety).
   */
  async createPending(d: {
    fullName: string; email: string; phone: string; passwordHash: string; sports: string[];
  }): Promise<StoredUser> {
    return this.db.tx(async (c) => {
      await c.query(`DELETE FROM users WHERE phone_verified = false AND (email = $1 OR phone = $2)`, [d.email, d.phone]);
      const r = await c.query(
        `INSERT INTO users(full_name, email, phone, password_hash, sports)
         VALUES ($1,$2,$3,$4,$5) RETURNING ${COLS}`,
        [d.fullName, d.email, d.phone, d.passwordHash, d.sports],
      );
      return map(r.rows[0]);
    });
  }

  async setOtp(id: string, otpHash: string, expiresAt: number, sentAt: number) {
    await this.db.query(
      `UPDATE users SET otp_hash=$2, otp_expires_at=to_timestamp($3/1000.0), otp_attempts=0,
         otp_sent_at=to_timestamp($4/1000.0) WHERE id=$1`,
      [id, otpHash, expiresAt, sentAt],
    );
  }

  /** Returns the new attempt count. */
  async bumpOtpAttempts(id: string): Promise<number> {
    const r = await this.db.one<{ otp_attempts: number }>(
      `UPDATE users SET otp_attempts = otp_attempts + 1 WHERE id=$1 RETURNING otp_attempts`, [id]);
    return r?.otp_attempts ?? 0;
  }

  async markVerified(id: string) {
    await this.db.query(
      `UPDATE users SET phone_verified=true, otp_hash=NULL, otp_expires_at=NULL, otp_attempts=0 WHERE id=$1`, [id]);
  }
}
