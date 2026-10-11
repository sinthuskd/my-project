-- Partners: match beacons ("Request a Partner"), friends, racket clubs

/* ------------------------------ match beacons ------------------------------
   A user broadcasts "I need a partner" for a sport. Other users respond (join). */
CREATE TABLE match_beacons (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  host_id       uuid        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sport         text        NOT NULL REFERENCES sports(name),
  format        text        NOT NULL DEFAULT 'any'      CHECK (format IN ('singles','doubles','any')),
  skill_level   text        NOT NULL DEFAULT 'intermediate' CHECK (skill_level IN ('beginner','intermediate','advanced','all')),
  style         text        NOT NULL DEFAULT 'casual'   CHECK (style IN ('casual','competitive')),
  fee_split     text        NOT NULL DEFAULT 'split'    CHECK (fee_split IN ('split','host_pays','bring_gear')),
  verified_only boolean     NOT NULL DEFAULT false,
  booking_id    uuid        REFERENCES bookings(id) ON DELETE SET NULL,
  start_at      timestamptz NOT NULL,
  spots         smallint    NOT NULL DEFAULT 1 CHECK (spots BETWEEN 1 AND 10),
  note          text        NOT NULL DEFAULT '',
  auto_expire   boolean     NOT NULL DEFAULT true,       -- closes 30 min before start_at
  notify        boolean     NOT NULL DEFAULT true,       -- alert host when someone accepts
  status        text        NOT NULL DEFAULT 'open'     CHECK (status IN ('open','full','cancelled')),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX match_beacons_open_idx ON match_beacons(status, start_at);
CREATE INDEX match_beacons_host_idx ON match_beacons(host_id, created_at DESC);

CREATE TABLE beacon_responses (
  beacon_id  uuid NOT NULL REFERENCES match_beacons(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (beacon_id, user_id)
);

/* ------------------------------ friends ------------------------------
   One row per direction, so "my friends" is a simple WHERE user_id = me. */
CREATE TABLE friends (
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  friend_id  uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, friend_id),
  CHECK (user_id <> friend_id)
);

/* ------------------------------ clubs ------------------------------ */
CREATE TABLE clubs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name        text NOT NULL UNIQUE,
  sport       text NOT NULL REFERENCES sports(name),
  description text NOT NULL DEFAULT '',
  area        text NOT NULL DEFAULT '',
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE club_members (
  club_id    uuid NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (club_id, user_id)
);
CREATE INDEX club_members_user_idx ON club_members(user_id);
