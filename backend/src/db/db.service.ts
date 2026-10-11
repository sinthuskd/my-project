import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { Pool, PoolClient, QueryResultRow } from 'pg';
import { loadConfig } from '../common/env';

// Return NUMERIC columns as JS numbers (money / hours / ratings are small enough).
import { types } from 'pg';
types.setTypeParser(1700, (v) => parseFloat(v)); // numeric
types.setTypeParser(20, (v) => parseInt(v, 10)); // bigint (count(*))

export type Queryable = {
  query<R extends QueryResultRow = any>(text: string, params?: unknown[]): Promise<{ rows: R[]; rowCount: number | null }>;
};

export function createPool(): Pool {
  const cfg = loadConfig();
  return new Pool({
    connectionString: cfg.databaseUrl,
    ssl: cfg.pgSsl ? { rejectUnauthorized: false } : undefined,
    max: 10,
  });
}

@Injectable()
export class Db implements Queryable, OnModuleDestroy {
  readonly pool = createPool();

  query<R extends QueryResultRow = any>(text: string, params?: unknown[]) {
    return this.pool.query<R>(text, params as any[]);
  }

  async one<R extends QueryResultRow = any>(text: string, params?: unknown[]): Promise<R | undefined> {
    return (await this.query<R>(text, params)).rows[0];
  }

  /** Runs fn inside BEGIN/COMMIT. Any thrown error rolls back. */
  async tx<T>(fn: (c: PoolClient) => Promise<T>): Promise<T> {
    const c = await this.pool.connect();
    try {
      await c.query('BEGIN');
      const out = await fn(c);
      await c.query('COMMIT');
      return out;
    } catch (e) {
      try { await c.query('ROLLBACK'); } catch { /* ignore */ }
      throw e;
    } finally {
      c.release();
    }
  }

  onModuleDestroy() {
    return this.pool.end();
  }
}
