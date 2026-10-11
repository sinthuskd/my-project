import { Injectable } from '@nestjs/common';
import { asObject, bad, isUuid } from '../admin/admin.util';
import { HttpError } from '../common/http-error';
import { normalizeLkPhone, toE164 } from '../common/phone';
import { Db } from '../db/db.service';

@Injectable()
export class FriendsService {
  constructor(private readonly db: Db) {}

  /** My friends. Optional ?q= filters by name. */
  async list(userId: string, q?: string) {
    const params: unknown[] = [userId];
    let where = '';
    if (q?.trim()) { params.push(`%${q.trim()}%`); where = `AND u.full_name ILIKE $2`; }
    const rows = (await this.db.query(
      `SELECT u.id, u.full_name AS name, u.sports, u.fairplay, u.matches_played AS "matchesPlayed", f.created_at AS "addedAt"
       FROM friends f JOIN users u ON u.id = f.friend_id
       WHERE f.user_id = $1 ${where} ORDER BY u.full_name`, params)).rows;
    return { items: rows };
  }

  /** Add by {userId} or {phone} or {email}. Friendship is mutual (both rows are created). */
  async add(userId: string, body: unknown) {
    const b = asObject(body);
    let friend: { id: string; full_name: string } | undefined;
    if (b.userId !== undefined) {
      if (!isUuid(b.userId)) throw bad('userId is invalid');
      friend = await this.db.one('SELECT id, full_name FROM users WHERE id = $1', [b.userId]);
    } else if (b.phone !== undefined) {
      const n = normalizeLkPhone(b.phone);
      if (!n) throw bad('Enter a valid Sri Lankan mobile number');
      friend = await this.db.one('SELECT id, full_name FROM users WHERE phone = $1', [toE164(n)]);
    } else if (typeof b.email === 'string') {
      friend = await this.db.one('SELECT id, full_name FROM users WHERE email = $1', [b.email.trim().toLowerCase()]);
    } else {
      throw bad('Send userId, phone or email');
    }
    if (!friend) throw new HttpError(404, 'No player found with those details');
    if (friend.id === userId) throw bad('You cannot add yourself');

    const ins = await this.db.tx(async (c) => {
      const a = await c.query('INSERT INTO friends (user_id, friend_id) VALUES ($1,$2) ON CONFLICT DO NOTHING', [userId, friend!.id]);
      await c.query('INSERT INTO friends (user_id, friend_id) VALUES ($1,$2) ON CONFLICT DO NOTHING', [friend!.id, userId]);
      return a.rowCount;
    });
    if (!ins) throw new HttpError(409, `${friend.full_name} is already your friend`);
    return { id: friend.id, name: friend.full_name };
  }

  /** Remove friend (both directions). */
  async remove(userId: string, friendId: string) {
    if (!isUuid(friendId)) throw new HttpError(404, 'Friend not found');
    const r = await this.db.query(
      'DELETE FROM friends WHERE (user_id=$1 AND friend_id=$2) OR (user_id=$2 AND friend_id=$1)', [userId, friendId]);
    if (!r.rowCount) throw new HttpError(404, 'Friend not found');
    return { ok: true };
  }
}
