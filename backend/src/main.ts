import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { networkInterfaces } from 'os';
import { AppModule } from './app.module';
import { loadConfig, loadEnvFile } from './common/env';
import { AllExceptionsFilter } from './common/http-exception.filter';
import { ensureAdmin } from './admin/admin.bootstrap';
import { Db } from './db/db.service';
import { migrate } from './db/migrate';
import { seed } from './db/seed';
import { VENUES_SEED } from './db/seed-data';

async function bootstrap() {
  loadEnvFile();
  const cfg = loadConfig();

  const app = await NestFactory.create(AppModule);
  const db = app.get(Db);
  try {
    if (cfg.autoMigrate) {
      const done = await migrate(db.pool);
      if (done.length) console.log(`[db] applied migrations: ${done.join(', ')}`);
    }
    const adminMsg = await ensureAdmin(db.pool, cfg);
    if (adminMsg) console.log(`[admin] ${adminMsg}`);
    const venues = (await db.query('SELECT count(*) AS n FROM venues').catch(() => ({ rows: [{ n: -1 }] }))).rows[0].n;
    if (cfg.autoSeed && venues === 0 && VENUES_SEED.length > 0) {
      await seed(db.pool);
      console.log('[db] venues and courts from seed-data.ts loaded');
    }
  } catch (e) {
    console.error(`\n[db] Cannot use PostgreSQL at ${cfg.databaseUrl.replace(/:[^:@/]*@/, ':***@')}\n     ${(e as Error).message}\n     Start it with:  docker compose up -d db   (or set DATABASE_URL in .env)\n`);
    process.exit(1);
  }

  app.enableCors(); // Flutter Web (Chrome) needs this
  app.useGlobalFilters(new AllExceptionsFilter());

  // One line per request (bodies are never logged: they contain passwords)
  app.use((req: any, res: any, next: () => void) => {
    const t = Date.now();
    res.on('finish', () => console.log(`${req.method} ${req.originalUrl} -> ${res.statusCode} (${Date.now() - t}ms)`));
    next();
  });

  await app.listen(cfg.port, '0.0.0.0');

  console.log(`\nSportsBook backend running`);
  console.log(`  Local:    http://localhost:${cfg.port}/health`);
  for (const list of Object.values(networkInterfaces())) {
    for (const i of list ?? []) {
      if (i.family === 'IPv4' && !i.internal) {
        console.log(`  Network:  http://${i.address}:${cfg.port}   <- use this for a real phone`);
      }
    }
  }
  console.log(`  OTP dev mode: ${cfg.otpDevMode ? 'ON (codes printed here + shown in app)' : 'OFF'}\n`);
}

bootstrap().catch((e) => {
  console.error('Failed to start:', e);
  process.exit(1);
});
