-- Admin panel: roles + admin-created bookable slots

/* ------------------------------ admin role ------------------------------ */
ALTER TABLE users ADD COLUMN role text NOT NULL DEFAULT 'user' CHECK (role IN ('user','admin'));

/* ------------------------------ slots ------------------------------
   A slot = one bookable time window of one court with a fixed price, created by an admin.
   Users only ever see (and book) these slots. */
CREATE TABLE court_slots (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  court_id   text        NOT NULL REFERENCES courts(id) ON DELETE CASCADE,
  start_at   timestamptz NOT NULL,
  end_at     timestamptz NOT NULL,
  price      integer     NOT NULL CHECK (price >= 0),   -- LKR for the whole slot
  active     boolean     NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (end_at > start_at)
);
CREATE INDEX court_slots_court_start_idx ON court_slots(court_id, start_at);

ALTER TABLE bookings ADD COLUMN slot_id uuid REFERENCES court_slots(id) ON DELETE RESTRICT;
-- one live booking per slot, enforced by the database itself
CREATE UNIQUE INDEX bookings_slot_live_uq ON bookings(slot_id) WHERE slot_id IS NOT NULL AND status <> 'cancelled';
CREATE INDEX bookings_created_idx ON bookings(created_at DESC);
