import { Injectable } from '@nestjs/common';
import { asObject, bad, intParam, isUuid, pick, setClause, Spec } from '../admin/admin.util';
import { HttpError } from '../common/http-error';
import { Db } from '../db/db.service';

const SPECS: Spec[] = [
  { key: 'name', col: 'name', kind: 'str', req: true, len: 80 },
  { key: 'sport', col: 'sport', kind: 'str', req: true, len: 60 },
  { key: 'description', col: 'description', kind: 'str', len: 500 },
  { key: 'area', col: 'area', kind: 'str', len: 80 },
];

const SELECT = `
  SELECT c.id, c.name, c.sport, c.description, c.area, c.owner_id AS "ownerId", u.full_name AS "ownerName",
         c.created_at AS "createdAt",
         (SELECT count(*) FROM club_members m WHERE m.club_id = c.id) AS members,
         (c.owner_id = $1) AS "isOwner",
         EXISTS (SELECT 1 FROM club_members m WHERE m.club_id = c.id AND m.user_id = $1) AS "isMember"
  FROM clubs c JOIN users u ON u.id = c.owner_id`;

@Injectable()
export class ClubsService {
  constructor(private readonly db: Db) {}

  /* ------------------------------ CREATE ------------------------------ */
  /** Body: {name, sport, description?, area?}. The creator becomes owner and first member. */
  async create(userId: string, body: unknown) {
    const v = pick(asObject(body), SPECS, false);
    if (!(await this.db.one('SELECT 1 FROM sports WHERE name=$1', [v.sport]))) throw bad(`Unknown sport "${v.sport}"`);
    const id = await this.db.tx(async (c) => {
      const keys = Object.keys(v);
      try {
        const r = await c.query(
          `INSERT INTO clubs (owner_id, ${keys.join(',')}) VALUES ($1, ${keys.map((_, i) => `$${i + 2}`).join(',')}) RETURNING id`,
          [userId, ...keys.map((k) => v[k])]);
        await c.query('INSERT INTO club_members (club_id, user_id) VALUES ($1,$2)', [r.rows[0].id, userId]);
        return r.rows[0].id as string;
      } catch (e: any) {
        if (e.code === '23505') throw new HttpError(409, 'A club with that name already exists');
        throw e;
      }
    });
    return this.get(userId, id);
  }

  /* ------------------------------ READ ------------------------------ */
  /** ?sport=&q=&mine=true (only clubs I am in) &limit=&offset= */
  async list(userId: string, q: Record<string, string>) {
    const where: string[] = [];
    const params: unknown[] = [userId];
    const add = (sql: string, v: unknown) => { params.push(v); where.push(sql.replace('?', `$${params.length}`)); };
    if (q.sport) add('c.sport = ?', q.sport);
    if (q.q?.trim()) add('c.name ILIKE ?', `%${q.q.trim()}%`);
    if (q.mine === 'true') where.push(`EXISTS (SELECT 1 FROM club_members m WHERE m.club_id = c.id AND m.user_id = $1)`);
    const limit = intParam(q.limit, 30, 1, 100);
    const offset = intParam(q.offset, 0, 0, 100000);
    const rows = (await this.db.query(
      `${SELECT} ${where.length ? 'WHERE ' + where.join(' AND ') : ''} ORDER BY members DESC, c.name LIMIT ${limit} OFFSET ${offset}`, params)).rows;
    return { items: rows };
  }

  async get(userId: string, id: string) {
    if (!isUuid(id)) throw new HttpError(404, 'Club not found');
    const club = await this.db.one(`${SELECT} WHERE c.id = $2`, [userId, id]);
    if (!club) throw new HttpError(404, 'Club not found');
    const members = (await this.db.query(
      `SELECT u.id, u.full_name AS name, u.fairplay FROM club_members m JOIN users u ON u.id = m.user_id
       WHERE m.club_id = $1 ORDER BY m.created_at`, [id])).rows;
    return { ...club, memberList: members };
  }

  /* ------------------------------ UPDATE (owner) ------------------------------ */
  async update(userId: string, id: string, body: unknown) {
    await this.owned(userId, id);
    const v = pick(asObject(body), SPECS, true);
    if (!Object.keys(v).length) throw bad('Nothing to update');
    if (v.sport && !(await this.db.one('SELECT 1 FROM sports WHERE name=$1', [v.sport]))) throw bad(`Unknown sport "${v.sport}"`);
    const { sql, params } = setClause(v);
    try {
      await this.db.query(`UPDATE clubs SET ${sql} WHERE id = $1`, [id, ...params]);
    } catch (e: any) {
      if (e.code === '23505') throw new HttpError(409, 'A club with that name already exists');
      throw e;
    }
    return this.get(userId, id);
  }

  /* ------------------------------ DELETE (owner) ------------------------------ */
  async remove(userId: string, id: string) {
    await this.owned(userId, id);
    await this.db.query('DELETE FROM clubs WHERE id = $1', [id]);
    return { ok: true };
  }

  /* ------------------------------ join / leave ------------------------------ */
  async join(userId: string, id: string) {
    if (!isUuid(id)) throw new HttpError(404, 'Club not found');
    if (!(await this.db.one('SELECT 1 FROM clubs WHERE id=$1', [id]))) throw new HttpError(404, 'Club not found');
    const r = await this.db.query('INSERT INTO club_members (club_id, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING', [id, userId]);
    if (!r.rowCount) throw new HttpError(409, 'You are already a member');
    return this.get(userId, id);
  }

  async leave(userId: string, id: string) {
    if (!isUuid(id)) throw new HttpError(404, 'Club not found');
    const club = await this.db.one('SELECT owner_id FROM clubs WHERE id=$1', [id]);
    if (!club) throw new HttpError(404, 'Club not found');
    if (club.owner_id === userId) throw bad('The owner cannot leave. Delete the club instead.');
    const r = await this.db.query('DELETE FROM club_members WHERE club_id=$1 AND user_id=$2', [id, userId]);
    if (!r.rowCount) throw new HttpError(404, 'You are not a member of this club');
    return this.get(userId, id);
  }

  private async owned(userId: string, id: string) {
    if (!isUuid(id)) throw new HttpError(404, 'Club not found');
    const c = await this.db.one('SELECT owner_id FROM clubs WHERE id=$1', [id]);
    if (!c) throw new HttpError(404, 'Club not found');
    if (c.owner_id !== userId) throw new HttpError(403, 'Only the club owner can do that');
    return c;
  }
}
