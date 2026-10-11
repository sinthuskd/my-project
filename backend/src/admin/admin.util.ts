import { HttpError } from '../common/http-error';
import { fromLocal, isValidDateStr } from '../common/time';

export const bad = (m: string) => new HttpError(400, m);

export function asObject(body: unknown): Record<string, unknown> {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) throw bad('Invalid request body');
  return body as Record<string, unknown>;
}

export const isUuid = (v: unknown): v is string => typeof v === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);

/** Query-string integer with default and bounds. */
export function intParam(v: unknown, dflt: number, min: number, max: number): number {
  if (v === undefined || v === '') return dflt;
  const n = Number(v);
  if (!Number.isInteger(n) || n < min || n > max) throw bad(`Value must be a whole number from ${min} to ${max}`);
  return n;
}

/* ---------------- field specs: one table drives validation for venues and courts ---------------- */

export type Kind = 'str' | 'nstr' | 'num' | 'nnum' | 'int' | 'bool' | 'strarr' | 'enum' | 'tags';
export interface Spec { key: string; col: string; kind: Kind; req?: boolean; min?: number; max?: number; len?: number; values?: string[] }

/**
 * Validates body fields listed in `specs`. Returns {column: value} for the fields that were sent.
 * partial=true (update): missing fields are skipped. partial=false (create): fields marked req must be present.
 */
export function pick(body: Record<string, unknown>, specs: Spec[], partial: boolean): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const sp of specs) {
    const v = body[sp.key];
    if (v === undefined) {
      if (sp.req && !partial) throw bad(`${sp.key} is required`);
      continue;
    }
    const need = (cond: boolean, msg: string) => { if (!cond) throw bad(`${sp.key}: ${msg}`); };
    switch (sp.kind) {
      case 'str': {
        need(typeof v === 'string', 'must be text');
        const t = (v as string).trim();
        need(!sp.req || t.length > 0, 'cannot be empty');
        need(t.length <= (sp.len ?? 200), `max ${sp.len ?? 200} characters`);
        out[sp.col] = t;
        break;
      }
      case 'nstr': {
        if (v === null || v === '') { out[sp.col] = null; break; }
        need(typeof v === 'string', 'must be text');
        need((v as string).trim().length <= (sp.len ?? 200), `max ${sp.len ?? 200} characters`);
        out[sp.col] = (v as string).trim();
        break;
      }
      case 'num':
      case 'nnum': {
        if (v === null && sp.kind === 'nnum') { out[sp.col] = null; break; }
        need(typeof v === 'number' && Number.isFinite(v), 'must be a number');
        need(sp.min === undefined || (v as number) >= sp.min, `min ${sp.min}`);
        need(sp.max === undefined || (v as number) <= sp.max, `max ${sp.max}`);
        out[sp.col] = v;
        break;
      }
      case 'int': {
        need(typeof v === 'number' && Number.isInteger(v), 'must be a whole number');
        need(sp.min === undefined || (v as number) >= sp.min, `min ${sp.min}`);
        need(sp.max === undefined || (v as number) <= sp.max, `max ${sp.max}`);
        out[sp.col] = v;
        break;
      }
      case 'bool':
        need(typeof v === 'boolean', 'must be true or false');
        out[sp.col] = v;
        break;
      case 'enum':
        need(typeof v === 'string' && !!sp.values?.includes(v), `must be one of ${sp.values?.join(', ')}`);
        out[sp.col] = v;
        break;
      case 'strarr':
        need(Array.isArray(v) && v.every((x) => typeof x === 'string' && x.trim().length > 0 && x.length <= 300), 'must be a list of text');
        need((v as string[]).length <= 50, 'too many items');
        out[sp.col] = (v as string[]).map((x) => x.trim());
        break;
      case 'tags':
        need(Array.isArray(v) && v.every((x) => x && typeof x.icon === 'string' && typeof x.label === 'string'), 'must be a list of {icon, label}');
        out[sp.col] = JSON.stringify((v as { icon: string; label: string }[]).map((x) => ({ icon: x.icon, label: x.label })));
        break;
    }
  }
  return out;
}

/** UPDATE helper: builds "col1=$2, col2=$3" for the picked values. */
export function setClause(values: Record<string, unknown>, startAt = 2): { sql: string; params: unknown[] } {
  const cols = Object.keys(values);
  return { sql: cols.map((c, i) => `${c} = $${i + startAt}`).join(', '), params: cols.map((c) => values[c]) };
}

/* ---------------- slot times (Colombo local) ---------------- */

const HM = /^(?:([01]\d|2[0-3]):([0-5]\d)|24:00)$/;

export function parseHM(v: unknown, label: string): { h: number; m: number } {
  if (typeof v !== 'string' || !HM.test(v)) throw bad(`${label} must be HH:mm (24-hour), e.g. 18:30`);
  return v === '24:00' ? { h: 24, m: 0 } : { h: Number(v.slice(0, 2)), m: Number(v.slice(3, 5)) };
}

export function slotRange(date: unknown, startTime: unknown, endTime: unknown): { start: Date; end: Date } {
  if (!isValidDateStr(date)) throw bad('date must be YYYY-MM-DD');
  const s = parseHM(startTime, 'startTime');
  const e = parseHM(endTime, 'endTime');
  const start = fromLocal(date, s.h, s.m);
  const end = fromLocal(date, e.h, e.m);
  if (end <= start) throw bad('endTime must be after startTime');
  if (end.getTime() - start.getTime() > 12 * 3_600_000) throw bad('A slot can be at most 12 hours long');
  return { start, end };
}

export const slotPrice = (v: unknown): number => {
  if (typeof v !== 'number' || !Number.isInteger(v) || v < 0 || v > 10_000_000) throw bad('price must be a whole number of LKR (0 or more)');
  return v;
};
