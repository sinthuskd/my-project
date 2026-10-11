export interface StoredUser {
  id: string;
  fullName: string;
  email: string; // lowercase
  phone: string; // +94XXXXXXXXX
  passwordHash: string;
  sports: string[];
  phoneVerified: boolean;
  role: 'user' | 'admin';

  otpHash: string | null;
  otpExpiresAt: number | null; // epoch ms
  otpAttempts: number;
  otpSentAt: number | null; // epoch ms

  // Profile stats. Start at 0 for every new account; the booking module will update these.
  matchesPlayed: number;
  courtTimeHours: number;
  savedLkr: number;
  fairplay: number | null;
  walletBalance: number;

  createdAt: string; // ISO
}

export interface PublicUser {
  id: string;
  memberId: string;
  fullName: string;
  email: string;
  phone: string;
  phoneVerified: boolean;
  role: 'user' | 'admin';
  sports: string[];
  tier: 'BRONZE' | 'SILVER' | 'GOLD';
  matchesPlayed: number;
  courtTimeHours: number;
  savedLkr: number;
  fairplay: number | null;
  walletBalance: number;
  createdAt: string;
}

/** What the app is allowed to see (never passwordHash / otp fields). */
export function toPublicUser(u: StoredUser): PublicUser {
  const tier = u.matchesPlayed >= 25 ? 'GOLD' : u.matchesPlayed >= 10 ? 'SILVER' : 'BRONZE';
  return {
    id: u.id,
    memberId: `SB-LK-${u.id.replace(/-/g, '').slice(0, 6).toUpperCase()}`,
    fullName: u.fullName,
    email: u.email,
    phone: u.phone,
    phoneVerified: u.phoneVerified,
    role: u.role,
    sports: u.sports,
    tier,
    matchesPlayed: u.matchesPlayed,
    courtTimeHours: u.courtTimeHours,
    savedLkr: u.savedLkr,
    fairplay: u.fairplay,
    walletBalance: u.walletBalance,
    createdAt: u.createdAt,
  };
}
