import { readdirSync, readFileSync } from 'fs';
import { resolve } from 'path';
import { Pool } from 'pg';

/** Applies db/migrations/*.sql in name order. Each file runs once (tracked in schema_migrations). */
export async function migrate(pool: Pool, dir = resolve(process.cwd(), 'db/migrations')): Promise<string[]> {
  const applied: string[] = [];
  const c = await pool.connect();
  try {
    // advisory lock: two instances starting together will not race
    await c.query('SELECT pg_advisory_lock(727001)');
    await c.query(`CREATE TABLE IF NOT EXISTS schema_migrations (
      name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())`);
    const done = new Set((await c.query('SELECT name FROM schema_migrations')).rows.map((r) => r.name));
    const files = readdirSync(dir).filter((f) => f.endsWith('.sql')).sort();
    for (const f of files) {
      if (done.has(f)) continue;
      await c.query('BEGIN');
      try {
        await c.query(readFileSync(resolve(dir, f), 'utf8'));
        await c.query('INSERT INTO schema_migrations(name) VALUES ($1)', [f]);
        await c.query('COMMIT');
        applied.push(f);
      } catch (e) {
        await c.query('ROLLBACK');
        throw new Error(`Migration ${f} failed: ${(e as Error).message}`);
      }
    }
  } finally {
    try { await c.query('SELECT pg_advisory_unlock(727001)'); } catch { /* connection already broken */ }
    c.release();
  }
  return applied;
}
