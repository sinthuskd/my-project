/**
 * Sri Lankan numbers. Returns the 9-digit national number, or null if invalid.
 * Accepts: 771234567, 077 123 4567, 0771234567, +94 77 123 4567, 94771234567
 */
export function normalizeLkPhone(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  let d = raw.replace(/\D/g, '');
  if (d.length === 11 && d.startsWith('94')) d = d.slice(2);
  else if (d.length === 10 && d.startsWith('0')) d = d.slice(1);
  return /^\d{9}$/.test(d) ? d : null;
}

/** 771234567 -> +94771234567 */
export const toE164 = (national: string) => `+94${national}`;
