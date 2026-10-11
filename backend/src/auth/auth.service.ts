import { Inject, Injectable } from '@nestjs/common';
import { AppConfig, loadConfig } from '../common/env';
import { HttpError } from '../common/http-error';
import { normalizeLkPhone, toE164 } from '../common/phone';
import {
  generateOtp,
  hashOtp,
  hashPassword,
  safeEqualHex,
  signToken,
  verifyPassword,
  verifyToken,
} from '../common/security';
import { SMS_SENDER, SmsSender } from '../sms/sms.sender';
import { StoredUser, toPublicUser } from '../users/user.model';
import { UsersRepo } from '../users/users.repo';
import { BookingsService } from '../bookings/bookings.service';

export const SPORTS = ['Badminton', 'Tennis', 'Basketball', 'Padel & TT'];

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const OTP_TTL_MS = 5 * 60 * 1000;
const OTP_RESEND_MS = 30 * 1000;
const OTP_MAX_ATTEMPTS = 5;
const LOGIN_MAX_FAILS = 10;
const LOGIN_WINDOW_MS = 15 * 60 * 1000;

const bad = (msg: string) => new HttpError(400, msg);

function asObject(body: unknown): Record<string, unknown> {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    throw bad('Invalid request body');
  }
  return body as Record<string, unknown>;
}
const str = (v: unknown) => (typeof v === 'string' ? v : '');

@Injectable()
export class AuthService {
  private loginFails = new Map<string, { count: number; first: number }>();

  private readonly cfg: AppConfig = loadConfig();

  constructor(
    private readonly store: UsersRepo,
    @Inject(SMS_SENDER) private readonly sms: SmsSender,
    private readonly bookings: BookingsService,
  ) {}

  /* ------------------------------ register ------------------------------ */

  async register(body: unknown) {
    const b = asObject(body);

    const fullName = str(b.fullName).trim();
    if (fullName.length < 2 || fullName.length > 100) throw bad('Enter your full name');

    const national = normalizeLkPhone(b.phone);
    if (!national) throw bad('Mobile number must be 9 digits, e.g. 771234567');

    const email = str(b.email).trim().toLowerCase();
    if (!EMAIL_RE.test(email) || email.length > 254) throw bad('Enter a valid email');

    const password = str(b.password);
    if (password.length < 8) throw bad('Password must be at least 8 characters');
    if (password.length > 128) throw bad('Password is too long');

    const sports = Array.isArray(b.sports) ? [...new Set(b.sports.map(String))] : [];
    if (sports.length < 1) throw bad('Pick at least 1 favorite sport');
    if (sports.some((s) => !SPORTS.includes(s))) throw bad('Unknown sport selected');

    const phone = toE164(national);
    const byEmail = await this.store.findByEmail(email);
    const byPhone = await this.store.findByPhone(phone);

    if (byEmail?.phoneVerified) throw new HttpError(409, 'This email is already registered');
    if (byPhone?.phoneVerified) throw new HttpError(409, 'This mobile number is already registered');

    let user: StoredUser;
    try {
      // removes any unverified account with this email/phone, then inserts (one transaction)
      user = await this.store.createPending({
        fullName, email, phone, passwordHash: await hashPassword(password), sports,
      });
    } catch (e: any) {
      if (e?.code === '23505') throw new HttpError(409, 'This email or mobile number is already registered');
      throw e;
    }

    const code = await this.issueOtp(user);
    return this.challenge(user, code, 'Verification code sent');
  }

  /* ------------------------------ verify otp ------------------------------ */

  async verifyOtp(body: unknown) {
    const b = asObject(body);
    const national = normalizeLkPhone(b.phone);
    const code = str(b.code).trim();
    if (!national) throw bad('Enter a valid mobile number');
    if (!/^\d{6}$/.test(code)) throw bad('Enter the 6-digit code');

    const user = await this.store.findByPhone(toE164(national));
    if (!user) throw bad('No registration found for this number');
    if (user.phoneVerified) throw new HttpError(409, 'Mobile already verified. Please log in.');
    if (!user.otpHash || !user.otpExpiresAt) throw bad('No active code. Please request a new one.');
    if (Date.now() > user.otpExpiresAt) throw bad('Code expired. Please request a new one.');
    if (user.otpAttempts >= OTP_MAX_ATTEMPTS) {
      throw new HttpError(429, 'Too many wrong attempts. Please request a new code.');
    }

    const ok = safeEqualHex(hashOtp(code, user.phone, this.cfg.jwtSecret), user.otpHash);
    if (!ok) {
      const attempts = await this.store.bumpOtpAttempts(user.id);
      const left = OTP_MAX_ATTEMPTS - attempts;
      throw bad(
        left > 0
          ? `Incorrect code. ${left} attempt${left === 1 ? '' : 's'} left.`
          : 'Too many wrong attempts. Please request a new code.',
      );
    }

    await this.store.markVerified(user.id);
    user.phoneVerified = true;

    return this.session(user);
  }

  /* ------------------------------ resend otp ------------------------------ */

  async resendOtp(body: unknown) {
    const b = asObject(body);
    const national = normalizeLkPhone(b.phone);
    if (!national) throw bad('Enter a valid mobile number');

    const user = await this.store.findByPhone(toE164(national));
    if (!user) throw new HttpError(404, 'No pending registration for this number');
    if (user.phoneVerified) throw new HttpError(409, 'Mobile already verified. Please log in.');

    const wait = this.cooldownLeft(user);
    if (wait > 0) {
      throw new HttpError(429, `Please wait ${wait}s before requesting another code`, { retryAfter: wait });
    }

    const code = await this.issueOtp(user);
    return this.challenge(user, code, 'Verification code sent');
  }

