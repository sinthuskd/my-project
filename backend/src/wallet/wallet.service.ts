import { Injectable } from '@nestjs/common';
import { loadConfig } from '../common/env';
import { HttpError } from '../common/http-error';
import { Db } from '../db/db.service';

@Injectable()
export class WalletService {
  constructor(private readonly db: Db) {}

  async get(userId: string) {
    const u = await this.db.one(`SELECT wallet_balance FROM users WHERE id=$1`, [userId]);
    if (!u) throw new HttpError(401, 'Account no longer exists');
    const tx = await this.db.query(
      `SELECT id, amount, kind, note, balance_after, booking_id, created_at
       FROM wallet_transactions WHERE user_id=$1 ORDER BY created_at DESC, id LIMIT 50`, [userId]);
    return {
      balance: u.wallet_balance,
      transactions: tx.rows.map((t) => ({
        id: t.id, amount: t.amount, kind: t.kind, note: t.note, balanceAfter: t.balance_after,
        bookingId: t.booking_id, createdAt: new Date(t.created_at).toISOString(),
      })),
    };
  }

  /**
   * DEV ONLY: credits the wallet without taking payment (ALLOW_DEV_TOPUP=true).
   * In production replace this with your payment gateway callback (PayHere, Stripe ...).
   */
  async topUp(userId: string, body: unknown) {
    if (!loadConfig().allowDevTopup) {
      throw new HttpError(403, 'Wallet top-up needs a payment gateway (not configured)');
    }
    const amount = Number((body as any)?.amount);
    if (!Number.isFinite(amount) || amount < 100 || amount > 100_000) {
      throw new HttpError(400, 'Top-up amount must be between LKR 100 and LKR 100,000');
    }
    await this.db.tx(async (c) => {
      const u = (await c.query(
        `UPDATE users SET wallet_balance = wallet_balance + $2 WHERE id=$1 RETURNING wallet_balance`, [userId, amount])).rows[0];
      if (!u) throw new HttpError(401, 'Account no longer exists');
      await c.query(
        `INSERT INTO wallet_transactions(user_id,amount,kind,note,balance_after) VALUES ($1,$2,'topup','Wallet top-up',$3)`,
        [userId, amount, u.wallet_balance]);
    });
    return this.get(userId);
  }
}
