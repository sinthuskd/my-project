import { Controller, Get } from '@nestjs/common';
import { Db } from './db/db.service';

/** Open http://localhost:3000/health in a browser to check the server and database are up. */
@Controller('health')
export class HealthController {
  constructor(private readonly db: Db) {}

  @Get()
  async health() {
    let database = 'ok';
    try {
      await this.db.query('SELECT 1');
    } catch {
      database = 'down';
    }
    return { status: database === 'ok' ? 'ok' : 'degraded', database, time: new Date().toISOString() };
  }
}
