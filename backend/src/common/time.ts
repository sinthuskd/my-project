/** Sri Lanka has no daylight saving: always UTC+05:30. All "local" times in the API are Colombo time. */
export const TZ_OFFSET_MIN = 330;
const MIN = 60_000;

const shift = (d: Date) => new Date(d.getTime() + TZ_OFFSET_MIN * MIN);

/** Date -> "YYYY-MM-DD" in Colombo */
export function localDate(d: Date): string {
  return shift(d).toISOString().slice(0, 10);
}

/** Colombo local hour (0-23) and minute of a Date */
export function localHM(d: Date): { h: number; m: number } {
  const s = shift(d);
  return { h: s.getUTCHours(), m: s.getUTCMinutes() };
}

/** "2026-10-09", 18, 30 (Colombo) -> Date */
export function fromLocal(dateStr: string, h: number, m = 0): Date {
  const [y, mo, d] = dateStr.split('-').map(Number);
  return new Date(Date.UTC(y, mo - 1, d, h, m) - TZ_OFFSET_MIN * MIN);
}

export function isValidDateStr(s: unknown): s is string {
  if (typeof s !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(s)) return false;
  const d = new Date(`${s}T00:00:00Z`);
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === s;
}

export function addDays(dateStr: string, n: number): string {
  const d = new Date(`${dateStr}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

/** 18:00 -> "6:00 PM" (pad=true -> "06:00 PM") */
export function fmtTime(d: Date, pad = false): string {
  const { h, m } = localHM(d);
  const hh = h % 12 === 0 ? 12 : h % 12;
  return `${pad ? String(hh).padStart(2, '0') : hh}:${String(m).padStart(2, '0')} ${h < 12 ? 'AM' : 'PM'}`;
}

export const fmt24 = (d: Date) => {
  const { h, m } = localHM(d);
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
};

/** 60 -> "1 Hour", 90 -> "1.5 Hours", 120 -> "2 Hours" */
export function fmtDuration(min: number): string {
  const h = min / 60;
  return `${h} ${h === 1 ? 'Hour' : 'Hours'}`;
}

export const MINUTE = MIN;

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/** "12 Oct" (Colombo) */
export function fmtDayMonth(d: Date): string {
  const [, m, day] = localDate(d).split('-').map(Number);
  return `${day} ${MONTHS[m - 1]}`;
}

/** "6:00 PM" today, "Tomorrow 6:00 AM", otherwise "12 Oct 6:00 PM" */
export function dayLabel(start: Date, now = new Date()): string {
  const day = localDate(start);
  const today = localDate(now);
  if (day === today) return fmtTime(start);
  if (day === addDays(today, 1)) return `Tomorrow ${fmtTime(start)}`;
  return `${fmtDayMonth(start)} ${fmtTime(start)}`;
}
