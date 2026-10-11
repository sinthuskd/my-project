import 'reflect-metadata';
import { loadEnvFile } from '../common/env';
import { ensureAdmin } from '../admin/admin.bootstrap';
import { loadConfig } from '../common/env';
import { createPool } from './db.service';
import { migrate } from './migrate';
import { seed } from './seed';

/** node dist/db/cli.js migrate | seed | reset */
async function main() {
  loadEnvFile();
  const cmd = process.argv[2];
  const pool = createPool();
  try {
    if (cmd === 'reset') {
      console.log('Dropping and recreating schema "public" ...');
      await pool.query('DROP SCHEMA public CASCADE; CREATE SCHEMA public;');
    }
    if (cmd === 'migrate' || cmd === 'seed' || cmd === 'reset') {
      const done = await migrate(pool);
      console.log(done.length ? `Applied: ${done.join(', ')}` : 'Schema is up to date');
    }
    if (cmd === 'seed' || cmd === 'reset') {
      await seed(pool);
      console.log('Venues and courts from seed-data.ts loaded (nothing if the lists are empty)');
    }
    if (cmd === 'admin') {
      await migrate(pool);
      const msg = await ensureAdmin(pool, loadConfig());
      console.log(msg ?? 'Set ADMIN_EMAIL and ADMIN_PASSWORD in .env first');
    }
    if (!['migrate', 'seed', 'reset', 'admin'].includes(cmd)) {
      console.log('Usage: node dist/db/cli.js migrate | seed | reset | admin');
      process.exitCode = 1;
    }
  } finally {
    await pool.end();
  }
}
main().catch((e) => { console.error(e.message || e); process.exit(1); });