  /* ------------------------------ login ------------------------------ */

  async login(body: unknown) {
    const b = asObject(body);
    const identifier = str(b.identifier).trim();
    const password = str(b.password);
    if (!identifier) throw bad('Enter your username or email');
    if (!password) throw bad('Enter your password');

    this.assertNotLocked(identifier);

    let user: StoredUser | undefined;
    if (identifier.includes('@')) {
      user = await this.store.findByEmail(identifier);
    } else {
      const national = normalizeLkPhone(identifier);
      user = national ? await this.store.findByPhone(toE164(national)) : undefined;
    }

    const ok = user ? await verifyPassword(password, user.passwordHash) : false;
    if (!user || !ok) {
      this.recordFail(identifier);
      throw new HttpError(401, 'Invalid email/mobile or password');
    }
    this.loginFails.delete(identifier.toLowerCase());

    if (!user.phoneVerified) {
      // Correct password but never finished OTP: send a fresh code and tell the app.
      let code: string | undefined;
      if (this.cooldownLeft(user) === 0) code = await this.issueOtp(user);
      const ch = this.challenge(user, code, 'Please verify your mobile number to continue');
      throw new HttpError(403, ch.message, { ...ch, code: 'PHONE_NOT_VERIFIED' });
    }

    return await this.session(user);
  }

  /* ------------------------------ admin login ------------------------------ */

  /** Admin panel login: email + password of a user whose role is 'admin' (no OTP step). */
  async adminLogin(body: unknown) {
    const b = asObject(body);
    const email = str(b.email).trim().toLowerCase();
    const password = str(b.password);
    if (!email) throw bad('Enter the admin email');
    if (!password) throw bad('Enter the password');

    this.assertNotLocked(email);
    const user = await this.store.findByEmail(email);
    const ok = user ? await verifyPassword(password, user.passwordHash) : false;
    if (!user || !ok || user.role !== 'admin') {
      this.recordFail(email);
      throw new HttpError(401, 'Invalid admin email or password');
    }
    this.loginFails.delete(email);
    return {
      accessToken: signToken(user.id, this.cfg.jwtSecret, this.cfg.tokenTtlSeconds),
      user: toPublicUser(user),
    };
  }

  /* ------------------------------ profile / auth ------------------------------ */

  async getProfile(userId: string) {
    // bookings that have finished since the last visit update matches / court time / savings
    await this.bookings.settleFinished(userId);
    const user = await this.store.findById(userId);
    if (!user) throw new HttpError(401, 'Account no longer exists');
    return toPublicUser(user);
  }

  /** "Authorization: Bearer xxx" -> user id, or throws 401 */
  userIdFromHeader(header: unknown): string {
    const [type, token] = typeof header === 'string' ? header.split(' ') : [];
    if (type !== 'Bearer' || !token) throw new HttpError(401, 'Missing token');
    const payload = verifyToken(token, this.cfg.jwtSecret);
    if (!payload) throw new HttpError(401, 'Invalid or expired token');
    return payload.sub;
  }

  /* ------------------------------ helpers ------------------------------ */

  private async session(user: StoredUser) {
    await this.bookings.settleFinished(user.id);
    user = (await this.store.findById(user.id)) ?? user;
    return {
      accessToken: signToken(user.id, this.cfg.jwtSecret, this.cfg.tokenTtlSeconds),
      user: toPublicUser(user),
    };
  }

  private cooldownLeft(user: StoredUser): number {
    if (!user.otpSentAt) return 0;
    return Math.max(0, Math.ceil((user.otpSentAt + OTP_RESEND_MS - Date.now()) / 1000));
  }

  private async issueOtp(user: StoredUser): Promise<string> {
    const code = generateOtp();
    const now = Date.now();
    await this.store.setOtp(user.id, hashOtp(code, user.phone, this.cfg.jwtSecret), now + OTP_TTL_MS, now);
    user.otpSentAt = now;
    await this.sms.send(user.phone, `Your SportsBook verification code is ${code}. It expires in 5 minutes.`);
    return code;
  }

  private challenge(user: StoredUser, code: string | undefined, message: string) {
    return {
      message,
      phone: user.phone.slice(3), // 9-digit national number the app sends back
      expiresInSeconds: OTP_TTL_MS / 1000,
      resendInSeconds: Math.max(this.cooldownLeft(user), 0),
      // Only in dev mode, so you can test without an SMS gateway.
      ...(this.cfg.otpDevMode && code ? { devOtp: code } : {}),
    };
  }

  private assertNotLocked(identifier: string) {
    const rec = this.loginFails.get(identifier.toLowerCase());
    if (!rec) return;
    if (Date.now() - rec.first > LOGIN_WINDOW_MS) {
      this.loginFails.delete(identifier.toLowerCase());
      return;
    }
    if (rec.count >= LOGIN_MAX_FAILS) {
      throw new HttpError(429, 'Too many failed attempts. Try again in a few minutes.');
    }
  }

  private recordFail(identifier: string) {
    const key = identifier.toLowerCase();
    const rec = this.loginFails.get(key);
    if (!rec || Date.now() - rec.first > LOGIN_WINDOW_MS) {
      this.loginFails.set(key, { count: 1, first: Date.now() });
    } else {
      rec.count += 1;
    }
  }
}
