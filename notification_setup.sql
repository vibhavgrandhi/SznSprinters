-- ============================================================
-- SZN SPRINTERS — BOOKING NOTIFICATION SETUP
-- Run this in: Supabase Dashboard → SQL Editor
-- ============================================================

-- STEP 1: Enable pg_net extension (allows HTTP calls from triggers)
CREATE EXTENSION IF NOT EXISTS pg_net;


-- ============================================================
-- OPTION A: PUSH NOTIFICATION via ntfy.sh (FREE, instant setup)
-- 1. Download the ntfy app on your phone (iOS or Android)
-- 2. Subscribe to topic: szn-bookings-5106103668
-- 3. Run this SQL — you'll get push notifications for every booking
-- ============================================================

CREATE OR REPLACE FUNCTION notify_booking_push()
RETURNS trigger AS $$
DECLARE
  msg text;
BEGIN
  msg :=
    'Name: '        || COALESCE(NEW.name, '?')               || chr(10) ||
    'Service: '     || COALESCE(NEW.service_type, '?')        || chr(10) ||
    'Date: '        || COALESCE(NEW.date::text, '?')          || chr(10) ||
    'Passengers: '  || COALESCE(NEW.passengers::text, '?')    || chr(10) ||
    'Phone: '       || COALESCE(NEW.phone, '?')               || chr(10) ||
    'Email: '       || COALESCE(NEW.email, '?')               || chr(10) ||
    'Pickup: '      || COALESCE(NEW.pickup_location, '—')     || chr(10) ||
    'Dest: '        || COALESCE(NEW.destination, '—')         || chr(10) ||
    'Notes: '       || COALESCE(NEW.notes, '—');

  PERFORM net.http_post(
    url     := 'https://ntfy.sh/szn-bookings-5106103668',
    headers := '{"Content-Type": "text/plain", "Title": "New SZN Booking!", "Priority": "high", "Tags": "van,calendar"}'::jsonb,
    body    := msg
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_booking_push ON bookings;
CREATE TRIGGER on_booking_push
  AFTER INSERT ON bookings
  FOR EACH ROW EXECUTE FUNCTION notify_booking_push();


-- ============================================================
-- OPTION B: SMS via AT&T text gateway + Resend (requires setup)
-- 1. Sign up FREE at resend.com
-- 2. Go to API Keys → Create API Key → copy it
-- 3. Verify your sending domain OR use their sandbox sender
-- 4. Replace REPLACE_WITH_RESEND_KEY below with your key
-- 5. Replace REPLACE_WITH_YOUR_EMAIL with your verified sender
-- 6. Run this SQL
-- AT&T gateway: texts delivered to 5106103668 as SMS
-- ============================================================

CREATE OR REPLACE FUNCTION notify_booking_sms()
RETURNS trigger AS $$
DECLARE
  msg text;
  body_json text;
BEGIN
  msg :=
    'NEW SZN BOOKING'                                            || chr(10) ||
    'Name: '        || COALESCE(NEW.name, '?')                  || chr(10) ||
    'Service: '     || COALESCE(NEW.service_type, '?')           || chr(10) ||
    'Billing: '     || COALESCE(NEW.billing_type, '?')           || chr(10) ||
    'Date: '        || COALESCE(NEW.date::text, '?')             || chr(10) ||
    'Passengers: '  || COALESCE(NEW.passengers::text, '?')       || chr(10) ||
    'Phone: '       || COALESCE(NEW.phone, '?')                  || chr(10) ||
    'Email: '       || COALESCE(NEW.email, '?')                  || chr(10) ||
    'Pickup: '      || COALESCE(NEW.pickup_location, '—')        || chr(10) ||
    'Dest: '        || COALESCE(NEW.destination, '—')            || chr(10) ||
    'Time: '        || COALESCE(NEW.pickup_time::text, '—')      || chr(10) ||
    'Notes: '       || COALESCE(NEW.notes, '—');

  body_json := json_build_object(
    'from', 'SZN Sprinters <REPLACE_WITH_YOUR_EMAIL>',
    'to',   ARRAY['5106103668@txt.att.net'],
    'subject', 'Booking: ' || COALESCE(NEW.name, 'Unknown'),
    'text', msg
  )::text;

  PERFORM net.http_post(
    url     := 'https://api.resend.com/emails',
    headers := ('{"Authorization": "Bearer REPLACE_WITH_RESEND_KEY", "Content-Type": "application/json"}')::jsonb,
    body    := body_json
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_booking_sms ON bookings;
CREATE TRIGGER on_booking_sms
  AFTER INSERT ON bookings
  FOR EACH ROW EXECUTE FUNCTION notify_booking_sms();


-- ============================================================
-- OPTION C: Email confirmation to CUSTOMER (same Resend setup)
-- Sends booking confirmation to the customer's email
-- Requires same Resend setup as Option B
-- Run AFTER Option B is working
-- ============================================================

CREATE OR REPLACE FUNCTION notify_customer_confirmation()
RETURNS trigger AS $$
DECLARE
  body_json text;
BEGIN
  IF NEW.email IS NULL OR NEW.email = '' THEN
    RETURN NEW;
  END IF;

  body_json := json_build_object(
    'from', 'SZN Sprinters <REPLACE_WITH_YOUR_EMAIL>',
    'to',   ARRAY[NEW.email],
    'subject', 'We got your booking request, ' || COALESCE(NEW.name, '') || '!',
    'text',
      'Hi ' || COALESCE(NEW.name, '') || ',' || chr(10) || chr(10) ||
      'We received your booking request. Here''s what we have:' || chr(10) || chr(10) ||
      'Service: '    || COALESCE(NEW.service_type, '?') || chr(10) ||
      'Date: '       || COALESCE(NEW.date::text, '?')   || chr(10) ||
      'Passengers: ' || COALESCE(NEW.passengers::text, '?') || chr(10) || chr(10) ||
      'We''ll reach out to you at ' || COALESCE(NEW.phone, 'the number you provided') || ' to confirm and arrange payment.' || chr(10) || chr(10) ||
      '— SZN Sprinters' || chr(10) ||
      'Instagram: @sznsprinter'
  )::text;

  PERFORM net.http_post(
    url     := 'https://api.resend.com/emails',
    headers := ('{"Authorization": "Bearer REPLACE_WITH_RESEND_KEY", "Content-Type": "application/json"}')::jsonb,
    body    := body_json
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_booking_customer_email ON bookings;
CREATE TRIGGER on_booking_customer_email
  AFTER INSERT ON bookings
  FOR EACH ROW EXECUTE FUNCTION notify_customer_confirmation();
