-- ============================================================
-- SZN Sprinters — Supabase Schema
-- Run this in Supabase Dashboard → SQL Editor
-- ============================================================

-- Bookings
CREATE TABLE IF NOT EXISTS bookings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT NOT NULL,
  service_type TEXT NOT NULL,
  billing_type TEXT,
  date DATE NOT NULL,
  pickup_time TEXT,
  pickup_location TEXT,
  destination TEXT,
  passengers INTEGER,
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','confirmed','declined')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Site settings (key-value — admin editable)
CREATE TABLE IF NOT EXISTS site_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL DEFAULT ''
);

-- ── RLS ──────────────────────────────────────────────────────
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE site_settings ENABLE ROW LEVEL SECURITY;

-- Bookings: public can INSERT (booking form) and READ/UPDATE/DELETE (admin UI uses anon key)
CREATE POLICY "Public insert bookings"  ON bookings FOR INSERT  WITH CHECK (true);
CREATE POLICY "Public read bookings"    ON bookings FOR SELECT  USING (true);
CREATE POLICY "Public update bookings"  ON bookings FOR UPDATE  USING (true) WITH CHECK (true);
CREATE POLICY "Public delete bookings"  ON bookings FOR DELETE  USING (true);

-- Settings: full public access (admin edits via anon key; values are non-sensitive)
CREATE POLICY "Public read settings"    ON site_settings FOR SELECT  USING (true);
CREATE POLICY "Public insert settings"  ON site_settings FOR INSERT  WITH CHECK (true);
CREATE POLICY "Public update settings"  ON site_settings FOR UPDATE  USING (true) WITH CHECK (true);

-- Blocked dates (admin can block full days or time ranges)
CREATE TABLE IF NOT EXISTS blocked_dates (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  date DATE NOT NULL,
  full_day BOOLEAN NOT NULL DEFAULT true,
  start_time TEXT,
  end_time TEXT,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE blocked_dates ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read blocked"   ON blocked_dates FOR SELECT  USING (true);
CREATE POLICY "Public insert blocked" ON blocked_dates FOR INSERT  WITH CHECK (true);
CREATE POLICY "Public delete blocked" ON blocked_dates FOR DELETE  USING (true);

-- ── SEED SETTINGS ─────────────────────────────────────────────
INSERT INTO site_settings (key, value) VALUES
  ('phone',           ''),
  ('email',           ''),
  ('instagram',       'https://www.instagram.com/sznsprinter/'),
  ('venmo',           ''),
  ('hourly_rate',     '100'),
  ('hourly_minimum',  '2'),
  ('pickup_fee',      '40'),
  ('per_mile_rate',   '4'),
  ('tagline',         'A different world of group travel.')
ON CONFLICT (key) DO NOTHING;
