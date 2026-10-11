-- SportsBook schema (PostgreSQL 13+)
CREATE EXTENSION IF NOT EXISTS pgcrypto;  -- gen_random_uuid()

/* ------------------------------ users ------------------------------ */
CREATE TABLE users (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name        text        NOT NULL,
  email            text        NOT NULL UNIQUE,          -- stored lowercase
  phone            text        NOT NULL UNIQUE,          -- +94XXXXXXXXX
  password_hash    text        NOT NULL,
  sports           text[]      NOT NULL DEFAULT '{}',
  phone_verified   boolean     NOT NULL DEFAULT false,
  otp_hash         text,
  otp_expires_at   timestamptz,
  otp_attempts     integer     NOT NULL DEFAULT 0,
  otp_sent_at      timestamptz,
  matches_played   integer     NOT NULL DEFAULT 0,
  court_time_hours numeric(8,2) NOT NULL DEFAULT 0,
  saved_lkr        numeric(12,2) NOT NULL DEFAULT 0,
  fairplay         numeric(3,1),
  wallet_balance   numeric(12,2) NOT NULL DEFAULT 0 CHECK (wallet_balance >= 0),
  created_at       timestamptz NOT NULL DEFAULT now()
);

/* ------------------------------ catalog ------------------------------ */
CREATE TABLE sports (
  name       text PRIMARY KEY,
  icon       text NOT NULL,            -- Flutter icon name, e.g. sports_tennis
  position   integer NOT NULL DEFAULT 0
);

CREATE TABLE venues (
  id             text PRIMARY KEY,     -- v1, v2 ...
  name           text NOT NULL,
  address        text NOT NULL,
  area           text NOT NULL,
  lat            double precision,
  lng            double precision,
  distance_km    numeric(5,1) NOT NULL DEFAULT 0,   -- fallback when the app sends no location
  rating         numeric(2,1) NOT NULL DEFAULT 0,
  reviews        integer NOT NULL DEFAULT 0,
  surface_label  text NOT NULL DEFAULT '',          -- dashboard card text, e.g. "Indoor Wood"
  image_asset    text NOT NULL,                     -- main image used on cards
  gate           text NOT NULL DEFAULT 'Main Gate',
  open_hour      smallint NOT NULL DEFAULT 6  CHECK (open_hour BETWEEN 0 AND 23),
  close_hour     smallint NOT NULL DEFAULT 22 CHECK (close_hour BETWEEN 1 AND 24),
  guidelines     text[] NOT NULL DEFAULT '{}',      -- **bold** markers supported by the app
  active         boolean NOT NULL DEFAULT true
);

CREATE TABLE venue_photos (
  venue_id text NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
  position smallint NOT NULL,
  asset    text NOT NULL,
  PRIMARY KEY (venue_id, position)
);

CREATE TABLE venue_amenities (
  venue_id text NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
  position smallint NOT NULL,
  icon     text NOT NULL,
  title    text NOT NULL,
  subtitle text NOT NULL,
  PRIMARY KEY (venue_id, position)
);

-- Facility names used by the search filter screen
CREATE TABLE venue_facilities (
  venue_id text NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
  facility text NOT NULL,
  PRIMARY KEY (venue_id, facility)
);

CREATE TABLE courts (
  id            text PRIMARY KEY,      -- v1-c1 ...
  venue_id      text NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
  sport         text NOT NULL REFERENCES sports(name),
  name          text NOT NULL,
  tag           text NOT NULL DEFAULT '',                 -- label on the venue page, e.g. BWF Approved
  listing_tag   text,                                      -- chip on search result card, e.g. WOODEN PARQUET
  description   text NOT NULL DEFAULT '',
  surface       text NOT NULL DEFAULT '',            -- matches search filter surface options
  environment   text NOT NULL DEFAULT 'indoor' CHECK (environment IN ('indoor','outdoor','rooftop')),
  price         integer NOT NULL CHECK (price >= 0), -- LKR per hour
  offpeak_price integer CHECK (offpeak_price >= 0),  -- LKR per hour from offpeak_from_hour
  offpeak_from_hour smallint NOT NULL DEFAULT 21,
  image_asset   text,
  top_pick      boolean NOT NULL DEFAULT false,
  instant_lock  boolean NOT NULL DEFAULT false,
  certified     text,                                -- e.g. BWF CERTIFIED MAT
  amenity_tags  jsonb NOT NULL DEFAULT '[]',         -- [{icon,label}] shown on the search result card
  position      integer NOT NULL DEFAULT 0,
  active        boolean NOT NULL DEFAULT true
);
CREATE INDEX courts_venue_idx ON courts(venue_id);
CREATE INDEX courts_sport_idx ON courts(sport);

/* ------------------------------ bookings ------------------------------ */
CREATE SEQUENCE booking_ref_seq START 8941;

CREATE TABLE bookings (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ref            text NOT NULL UNIQUE,                 -- #SB-COL-8941
  user_id        uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  court_id       text NOT NULL REFERENCES courts(id),
  venue_id       text NOT NULL REFERENCES venues(id),
  start_at       timestamptz NOT NULL,
  end_at         timestamptz NOT NULL,
  total_lkr      numeric(12,2) NOT NULL,
  saved_lkr      numeric(12,2) NOT NULL DEFAULT 0,
  status         text NOT NULL DEFAULT 'confirmed' CHECK (status IN ('confirmed','cancelled','completed')),
  payment_method text NOT NULL CHECK (payment_method IN ('wallet','pay_at_venue')),
  payment_status text NOT NULL CHECK (payment_status IN ('paid','pending','refunded')),
  pin            text NOT NULL,
  session_code   text NOT NULL,
  lockers        text NOT NULL DEFAULT '',
  max_players    smallint NOT NULL DEFAULT 4,
  cancelled_at   timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now(),
  CHECK (end_at > start_at)
);
CREATE INDEX bookings_user_idx  ON bookings(user_id, start_at DESC);
CREATE INDEX bookings_court_idx ON bookings(court_id, start_at) WHERE status <> 'cancelled';

CREATE TABLE booking_players (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id  uuid NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  user_id     uuid REFERENCES users(id) ON DELETE SET NULL,
  name        text NOT NULL,
  ready       boolean NOT NULL DEFAULT true,
  is_host     boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX booking_players_booking_idx ON booking_players(booking_id);

/* ------------------------------ wallet ------------------------------ */
CREATE TABLE wallet_transactions (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount        numeric(12,2) NOT NULL,                 -- + credit, - debit
  kind          text NOT NULL CHECK (kind IN ('topup','booking','refund')),
  booking_id    uuid REFERENCES bookings(id) ON DELETE SET NULL,
  note          text NOT NULL DEFAULT '',
  balance_after numeric(12,2) NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX wallet_tx_user_idx ON wallet_transactions(user_id, created_at DESC);
