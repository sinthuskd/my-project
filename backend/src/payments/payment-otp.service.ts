import { Inject, Injectable } from '@nestjs/common';
import { generateOtp, hashOtp, safeEqualHex } from '../common/security';
import { loadConfig } from '../common/env';
import { HttpError } from '../common/http-error';
import { SMS_SENDER, SmsSender } from '../sms/sms.sender';
import { UsersRepo } from '../users/users.repo';

const TTL_MS = 5 * 60 * 1000;
const RESEND_MS = 30 * 1000;
const MAX_ATTEMPTS = 5;

interface Entry { hash: string; expiresAt: number; sentAt: number; attempts: number }

/**
 * One-time code that confirms a WALLET payment (sent to the user's verified mobile).
 * Kept in memory (5 minutes), so no database change is needed.
 * OTP_DEV_MODE=true -> the code is printed in the backend terminal and returned to the app.
 */
@Injectable()
export class PaymentOtpService {
  private readonly cfg = loadConfig();
  private readonly codes = new Map<string, Entry>();

  constructor(
    private readonly users: UsersRepo,
    @Inject(SMS_SENDER) private readonly sms: SmsSender,
  ) {}

  get required(): boolean {
    return this.cfg.paymentOtp;
  }

  async issue(userId: string) {
    const user = await this.users.findById(userId);
    if (!user) throw new HttpError(401, 'Account no longer exists');
    if (!user.phoneVerified) throw new HttpError(403, 'Verify your mobile number first');

    const old = this.codes.get(userId);
    const now = Date.now();
    if (old && old.sentAt + RESEND_MS > now) {
      const wait = Math.ceil((old.sentAt + RESEND_MS - now) / 1000);
      throw new HttpError(429, `Please wait ${wait}s before asking for a new code`, { code: 'OTP_COOLDOWN', retryAfter: wait });
    }

    const code = generateOtp();
    this.codes.set(userId, { hash: hashOtp(code, user.phone, this.cfg.jwtSecret), expiresAt: now + TTL_MS, sentAt: now, attempts: 0 });
    await this.sms.send(user.phone, `SportsBook payment code: ${code}. Valid for 5 minutes. Never share it.`);
    return {
      phone: user.phone,
      expiresInSeconds: TTL_MS / 1000,
      resendInSeconds: RESEND_MS / 1000,
      ...(this.cfg.otpDevMode ? { devOtp: code } : {}),
    };
  }

  /** Throws if the code is missing / wrong / expired. Does not consume it (see consume). */
  async check(userId: string, code: unknown) {
    if (typeof code !== 'string' || !/^\d{6}$/.test(code.trim())) {
      throw new HttpError(400, 'Enter the 6-digit payment code', { code: 'OTP_REQUIRED' });
    }
    const e = this.codes.get(userId);
    if (!e) throw new HttpError(400, 'Request a payment code first', { code: 'OTP_REQUIRED' });
    if (Date.now() > e.expiresAt) {
      this.codes.delete(userId);
      throw new HttpError(400, 'Code expired. Request a new one.', { code: 'OTP_EXPIRED' });
    }
    if (e.attempts >= MAX_ATTEMPTS) {
      this.codes.delete(userId);
      throw new HttpError(400, 'Too many wrong attempts. Request a new code.', { code: 'OTP_EXPIRED' });
    }
    const user = await this.users.findById(userId);
    if (!user) throw new HttpError(401, 'Account no longer exists');
    if (!safeEqualHex(hashOtp(code.trim(), user.phone, this.cfg.jwtSecret), e.hash)) {
      e.attempts += 1;
      throw new HttpError(400, `Wrong code. ${MAX_ATTEMPTS - e.attempts} attempts left.`, { code: 'INVALID_OTP' });
    }
  }

  consume(userId: string) {
    this.codes.delete(userId);
  }
}
