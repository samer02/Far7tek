-- ==============================================================================
-- Far7tek — FULL DATABASE RESET
-- ⚠️  This script DROPS everything in the public schema and rebuilds from scratch.
-- ⚠️  All existing data (users stay in auth, but app data is lost) will be deleted.
--
-- Run in Supabase Studio → SQL Editor → New Query → Run
-- ==============================================================================

-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║  STEP 0 — DROP EVERYTHING (clean slate)                                     ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝

-- Remove realtime publications for our tables
DO $$
DECLARE t text;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    FOREACH t IN ARRAY ARRAY[
      'live_locations','journey_stages','journey_events','booking_requests',
      'notifications','trip_status_history','trip_assignments','cars',
      'car_images','car_videos','car_proposals','proposal_images',
      'car_availability_rules','gps_location_updates','audit_log',
      'vehicle_change_requests','admin_notes','gallery','profiles','user_roles'
    ] LOOP
      BEGIN
        EXECUTE format('ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS public.%I', t);
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
    END LOOP;
  END IF;
END $$;

-- Drop triggers first
DROP TRIGGER IF EXISTS far7tek_partner_link ON auth.users;
DROP TRIGGER IF EXISTS cars_audit ON public.cars;
DROP TRIGGER IF EXISTS cars_delete_guard ON public.cars;

-- Drop all functions (CASCADE drops dependent triggers too)
DROP FUNCTION IF EXISTS public.has_role(uuid, public.app_role) CASCADE;
DROP FUNCTION IF EXISTS public.is_assigned_partner(uuid, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.assert_admin() CASCADE;
DROP FUNCTION IF EXISTS public.link_partner_account(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.on_auth_user_confirmed() CASCADE;
DROP FUNCTION IF EXISTS public.claim_partner_account() CASCADE;
DROP FUNCTION IF EXISTS public.admin_approve_partner(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.admin_review_partner(uuid, text, text) CASCADE;
DROP FUNCTION IF EXISTS public.admin_set_car_validation(uuid, text) CASCADE;
DROP FUNCTION IF EXISTS public.admin_assign_trip(uuid, uuid, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.admin_set_booking_status(uuid, text, text) CASCADE;
DROP FUNCTION IF EXISTS public.admin_review_change_request(uuid, boolean) CASCADE;
DROP FUNCTION IF EXISTS public.admin_list_clients() CASCADE;
DROP FUNCTION IF EXISTS public.partner_respond_assignment(uuid, boolean, text) CASCADE;
DROP FUNCTION IF EXISTS public.partner_update_trip_status(uuid, text) CASCADE;
DROP FUNCTION IF EXISTS public.partner_update_car_availability(uuid, text) CASCADE;
DROP FUNCTION IF EXISTS public.partner_add_car_photo(uuid, text) CASCADE;
DROP FUNCTION IF EXISTS public.geo_valid(double precision, double precision) CASCADE;
DROP FUNCTION IF EXISTS public.geo_distance_m(double precision, double precision, double precision, double precision) CASCADE;
DROP FUNCTION IF EXISTS public.audit(text, text, uuid, jsonb) CASCADE;
DROP FUNCTION IF EXISTS public.can_view_booking(uuid, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.can_view_live_location(uuid, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.notify_user(uuid, text, text, text) CASCADE;
DROP FUNCTION IF EXISTS public.notify_admins(text, text) CASCADE;
DROP FUNCTION IF EXISTS public.car_window_status(uuid, timestamptz, timestamptz, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.car_calendar_bookings(uuid, date, date) CASCADE;
DROP FUNCTION IF EXISTS public.transport_submit_request(jsonb) CASCADE;
DROP FUNCTION IF EXISTS public.transport_client_cancel(uuid, text) CASCADE;
DROP FUNCTION IF EXISTS public.admin_list_owners() CASCADE;
DROP FUNCTION IF EXISTS public.transport_assert_slot(public.booking_requests, boolean) CASCADE;
DROP FUNCTION IF EXISTS public.admin_transport_set_status(uuid, text, text, boolean) CASCADE;
DROP FUNCTION IF EXISTS public.admin_transport_assign(uuid, uuid, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.admin_transport_set_window(uuid, timestamptz, timestamptz) CASCADE;
DROP FUNCTION IF EXISTS public.admin_transport_log_contact(uuid, text) CASCADE;
DROP FUNCTION IF EXISTS public.owner_transport_operations() CASCADE;
DROP FUNCTION IF EXISTS public.owner_respond_booking(uuid, boolean, text) CASCADE;
DROP FUNCTION IF EXISTS public.owner_set_availability_mode(uuid, text) CASCADE;
DROP FUNCTION IF EXISTS public.journey_start_stage(uuid, double precision, double precision, double precision) CASCADE;
DROP FUNCTION IF EXISTS public.journey_end_stage(uuid, double precision, double precision, double precision) CASCADE;
DROP FUNCTION IF EXISTS public.journey_mark_stop(uuid, int, double precision, double precision) CASCADE;
DROP FUNCTION IF EXISTS public.journey_client_signal(uuid, text) CASCADE;
DROP FUNCTION IF EXISTS public.journey_push_location(uuid, double precision, double precision, double precision, double precision, double precision, timestamptz) CASCADE;
DROP FUNCTION IF EXISTS public.cars_audit_trigger() CASCADE;
DROP FUNCTION IF EXISTS public.cars_delete_guard() CASCADE;

-- Drop all tables in dependency order
DROP TABLE IF EXISTS public.gps_location_updates CASCADE;
DROP TABLE IF EXISTS public.live_locations CASCADE;
DROP TABLE IF EXISTS public.journey_events CASCADE;
DROP TABLE IF EXISTS public.journey_stages CASCADE;
DROP TABLE IF EXISTS public.car_availability_rules CASCADE;
DROP TABLE IF EXISTS public.audit_log CASCADE;
DROP TABLE IF EXISTS public.admin_notes CASCADE;
DROP TABLE IF EXISTS public.vehicle_change_requests CASCADE;
DROP TABLE IF EXISTS public.trip_status_history CASCADE;
DROP TABLE IF EXISTS public.trip_assignments CASCADE;
DROP TABLE IF EXISTS public.booking_requests CASCADE;
DROP TABLE IF EXISTS public.proposal_images CASCADE;
DROP TABLE IF EXISTS public.car_proposals CASCADE;
DROP TABLE IF EXISTS public.car_videos CASCADE;
DROP TABLE IF EXISTS public.car_images CASCADE;
DROP TABLE IF EXISTS public.gallery CASCADE;
DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.cars CASCADE;
DROP TABLE IF EXISTS public.user_roles CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- Drop enums
DROP TYPE IF EXISTS public.app_role CASCADE;
DROP TYPE IF EXISTS public.booking_status CASCADE;
DROP TYPE IF EXISTS public.proposal_status CASCADE;

-- Drop storage policies (safe even if bucket doesn't exist)
DROP POLICY IF EXISTS "car_images_public_read" ON storage.objects;
DROP POLICY IF EXISTS "car_images_partner_upload" ON storage.objects;
DROP POLICY IF EXISTS "car_images_admin_delete" ON storage.objects;
DROP POLICY IF EXISTS "proposal_images_upload" ON storage.objects;
DROP POLICY IF EXISTS "proposal_images_read" ON storage.objects;

-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║  STEP 1 — BASE SCHEMA (setup_external_db.sql)                               ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Enums
DO $$ BEGIN
  CREATE TYPE public.app_role AS ENUM ('admin', 'editor', 'partner');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE public.booking_status AS ENUM (
    'new', 'contacted', 'pending', 'confirmed', 'cancelled', 'accepted', 'rejected', 'in_progress', 'completed'
  );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE public.proposal_status AS ENUM (
    'new', 'reviewing', 'accepted', 'rejected', 'pending', 'info_requested', 'approved'
  );
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- Tables

CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name TEXT DEFAULT '' NOT NULL,
  last_name TEXT DEFAULT '' NOT NULL,
  phone TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.app_role NOT NULL,
  CONSTRAINT user_roles_user_id_role_key UNIQUE (user_id, role)
);

CREATE TABLE IF NOT EXISTS public.cars (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  brand TEXT NOT NULL,
  model TEXT NOT NULL,
  slug TEXT NOT NULL,
  year INTEGER,
  color TEXT,
  category TEXT NOT NULL,
  short_description TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  features JSONB DEFAULT '{}'::jsonb NOT NULL,
  service_information JSONB DEFAULT '{}'::jsonb NOT NULL,
  price_from NUMERIC,
  availability TEXT NOT NULL DEFAULT 'Sur demande',
  active BOOLEAN NOT NULL DEFAULT true,
  featured BOOLEAN NOT NULL DEFAULT false,
  sort_order INTEGER NOT NULL DEFAULT 0,
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  validation_status TEXT NOT NULL DEFAULT 'active',
  seats INTEGER,
  city TEXT,
  services TEXT[] DEFAULT '{}'::text[] NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.car_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  car_id UUID NOT NULL REFERENCES public.cars(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL,
  alt_text TEXT NOT NULL DEFAULT '',
  is_cover BOOLEAN NOT NULL DEFAULT false,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.car_videos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  car_id UUID NOT NULL REFERENCES public.cars(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL,
  title TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.car_proposals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  phone TEXT NOT NULL,
  email TEXT NOT NULL,
  city TEXT NOT NULL,
  brand TEXT NOT NULL,
  model TEXT NOT NULL,
  year INTEGER NOT NULL,
  color TEXT NOT NULL,
  vehicle_type TEXT NOT NULL,
  description TEXT NOT NULL,
  availability TEXT NOT NULL,
  travel_zone TEXT NOT NULL,
  schedules TEXT NOT NULL,
  desired_rate NUMERIC NOT NULL DEFAULT 0,
  message TEXT NOT NULL DEFAULT '',
  status public.proposal_status NOT NULL DEFAULT 'pending',
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  address TEXT NOT NULL DEFAULT '',
  extra_info TEXT NOT NULL DEFAULT '',
  seats INTEGER NOT NULL DEFAULT 4,
  vehicle_condition TEXT NOT NULL DEFAULT '',
  services TEXT[] NOT NULL DEFAULT '{}'::text[],
  rejection_reason TEXT,
  info_request TEXT,
  partner_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  car_id UUID REFERENCES public.cars(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.proposal_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proposal_id UUID NOT NULL REFERENCES public.car_proposals(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL,
  kind TEXT NOT NULL DEFAULT 'exterior',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.booking_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  phone TEXT NOT NULL,
  email TEXT NOT NULL,
  wedding_date DATE NOT NULL,
  wedding_time TIME NOT NULL,
  city TEXT NOT NULL,
  venue TEXT NOT NULL,
  car_id UUID REFERENCES public.cars(id) ON DELETE SET NULL,
  car_name TEXT NOT NULL,
  service_type TEXT NOT NULL,
  message TEXT NOT NULL DEFAULT '',
  status public.booking_status NOT NULL DEFAULT 'pending',
  client_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  pickup_address TEXT NOT NULL DEFAULT '',
  destination_type TEXT NOT NULL DEFAULT '',
  return_time TIME,
  passengers INTEGER NOT NULL DEFAULT 1,
  vehicle_type TEXT NOT NULL DEFAULT '',
  trip_type TEXT NOT NULL DEFAULT 'one_way',
  reference TEXT NOT NULL DEFAULT upper(substr(md5(random()::text), 1, 8)),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.trip_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_request_id UUID NOT NULL REFERENCES public.booking_requests(id) ON DELETE CASCADE,
  partner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  car_id UUID REFERENCES public.cars(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'proposed',
  rejection_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.trip_status_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_request_id UUID NOT NULL REFERENCES public.booking_requests(id) ON DELETE CASCADE,
  status TEXT NOT NULL,
  changed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  note TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.vehicle_change_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  car_id UUID NOT NULL REFERENCES public.cars(id) ON DELETE CASCADE,
  partner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  changes JSONB NOT NULL DEFAULT '{}'::jsonb,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.admin_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  booking_request_id UUID REFERENCES public.booking_requests(id) ON DELETE CASCADE,
  car_proposal_id UUID REFERENCES public.car_proposals(id) ON DELETE CASCADE,
  note TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  audience TEXT NOT NULL DEFAULT 'user',
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  link TEXT,
  read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.gallery (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  event_date DATE,
  service_type TEXT,
  media_type TEXT NOT NULL,
  storage_path TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║  STEP 2 — TRANSPORT MANAGEMENT (0001_transport_management.sql)              ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝

CREATE EXTENSION IF NOT EXISTS btree_gist;

-- New booking statuses
ALTER TYPE public.booking_status ADD VALUE IF NOT EXISTS 'under_review';
ALTER TYPE public.booking_status ADD VALUE IF NOT EXISTS 'approved';
ALTER TYPE public.booking_status ADD VALUE IF NOT EXISTS 'awaiting_owner';

-- Catalog extensions
ALTER TABLE public.cars
  ADD COLUMN IF NOT EXISTS transmission text,
  ADD COLUMN IF NOT EXISTS fuel_type text,
  ADD COLUMN IF NOT EXISTS equipment text[] NOT NULL DEFAULT '{}'::text[],
  ADD COLUMN IF NOT EXISTS is_new_arrival boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS availability_mode text NOT NULL DEFAULT 'always';

DO $$ BEGIN
  ALTER TABLE public.cars ADD CONSTRAINT cars_availability_mode_check CHECK (availability_mode IN ('always', 'schedule'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Request extensions
ALTER TABLE public.booking_requests
  ADD COLUMN IF NOT EXISTS owner_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS assigned_admin_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS category text,
  ADD COLUMN IF NOT EXISTS pickup_lat double precision,
  ADD COLUMN IF NOT EXISTS pickup_lng double precision,
  ADD COLUMN IF NOT EXISTS destination_lat double precision,
  ADD COLUMN IF NOT EXISTS destination_lng double precision,
  ADD COLUMN IF NOT EXISTS stops jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS client_notes text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS contact_extra text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS service_start_at timestamptz,
  ADD COLUMN IF NOT EXISTS service_end_at timestamptz,
  ADD COLUMN IF NOT EXISTS decision_note text,
  ADD COLUMN IF NOT EXISTS decided_at timestamptz;

DO $$ BEGIN
  ALTER TABLE public.booking_requests ADD CONSTRAINT booking_requests_category_check CHECK (category IS NULL OR category IN ('wedding', 'family'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE public.booking_requests ADD CONSTRAINT booking_requests_window_check
    CHECK (service_start_at IS NULL OR service_end_at IS NULL OR service_end_at > service_start_at);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE public.booking_requests ADD CONSTRAINT booking_requests_no_overlap
    EXCLUDE USING gist (car_id WITH =, tstzrange(service_start_at, service_end_at, '[)') WITH &&)
    WHERE (car_id IS NOT NULL AND service_start_at IS NOT NULL AND service_end_at IS NOT NULL
           AND status IN ('confirmed', 'in_progress'));
EXCEPTION WHEN duplicate_object OR duplicate_table THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS booking_requests_owner_idx ON public.booking_requests (owner_id);
CREATE INDEX IF NOT EXISTS booking_requests_client_idx ON public.booking_requests (client_id);
CREATE INDEX IF NOT EXISTS booking_requests_car_window_idx ON public.booking_requests (car_id, service_start_at);

-- Owner availability
CREATE TABLE IF NOT EXISTS public.car_availability_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  car_id uuid NOT NULL REFERENCES public.cars(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('weekly', 'dates')),
  available boolean NOT NULL,
  weekday smallint CHECK (weekday BETWEEN 0 AND 6),
  date_from date,
  date_to date,
  start_time time,
  end_time time,
  note text NOT NULL DEFAULT '' CHECK (length(note) <= 200),
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT car_availability_shape CHECK (
    (kind = 'weekly' AND weekday IS NOT NULL AND date_from IS NULL AND date_to IS NULL)
    OR (kind = 'dates' AND weekday IS NULL AND date_from IS NOT NULL AND date_to IS NOT NULL
        AND date_to >= date_from AND date_to - date_from <= 366)),
  CONSTRAINT car_availability_hours CHECK (
    (start_time IS NULL AND end_time IS NULL) OR (start_time IS NOT NULL AND end_time IS NOT NULL AND end_time > start_time))
);
CREATE INDEX IF NOT EXISTS car_availability_rules_car_idx ON public.car_availability_rules (car_id);

-- Journeys and GPS
CREATE TABLE IF NOT EXISTS public.journey_stages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_request_id uuid NOT NULL REFERENCES public.booking_requests(id) ON DELETE CASCADE,
  stage_no smallint NOT NULL CHECK (stage_no BETWEEN 1 AND 10),
  label text NOT NULL DEFAULT '',
  from_address text NOT NULL,
  from_lat double precision,
  from_lng double precision,
  to_address text NOT NULL,
  to_lat double precision,
  to_lng double precision,
  stops jsonb NOT NULL DEFAULT '[]'::jsonb,
  scheduled_at timestamptz,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'skipped', 'cancelled')),
  started_at timestamptz,
  started_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  start_lat double precision,
  start_lng double precision,
  start_accuracy double precision,
  ended_at timestamptz,
  ended_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  end_lat double precision,
  end_lng double precision,
  end_accuracy double precision,
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT journey_stages_booking_stage_key UNIQUE (booking_request_id, stage_no)
);
CREATE UNIQUE INDEX IF NOT EXISTS journey_stages_one_active ON public.journey_stages (booking_request_id) WHERE status = 'in_progress';

CREATE TABLE IF NOT EXISTS public.journey_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_request_id uuid NOT NULL REFERENCES public.booking_requests(id) ON DELETE CASCADE,
  stage_id uuid REFERENCES public.journey_stages(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_role text NOT NULL DEFAULT '',
  lat double precision,
  lng double precision,
  accuracy double precision,
  note text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS journey_events_booking_idx ON public.journey_events (booking_request_id, created_at);

CREATE TABLE IF NOT EXISTS public.gps_location_updates (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  booking_request_id uuid NOT NULL REFERENCES public.booking_requests(id) ON DELETE CASCADE,
  stage_id uuid REFERENCES public.journey_stages(id) ON DELETE SET NULL,
  owner_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  lat double precision NOT NULL,
  lng double precision NOT NULL,
  accuracy double precision,
  heading double precision,
  speed double precision,
  source text NOT NULL DEFAULT 'watch',
  recorded_at timestamptz NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS gps_location_updates_booking_idx ON public.gps_location_updates (booking_request_id, recorded_at);

CREATE TABLE IF NOT EXISTS public.live_locations (
  booking_request_id uuid PRIMARY KEY REFERENCES public.booking_requests(id) ON DELETE CASCADE,
  stage_id uuid REFERENCES public.journey_stages(id) ON DELETE SET NULL,
  owner_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  lat double precision,
  lng double precision,
  accuracy double precision,
  heading double precision,
  speed double precision,
  recorded_at timestamptz,
  received_at timestamptz,
  tracking boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.audit_log (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  actor_id uuid,
  action text NOT NULL,
  entity text NOT NULL,
  entity_id uuid,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS audit_log_entity_idx ON public.audit_log (entity, entity_id, created_at);

-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║  STEP 3 — ALL FUNCTIONS                                                     ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝

-- Security helpers
CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role app_role)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role);
$$;

CREATE OR REPLACE FUNCTION public.is_assigned_partner(_booking uuid, _user uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.trip_assignments WHERE booking_request_id = _booking AND partner_id = _user AND status = 'accepted'
  );
$$;

CREATE OR REPLACE FUNCTION public.assert_admin()
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT public.has_role(auth.uid(), 'admin') THEN
    RAISE EXCEPTION 'Accès réservé aux administrateurs';
  END IF;
END $$;

-- Geo helpers
CREATE OR REPLACE FUNCTION public.geo_valid(_lat double precision, _lng double precision)
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT _lat IS NOT NULL AND _lng IS NOT NULL AND _lat BETWEEN -90 AND 90 AND _lng BETWEEN -180 AND 180
    AND NOT (_lat = 0 AND _lng = 0);
$$;

CREATE OR REPLACE FUNCTION public.geo_distance_m(_lat1 double precision, _lng1 double precision, _lat2 double precision, _lng2 double precision)
RETURNS double precision LANGUAGE sql IMMUTABLE AS $$
  SELECT 2 * 6371000 * asin(sqrt(
    power(sin(radians(_lat2 - _lat1) / 2), 2)
    + cos(radians(_lat1)) * cos(radians(_lat2)) * power(sin(radians(_lng2 - _lng1) / 2), 2)));
$$;

CREATE OR REPLACE FUNCTION public.audit(_action text, _entity text, _id uuid, _details jsonb DEFAULT '{}'::jsonb)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  INSERT INTO public.audit_log (actor_id, action, entity, entity_id, details) VALUES (auth.uid(), _action, _entity, _id, coalesce(_details, '{}'::jsonb));
$$;

CREATE OR REPLACE FUNCTION public.can_view_booking(_booking uuid, _user uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT _user IS NOT NULL AND (
    public.has_role(_user, 'admin')
    OR EXISTS (SELECT 1 FROM public.booking_requests b WHERE b.id = _booking AND (
      b.client_id = _user
      OR (b.owner_id = _user AND b.status::text IN ('approved', 'awaiting_owner', 'confirmed', 'in_progress', 'completed', 'cancelled')))));
$$;

CREATE OR REPLACE FUNCTION public.can_view_live_location(_booking uuid, _user uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT _user IS NOT NULL AND (
    public.has_role(_user, 'admin')
    OR EXISTS (SELECT 1 FROM public.booking_requests b WHERE b.id = _booking AND (
      b.owner_id = _user OR (b.client_id = _user AND b.status::text = 'in_progress'))));
$$;

CREATE OR REPLACE FUNCTION public.notify_user(_user uuid, _title text, _body text, _link text)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  INSERT INTO public.notifications (user_id, title, body, link) SELECT _user, _title, _body, _link WHERE _user IS NOT NULL;
$$;

CREATE OR REPLACE FUNCTION public.notify_admins(_title text, _body text)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  INSERT INTO public.notifications (audience, title, body, link) VALUES ('admin', _title, _body, '/admin');
$$;

-- Availability check
CREATE OR REPLACE FUNCTION public.car_window_status(_car uuid, _start timestamptz, _end timestamptz, _ignore uuid DEFAULT NULL)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  _mode text; _ls timestamp; _le timestamp; _d date; _from time; _to time; _ok boolean;
BEGIN
  SELECT availability_mode INTO _mode FROM public.cars WHERE id = _car;
  IF NOT FOUND THEN RETURN 'unknown'; END IF;
  IF _start IS NULL OR _end IS NULL OR _end <= _start THEN RETURN 'invalid'; END IF;
  IF EXISTS (SELECT 1 FROM public.booking_requests b
             WHERE b.car_id = _car AND b.id IS DISTINCT FROM _ignore
               AND b.status::text IN ('approved', 'awaiting_owner', 'confirmed', 'in_progress')
               AND b.service_start_at < _end AND b.service_end_at > _start) THEN
    RETURN 'booked';
  END IF;
  _ls := _start AT TIME ZONE 'Africa/Tunis';
  _le := _end AT TIME ZONE 'Africa/Tunis';
  _d := _ls::date;
  WHILE _d <= (_le - interval '1 microsecond')::date LOOP
    _from := CASE WHEN _d = _ls::date THEN _ls::time ELSE time '00:00' END;
    _to := CASE WHEN _d = _le::date THEN _le::time ELSE time '24:00' END;
    IF EXISTS (SELECT 1 FROM public.car_availability_rules r
               WHERE r.car_id = _car AND NOT r.available
                 AND ((r.kind = 'dates' AND _d BETWEEN r.date_from AND r.date_to)
                      OR (r.kind = 'weekly' AND r.weekday = extract(dow FROM _d)))
                 AND (r.start_time IS NULL OR (r.start_time < _to AND r.end_time > _from))) THEN
      RETURN 'unavailable';
    END IF;
    IF EXISTS (SELECT 1 FROM public.car_availability_rules r
               WHERE r.car_id = _car AND r.available AND r.kind = 'dates' AND _d BETWEEN r.date_from AND r.date_to) THEN
      _ok := EXISTS (SELECT 1 FROM public.car_availability_rules r
                     WHERE r.car_id = _car AND r.available AND r.kind = 'dates' AND _d BETWEEN r.date_from AND r.date_to
                       AND (r.start_time IS NULL OR (r.start_time <= _from AND r.end_time >= _to)));
    ELSIF _mode = 'always' THEN _ok := true;
    ELSE
      _ok := EXISTS (SELECT 1 FROM public.car_availability_rules r
                     WHERE r.car_id = _car AND r.available AND r.kind = 'weekly' AND r.weekday = extract(dow FROM _d)
                       AND (r.start_time IS NULL OR (r.start_time <= _from AND r.end_time >= _to)));
    END IF;
    IF NOT _ok THEN RETURN 'unavailable'; END IF;
    _d := _d + 1;
  END LOOP;
  RETURN 'available';
END $$;

CREATE OR REPLACE FUNCTION public.car_calendar_bookings(_car uuid, _from date, _to date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT (public.has_role(auth.uid(), 'admin')
     OR EXISTS (SELECT 1 FROM public.cars WHERE id = _car AND owner_id = auth.uid())) THEN
    RAISE EXCEPTION 'Non autorisé';
  END IF;
  IF _to < _from OR _to - _from > 400 THEN RAISE EXCEPTION 'Période invalide'; END IF;
  RETURN coalesce((
    SELECT jsonb_agg(jsonb_build_object('id', b.id, 'reference', b.reference, 'status', b.status,
             'start', b.service_start_at, 'end', b.service_end_at) ORDER BY b.service_start_at)
    FROM public.booking_requests b
    WHERE b.car_id = _car AND b.service_start_at IS NOT NULL
      AND b.status::text NOT IN ('rejected', 'cancelled')
      AND b.service_start_at < ((_to + 1)::timestamp AT TIME ZONE 'Africa/Tunis')
      AND b.service_end_at > (_from::timestamp AT TIME ZONE 'Africa/Tunis')), '[]'::jsonb);
END $$;

-- Partner account linking
CREATE OR REPLACE FUNCTION public.link_partner_account(_user uuid)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _email text; _n integer := 0; p record;
BEGIN
  SELECT email INTO _email FROM auth.users WHERE id = _user AND email_confirmed_at IS NOT NULL;
  IF _email IS NULL THEN RETURN 0; END IF;
  FOR p IN SELECT * FROM public.car_proposals WHERE status = 'approved' AND partner_user_id IS NULL AND lower(email) = lower(_email) LOOP
    UPDATE public.car_proposals SET partner_user_id = _user, updated_at = now() WHERE id = p.id;
    IF p.car_id IS NOT NULL THEN UPDATE public.cars SET owner_id = _user, updated_at = now() WHERE id = p.car_id AND owner_id IS NULL; END IF;
    INSERT INTO public.profiles (id, first_name, last_name, phone) VALUES (_user, p.first_name, p.last_name, p.phone)
      ON CONFLICT (id) DO UPDATE SET
        first_name = CASE WHEN profiles.first_name = '' THEN EXCLUDED.first_name ELSE profiles.first_name END,
        last_name = CASE WHEN profiles.last_name = '' THEN EXCLUDED.last_name ELSE profiles.last_name END,
        phone = COALESCE(profiles.phone, EXCLUDED.phone);
    INSERT INTO public.notifications (user_id, title, body, link) VALUES (_user, 'Dossier accepté', 'Bienvenue parmi nos partenaires.', '/partenaire');
    _n := _n + 1;
  END LOOP;
  IF _n > 0 THEN INSERT INTO public.user_roles (user_id, role) VALUES (_user, 'partner') ON CONFLICT (user_id, role) DO NOTHING; END IF;
  RETURN _n;
END $$;

CREATE OR REPLACE FUNCTION public.on_auth_user_confirmed()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.email_confirmed_at IS NOT NULL THEN
    BEGIN PERFORM public.link_partner_account(NEW.id);
    EXCEPTION WHEN OTHERS THEN RAISE WARNING 'link_partner_account failed: %', SQLERRM; END;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS far7tek_partner_link ON auth.users;
CREATE TRIGGER far7tek_partner_link
  AFTER INSERT OR UPDATE OF email_confirmed_at ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.on_auth_user_confirmed();

CREATE OR REPLACE FUNCTION public.claim_partner_account()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN 0; END IF;
  RETURN public.link_partner_account(auth.uid());
END $$;

-- Admin functions
CREATE OR REPLACE FUNCTION public.admin_approve_partner(_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE p public.car_proposals%ROWTYPE; _car uuid; _uid uuid;
BEGIN
  PERFORM public.assert_admin();
  SELECT * INTO p FROM public.car_proposals WHERE id = _id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Dossier introuvable'; END IF;
  IF p.status = 'approved' THEN
    RETURN jsonb_build_object('car_id', p.car_id, 'linked', p.partner_user_id IS NOT NULL, 'email', p.email, 'already', true);
  END IF;
  INSERT INTO public.cars (name, brand, model, slug, year, color, category, short_description, description,
                           price_from, availability, active, validation_status, seats, city, services)
  VALUES (p.brand || ' ' || p.model, p.brand, p.model,
          trim(both '-' from lower(regexp_replace(p.brand || '-' || p.model || '-' || left(p.id::text, 6), '[^a-zA-Z0-9]+', '-', 'g'))),
          p.year, p.color, p.vehicle_type, left(p.description, 140), p.description,
          NULLIF(p.desired_rate, 0), p.availability, false, 'pending', p.seats, p.city, p.services)
  RETURNING id INTO _car;
  UPDATE public.car_proposals SET status = 'approved', car_id = _car, updated_at = now() WHERE id = p.id;
  SELECT id INTO _uid FROM auth.users WHERE lower(email) = lower(p.email) AND email_confirmed_at IS NOT NULL LIMIT 1;
  IF _uid IS NOT NULL THEN PERFORM public.link_partner_account(_uid); END IF;
  RETURN jsonb_build_object('car_id', _car, 'linked', _uid IS NOT NULL, 'email', p.email, 'already', false);
END $$;

CREATE OR REPLACE FUNCTION public.admin_review_partner(_id uuid, _action text, _message text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM public.assert_admin();
  _message := trim(coalesce(_message, ''));
  IF _action NOT IN ('reject', 'info', 'reviewing') THEN RAISE EXCEPTION 'Action inconnue'; END IF;
  IF _action <> 'reviewing' AND _message = '' THEN RAISE EXCEPTION 'Merci d''indiquer un motif ou un message'; END IF;
  IF length(_message) > 1000 THEN RAISE EXCEPTION 'Message trop long'; END IF;
  IF _action = 'reject' THEN
    UPDATE public.car_proposals SET status = 'rejected', rejection_reason = _message, updated_at = now() WHERE id = _id;
  ELSIF _action = 'info' THEN
    UPDATE public.car_proposals SET status = 'info_requested', info_request = _message, updated_at = now() WHERE id = _id;
  ELSE
    UPDATE public.car_proposals SET status = 'reviewing', updated_at = now() WHERE id = _id;
  END IF;
  IF NOT FOUND THEN RAISE EXCEPTION 'Dossier introuvable'; END IF;
END $$;

CREATE OR REPLACE FUNCTION public.admin_set_car_validation(_car uuid, _status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE c record;
BEGIN
  PERFORM public.assert_admin();
  IF _status NOT IN ('active', 'disabled', 'pending') THEN RAISE EXCEPTION 'Statut invalide'; END IF;
  UPDATE public.cars SET validation_status = _status, active = (_status = 'active'), updated_at = now()
    WHERE id = _car RETURNING owner_id, name INTO c;
  IF NOT FOUND THEN RAISE EXCEPTION 'Véhicule introuvable'; END IF;
  IF c.owner_id IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, title, body, link) VALUES (
      c.owner_id,
      CASE WHEN _status = 'active' THEN 'Véhicule publié' ELSE 'Véhicule mis à jour' END,
      c.name || ' : ' || CASE WHEN _status = 'active' THEN 'visible sur la plateforme' ELSE 'non publié' END || '.',
      '/partenaire');
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.admin_assign_trip(_booking uuid, _partner uuid, _car uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _ref text;
BEGIN
  PERFORM public.assert_admin();
  IF NOT public.has_role(_partner, 'partner') THEN RAISE EXCEPTION 'Ce partenaire n''a pas encore activé son compte'; END IF;
  IF EXISTS (SELECT 1 FROM public.trip_assignments WHERE booking_request_id = _booking AND status <> 'rejected') THEN
    RAISE EXCEPTION 'Cette demande est déjà attribuée';
  END IF;
  SELECT reference INTO _ref FROM public.booking_requests WHERE id = _booking;
  IF NOT FOUND THEN RAISE EXCEPTION 'Demande introuvable'; END IF;
  INSERT INTO public.trip_assignments (booking_request_id, partner_id, car_id) VALUES (_booking, _partner, _car);
  INSERT INTO public.trip_status_history (booking_request_id, status, changed_by, note) VALUES (_booking, 'assigned', auth.uid(), 'Attribuée à un partenaire');
  INSERT INTO public.notifications (user_id, title, body, link) VALUES (_partner, 'Nouvelle demande attribuée', 'Demande ' || coalesce(_ref, '') || ' à traiter.', '/partenaire');
END $$;

CREATE OR REPLACE FUNCTION public.admin_set_booking_status(_id uuid, _status text, _note text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE b record;
BEGIN
  PERFORM public.assert_admin();
  IF _status NOT IN ('pending', 'contacted', 'accepted', 'rejected', 'confirmed', 'in_progress', 'completed', 'cancelled') THEN
    RAISE EXCEPTION 'Statut invalide';
  END IF;
  UPDATE public.booking_requests SET status = _status::booking_status, updated_at = now() WHERE id = _id RETURNING client_id, reference INTO b;
  IF NOT FOUND THEN RAISE EXCEPTION 'Demande introuvable'; END IF;
  INSERT INTO public.trip_status_history (booking_request_id, status, changed_by, note) VALUES (_id, _status, auth.uid(), left(coalesce(_note, ''), 500));
  IF b.client_id IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, title, body, link) VALUES (b.client_id, 'Mise à jour de votre demande', 'Demande ' || b.reference || ' : nouveau statut.', '/compte');
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.admin_review_change_request(_id uuid, _approve boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE cr public.vehicle_change_requests%ROWTYPE; ch jsonb;
BEGIN
  PERFORM public.assert_admin();
  SELECT * INTO cr FROM public.vehicle_change_requests WHERE id = _id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Introuvable'; END IF;
  ch := cr.changes;
  IF _approve THEN
    UPDATE public.cars SET
      name = CASE WHEN ch ? 'name' THEN ch->>'name' ELSE name END,
      color = CASE WHEN ch ? 'color' THEN ch->>'color' ELSE color END,
      year = CASE WHEN ch ? 'year' THEN NULLIF(ch->>'year', '')::int ELSE year END,
      seats = CASE WHEN ch ? 'seats' THEN NULLIF(ch->>'seats', '')::int ELSE seats END,
      description = CASE WHEN ch ? 'description' THEN ch->>'description' ELSE description END,
      short_description = CASE WHEN ch ? 'short_description' THEN ch->>'short_description' ELSE short_description END,
      price_from = CASE WHEN ch ? 'price_from' THEN NULLIF(ch->>'price_from', '')::numeric ELSE price_from END,
      city = CASE WHEN ch ? 'city' THEN ch->>'city' ELSE city END,
      category = CASE WHEN ch ? 'category' THEN ch->>'category' ELSE category END,
      updated_at = now()
    WHERE id = cr.car_id;
  END IF;
  UPDATE public.vehicle_change_requests SET status = CASE WHEN _approve THEN 'approved' ELSE 'rejected' END WHERE id = cr.id;
  INSERT INTO public.notifications (user_id, title, body, link) VALUES (cr.partner_id,
    CASE WHEN _approve THEN 'Modification validée' ELSE 'Modification refusée' END,
    'Votre demande de modification du véhicule a été traitée.', '/partenaire');
END $$;

CREATE OR REPLACE FUNCTION public.admin_list_clients()
RETURNS TABLE (id uuid, email text, created_at timestamptz, last_sign_in_at timestamptz, roles text[], requests integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM public.assert_admin();
  RETURN QUERY
    SELECT u.id, u.email::text, u.created_at, u.last_sign_in_at,
      COALESCE((SELECT array_agg(r.role::text) FROM public.user_roles r WHERE r.user_id = u.id), '{}'),
      (SELECT count(*)::int FROM public.booking_requests b WHERE b.client_id = u.id)
    FROM auth.users u ORDER BY u.created_at DESC LIMIT 1000;
END $$;

CREATE OR REPLACE FUNCTION public.admin_list_owners()
RETURNS TABLE (id uuid, first_name text, last_name text, phone text, email text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM public.assert_admin();
  RETURN QUERY
    SELECT u.id, coalesce(p.first_name, ''), coalesce(p.last_name, ''), p.phone, u.email::text
    FROM auth.users u LEFT JOIN public.profiles p ON p.id = u.id
    WHERE EXISTS (SELECT 1 FROM public.user_roles r WHERE r.user_id = u.id AND r.role = 'partner')
       OR EXISTS (SELECT 1 FROM public.cars c WHERE c.owner_id = u.id)
    ORDER BY p.last_name, p.first_name;
END $$;

-- Partner functions
CREATE OR REPLACE FUNCTION public.partner_respond_assignment(_id uuid, _accept boolean, _reason text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE a public.trip_assignments%ROWTYPE; b record;
BEGIN
  _reason := trim(coalesce(_reason, ''));
  SELECT * INTO a FROM public.trip_assignments WHERE id = _id FOR UPDATE;
  IF NOT FOUND OR a.partner_id <> auth.uid() THEN RAISE EXCEPTION 'Demande introuvable'; END IF;
  IF a.status <> 'proposed' THEN RAISE EXCEPTION 'Demande déjà traitée'; END IF;
  IF NOT _accept AND _reason = '' THEN RAISE EXCEPTION 'Merci d''indiquer un motif de refus'; END IF;
  UPDATE public.trip_assignments SET status = CASE WHEN _accept THEN 'accepted' ELSE 'rejected' END,
    rejection_reason = CASE WHEN _accept THEN NULL ELSE left(_reason, 500) END, updated_at = now() WHERE id = a.id;
  IF _accept THEN
    UPDATE public.booking_requests SET status = 'accepted', updated_at = now() WHERE id = a.booking_request_id RETURNING client_id, reference INTO b;
  END IF;
  INSERT INTO public.trip_status_history (booking_request_id, status, changed_by, note)
    VALUES (a.booking_request_id, CASE WHEN _accept THEN 'accepted' ELSE 'partner_rejected' END, auth.uid(), left(_reason, 500));
  INSERT INTO public.notifications (audience, title, body, link)
    VALUES ('admin', CASE WHEN _accept THEN 'Trajet accepté par un partenaire' ELSE 'Trajet refusé par un partenaire' END, left(_reason, 500), '/admin');
  IF _accept AND b.client_id IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, title, body, link) VALUES (b.client_id, 'Chauffeur trouvé', 'Votre demande ' || b.reference || ' a été acceptée.', '/compte');
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.partner_update_trip_status(_booking uuid, _status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE b public.booking_requests%ROWTYPE; _from text;
BEGIN
  SELECT * INTO b FROM public.booking_requests WHERE id = _booking FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Demande introuvable'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.trip_assignments WHERE booking_request_id = _booking AND partner_id = auth.uid() AND status = 'accepted') THEN
    RAISE EXCEPTION 'Vous devez d''abord accepter cette demande';
  END IF;
  _from := b.status::text;
  IF NOT ((_from = 'accepted' AND _status IN ('confirmed', 'cancelled'))
       OR (_from = 'confirmed' AND _status IN ('in_progress', 'cancelled'))
       OR (_from = 'in_progress' AND _status = 'completed')) THEN
    RAISE EXCEPTION 'Changement de statut non autorisé';
  END IF;
  UPDATE public.booking_requests SET status = _status::booking_status, updated_at = now() WHERE id = b.id;
  INSERT INTO public.trip_status_history (booking_request_id, status, changed_by) VALUES (b.id, _status, auth.uid());
  IF b.client_id IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, title, body, link) VALUES (b.client_id, 'Mise à jour de votre trajet', 'Demande ' || b.reference || ' mise à jour.', '/compte');
  END IF;
  INSERT INTO public.notifications (audience, title, body, link) VALUES ('admin', 'Statut de trajet modifié', b.reference || ' → ' || _status, '/admin');
END $$;

CREATE OR REPLACE FUNCTION public.partner_update_car_availability(_car uuid, _availability text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  _availability := trim(coalesce(_availability, ''));
  IF _availability = '' OR length(_availability) > 300 THEN RAISE EXCEPTION 'Disponibilités invalides'; END IF;
  UPDATE public.cars SET availability = _availability, updated_at = now() WHERE id = _car AND owner_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'Véhicule introuvable'; END IF;
END $$;

CREATE OR REPLACE FUNCTION public.partner_add_car_photo(_car uuid, _path text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _name text;
BEGIN
  SELECT name INTO _name FROM public.cars WHERE id = _car AND owner_id = auth.uid();
  IF NOT FOUND OR _path IS NULL OR length(_path) > 300 OR left(_path, length(auth.uid()::text) + 1) <> auth.uid()::text || '/' THEN
    RAISE EXCEPTION 'Non autorisé';
  END IF;
  INSERT INTO public.car_images (car_id, storage_path, sort_order) VALUES (_car, _path, 50);
  INSERT INTO public.notifications (audience, title, body, link) VALUES ('admin', 'Nouvelle photo partenaire', _name, '/admin');
END $$;

-- Transport submit request (THE function that "Envoyer ma demande" calls)
CREATE OR REPLACE FUNCTION public.transport_submit_request(_data jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  _uid uuid := auth.uid(); _email text; _car uuid; _car_name text; _car_type text; _owner uuid; _seats int; _services text[];
  _cat text := _data->>'category'; _first text := left(trim(coalesce(_data->>'first_name', '')), 80);
  _last text := left(trim(coalesce(_data->>'last_name', '')), 80); _phone text := trim(coalesce(_data->>'phone', ''));
  _city text := left(trim(coalesce(_data->>'city', '')), 80);
  _pickup text := left(trim(coalesce(_data->>'pickup_address', '')), 250);
  _dest text := left(trim(coalesce(_data->>'destination_address', '')), 250);
  _round boolean := coalesce((_data->>'round_trip')::boolean, false);
  _stops jsonb := coalesce(_data->'stops', '[]'::jsonb); _clean jsonb := '[]'::jsonb; st jsonb;
  _a text; _la double precision; _lo double precision; _date date; _time time; _ret time; _pass int;
  _plat double precision; _plng double precision; _dlat double precision; _dlng double precision;
  _start timestamptz; _ret_at timestamptz; _end timestamptz; _avail text := NULL; _ref text; _id uuid;
BEGIN
  IF _uid IS NULL THEN RAISE EXCEPTION 'Connexion requise'; END IF;
  IF _cat IS NULL OR _cat NOT IN ('wedding', 'family') THEN RAISE EXCEPTION 'Catégorie invalide'; END IF;
  BEGIN
    _date := (_data->>'date')::date; _time := (_data->>'time')::time;
    _ret := NULLIF(_data->>'return_time', '')::time; _pass := (_data->>'passengers')::int;
    _plat := (_data->>'pickup_lat')::double precision; _plng := (_data->>'pickup_lng')::double precision;
    _dlat := (_data->>'destination_lat')::double precision; _dlng := (_data->>'destination_lng')::double precision;
  EXCEPTION WHEN invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow OR numeric_value_out_of_range THEN
    RAISE EXCEPTION 'Données de la demande invalides';
  END;
  IF _first = '' OR _last = '' THEN RAISE EXCEPTION 'Nom et prénom requis'; END IF;
  IF _phone !~ '^[+0-9 .()-]{6,20}$' THEN RAISE EXCEPTION 'Téléphone invalide'; END IF;
  IF _city = '' THEN RAISE EXCEPTION 'Ville requise'; END IF;
  IF length(_pickup) < 3 OR length(_dest) < 3 THEN RAISE EXCEPTION 'Adresses de départ et de destination requises'; END IF;
  IF NOT public.geo_valid(_plat, _plng) OR NOT public.geo_valid(_dlat, _dlng) THEN
    RAISE EXCEPTION 'Placez le départ et la destination sur la carte';
  END IF;
  IF _date IS NULL OR _time IS NULL THEN RAISE EXCEPTION 'Date et heure requises'; END IF;
  IF _date < (now() AT TIME ZONE 'Africa/Tunis')::date OR _date > (now() AT TIME ZONE 'Africa/Tunis')::date + 730 THEN
    RAISE EXCEPTION 'La date doit être à venir';
  END IF;
  IF _pass IS NULL OR _pass < 1 OR _pass > 60 THEN RAISE EXCEPTION 'Nombre de passagers invalide'; END IF;
  IF _round AND _ret IS NULL THEN RAISE EXCEPTION 'Heure de retour requise pour un aller-retour'; END IF;
  IF length(coalesce(_data->>'requirements', '')) > 1500 OR length(coalesce(_data->>'client_notes', '')) > 1500
     OR length(coalesce(_data->>'contact_extra', '')) > 300 THEN RAISE EXCEPTION 'Texte trop long'; END IF;
  IF jsonb_typeof(_stops) <> 'array' OR jsonb_array_length(_stops) > 5 THEN RAISE EXCEPTION 'Arrêts invalides (5 maximum)'; END IF;
  FOR st IN SELECT value FROM jsonb_array_elements(_stops) LOOP
    _a := left(trim(coalesce(st->>'address', '')), 250);
    BEGIN _la := (st->>'lat')::double precision; _lo := (st->>'lng')::double precision;
    EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'Arrêt invalide'; END;
    IF _a = '' OR NOT public.geo_valid(_la, _lo) THEN RAISE EXCEPTION 'Arrêt invalide'; END IF;
    _clean := _clean || jsonb_build_array(jsonb_build_object('address', _a, 'lat', _la, 'lng', _lo));
  END LOOP;
  _car := NULLIF(_data->>'car_id', '')::uuid;
  IF _car IS NOT NULL THEN
    SELECT name, category, owner_id, seats, services INTO _car_name, _car_type, _owner, _seats, _services
      FROM public.cars WHERE id = _car AND active;
    IF NOT FOUND THEN RAISE EXCEPTION 'Véhicule indisponible'; END IF;
    IF NOT (_services && CASE WHEN _cat = 'wedding' THEN ARRAY['wedding', 'event'] ELSE ARRAY['family', 'private'] END) THEN
      RAISE EXCEPTION 'Ce véhicule ne propose pas ce service';
    END IF;
    IF _seats IS NOT NULL AND _pass > _seats THEN RAISE EXCEPTION 'Trop de passagers pour ce véhicule (% places)', _seats; END IF;
  END IF;
  _start := (_date + _time) AT TIME ZONE 'Africa/Tunis';
  IF _round THEN
    _ret_at := (_date + _ret) AT TIME ZONE 'Africa/Tunis' + CASE WHEN _ret <= _time THEN interval '1 day' ELSE interval '0' END;
    _end := _ret_at + interval '90 minutes';
  ELSE _end := _start + interval '3 hours'; END IF;
  IF _car IS NOT NULL THEN
    _avail := public.car_window_status(_car, _start, _end);
    IF _avail = 'booked' THEN RAISE EXCEPTION 'Ce véhicule est déjà réservé sur ce créneau'; END IF;
  END IF;
  LOOP _ref := 'F7-' || upper(substr(md5(gen_random_uuid()::text), 1, 6)); EXIT WHEN NOT EXISTS (SELECT 1 FROM public.booking_requests WHERE reference = _ref); END LOOP;
  SELECT email INTO _email FROM auth.users WHERE id = _uid;
  INSERT INTO public.booking_requests (
    first_name, last_name, phone, email, wedding_date, wedding_time, return_time, city, venue, car_id, car_name,
    service_type, message, status, client_id, pickup_address, destination_type, passengers, vehicle_type, trip_type,
    reference, owner_id, category, pickup_lat, pickup_lng, destination_lat, destination_lng, stops, client_notes,
    contact_extra, service_start_at, service_end_at)
  VALUES (
    _first, _last, _phone, coalesce(_email, ''), _date, _time, CASE WHEN _round THEN _ret END, _city, _dest, _car,
    coalesce(_car_name, 'Sans préférence'), _cat, left(trim(coalesce(_data->>'requirements', '')), 1500), 'pending', _uid,
    _pickup, left(coalesce(NULLIF(_data->>'destination_type', ''), 'autre'), 40), _pass, coalesce(_car_type, ''),
    CASE WHEN _round THEN 'round_trip' ELSE 'one_way' END, _ref, _owner, _cat, _plat, _plng, _dlat, _dlng, _clean,
    left(trim(coalesce(_data->>'client_notes', '')), 1500), left(trim(coalesce(_data->>'contact_extra', '')), 300), _start, _end)
  RETURNING id INTO _id;
  INSERT INTO public.journey_stages (booking_request_id, stage_no, label, from_address, from_lat, from_lng, to_address, to_lat, to_lng, stops, scheduled_at)
    VALUES (_id, 1, 'Aller', _pickup, _plat, _plng, _dest, _dlat, _dlng, _clean, _start);
  IF _round THEN
    INSERT INTO public.journey_stages (booking_request_id, stage_no, label, from_address, from_lat, from_lng, to_address, to_lat, to_lng, scheduled_at)
      VALUES (_id, 2, 'Retour', _dest, _dlat, _dlng, _pickup, _plat, _plng, _ret_at);
  END IF;
  INSERT INTO public.trip_status_history (booking_request_id, status, changed_by, note) VALUES (_id, 'pending', _uid, 'Demande envoyée');
  PERFORM public.notify_admins('Nouvelle demande de transport', _ref || ' · ' || coalesce(_car_name, 'véhicule à attribuer') || ' · ' || to_char(_date, 'DD/MM/YYYY'));
  PERFORM public.audit('request_submitted', 'booking_request', _id, jsonb_build_object('car', _car, 'availability', _avail));
  RETURN jsonb_build_object('id', _id, 'reference', _ref, 'availability', _avail);
END $$;

CREATE OR REPLACE FUNCTION public.transport_client_cancel(_id uuid, _reason text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE b public.booking_requests%ROWTYPE;
BEGIN
  SELECT * INTO b FROM public.booking_requests WHERE id = _id FOR UPDATE;
  IF NOT FOUND OR b.client_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Demande introuvable'; END IF;
  IF b.status::text NOT IN ('new', 'pending', 'contacted', 'under_review', 'approved', 'awaiting_owner', 'confirmed', 'accepted') THEN
    RAISE EXCEPTION 'Cette demande ne peut plus être annulée';
  END IF;
  UPDATE public.booking_requests SET status = 'cancelled', decision_note = left(trim(coalesce(_reason, '')), 500), updated_at = now() WHERE id = b.id;
  UPDATE public.journey_stages SET status = 'cancelled', updated_at = now() WHERE booking_request_id = b.id AND status = 'pending';
  INSERT INTO public.trip_status_history (booking_request_id, status, changed_by, note) VALUES (b.id, 'cancelled', auth.uid(), left('Annulée par le client. ' || coalesce(_reason, ''), 500));
  PERFORM public.notify_admins('Demande annulée par le client', b.reference);
  IF b.status::text IN ('approved', 'awaiting_owner', 'confirmed') THEN
    PERFORM public.notify_user(b.owner_id, 'Réservation annulée', 'La réservation ' || b.reference || ' a été annulée.', '/partenaire');
  END IF;
  PERFORM public.audit('request_cancelled_by_client', 'booking_request', b.id);
END $$;

-- Admin transport functions
CREATE OR REPLACE FUNCTION public.transport_assert_slot(b public.booking_requests, _override boolean)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _avail text;
BEGIN
  IF b.car_id IS NULL OR b.owner_id IS NULL THEN RAISE EXCEPTION 'Attribuez d''abord un véhicule et son propriétaire'; END IF;
  IF b.service_start_at IS NULL OR b.service_end_at IS NULL THEN RAISE EXCEPTION 'Créneau horaire manquant'; END IF;
  PERFORM 1 FROM public.cars WHERE id = b.car_id FOR UPDATE;
  _avail := public.car_window_status(b.car_id, b.service_start_at, b.service_end_at, b.id);
  IF _avail = 'booked' THEN RAISE EXCEPTION 'Conflit : ce véhicule est déjà retenu sur ce créneau'; END IF;
  IF _avail = 'unavailable' AND NOT coalesce(_override, false) THEN
    RAISE EXCEPTION 'Le propriétaire est indisponible sur ce créneau (cochez « forcer » après accord téléphonique)';
  END IF;
  RETURN _avail;
END $$;

CREATE OR REPLACE FUNCTION public.admin_transport_set_status(_id uuid, _status text, _note text DEFAULT '', _override boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE b public.booking_requests%ROWTYPE; _from text; _avail text := NULL; _ok boolean; _title text;
BEGIN
  PERFORM public.assert_admin();
  _note := left(trim(coalesce(_note, '')), 500);
  SELECT * INTO b FROM public.booking_requests WHERE id = _id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Demande introuvable'; END IF;
  _from := b.status::text;
  IF _from = _status THEN RETURN jsonb_build_object('status', _status, 'already', true); END IF;
  _ok := CASE _from
    WHEN 'new' THEN _status IN ('under_review', 'approved', 'rejected', 'cancelled')
    WHEN 'pending' THEN _status IN ('under_review', 'approved', 'rejected', 'cancelled')
    WHEN 'contacted' THEN _status IN ('under_review', 'approved', 'rejected', 'cancelled')
    WHEN 'under_review' THEN _status IN ('pending', 'approved', 'rejected', 'cancelled')
    WHEN 'accepted' THEN _status IN ('approved', 'confirmed', 'cancelled')
    WHEN 'approved' THEN _status IN ('under_review', 'awaiting_owner', 'confirmed', 'rejected', 'cancelled')
    WHEN 'awaiting_owner' THEN _status IN ('under_review', 'approved', 'confirmed', 'cancelled')
    WHEN 'confirmed' THEN _status IN ('approved', 'cancelled')
    WHEN 'in_progress' THEN _status IN ('completed', 'cancelled')
    WHEN 'rejected' THEN _status IN ('under_review')
    ELSE false END;
  IF NOT _ok THEN RAISE EXCEPTION 'Transition de statut non autorisée (% → %)', _from, _status; END IF;
  IF _status = 'rejected' AND _note = '' THEN RAISE EXCEPTION 'Indiquez le motif du refus'; END IF;
  IF _status IN ('approved', 'awaiting_owner', 'confirmed') THEN _avail := public.transport_assert_slot(b, _override); END IF;
  BEGIN
    UPDATE public.booking_requests SET
      status = _status::public.booking_status,
      assigned_admin_id = coalesce(assigned_admin_id, auth.uid()),
      decision_note = CASE WHEN _status IN ('approved', 'rejected') THEN NULLIF(_note, '') ELSE decision_note END,
      decided_at = CASE WHEN _status IN ('approved', 'rejected') THEN now() ELSE decided_at END,
      updated_at = now()
    WHERE id = b.id;
  EXCEPTION WHEN exclusion_violation THEN
    RAISE EXCEPTION 'Conflit : ce véhicule a déjà une réservation confirmée sur ce créneau';
  END;
  IF _status IN ('completed', 'cancelled') AND _from = 'in_progress' THEN
    UPDATE public.journey_stages SET status = CASE WHEN _status = 'completed' THEN 'completed' ELSE 'cancelled' END,
      ended_at = now(), ended_by = auth.uid(), notes = trim(notes || ' Clôturée par l''administration.'), updated_at = now()
    WHERE booking_request_id = b.id AND status = 'in_progress';
    UPDATE public.journey_stages SET status = CASE WHEN _status = 'completed' THEN 'skipped' ELSE 'cancelled' END, updated_at = now()
    WHERE booking_request_id = b.id AND status = 'pending';
    UPDATE public.live_locations SET tracking = false, updated_at = now() WHERE booking_request_id = b.id;
    INSERT INTO public.journey_events (booking_request_id, event_type, actor_id, actor_role, note)
      VALUES (b.id, CASE WHEN _status = 'completed' THEN 'operation_completed' ELSE 'operation_cancelled' END, auth.uid(), 'admin', _note);
  ELSIF _status IN ('cancelled', 'rejected') THEN
    UPDATE public.journey_stages SET status = 'cancelled', updated_at = now() WHERE booking_request_id = b.id AND status = 'pending';
  END IF;
  INSERT INTO public.trip_status_history (booking_request_id, status, changed_by, note) VALUES (b.id, _status, auth.uid(), _note);
  _title := CASE _status
    WHEN 'under_review' THEN 'Demande en cours d''étude'
    WHEN 'approved' THEN 'Demande approuvée' WHEN 'awaiting_owner' THEN 'Demande approuvée'
    WHEN 'confirmed' THEN 'Réservation confirmée' WHEN 'rejected' THEN 'Demande refusée'
    WHEN 'cancelled' THEN 'Demande annulée' WHEN 'completed' THEN 'Transport terminé'
    ELSE 'Mise à jour de votre demande' END;
  PERFORM public.notify_user(b.client_id, _title, 'Demande ' || b.reference || CASE WHEN _note <> '' THEN ' : ' || _note ELSE '' END, '/compte');
  IF _status = 'awaiting_owner' THEN
    PERFORM public.notify_user(b.owner_id, 'Confirmation demandée', 'Merci de confirmer la réservation ' || b.reference || '.', '/partenaire');
  ELSIF _status IN ('approved', 'confirmed') THEN
    PERFORM public.notify_user(b.owner_id, CASE WHEN _status = 'confirmed' THEN 'Réservation confirmée' ELSE 'Nouvelle réservation approuvée' END, 'Réservation ' || b.reference || '.', '/partenaire');
  ELSIF _status IN ('cancelled', 'completed') AND _from IN ('approved', 'awaiting_owner', 'confirmed', 'in_progress') THEN
    PERFORM public.notify_user(b.owner_id, _title, 'Réservation ' || b.reference || '.', '/partenaire');
  END IF;
  PERFORM public.audit('status_' || _status, 'booking_request', b.id, jsonb_build_object('from', _from, 'note', _note, 'override', _override, 'availability', _avail));
  RETURN jsonb_build_object('status', _status, 'already', false, 'availability', _avail);
END $$;

CREATE OR REPLACE FUNCTION public.admin_transport_assign(_id uuid, _car uuid, _owner uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE b public.booking_requests%ROWTYPE; c record; _new_owner uuid;
BEGIN
  PERFORM public.assert_admin();
  SELECT * INTO b FROM public.booking_requests WHERE id = _id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Demande introuvable'; END IF;
  IF b.status::text IN ('in_progress', 'completed', 'cancelled', 'rejected') THEN RAISE EXCEPTION 'Demande déjà clôturée ou en cours'; END IF;
  SELECT id, name, category, owner_id, seats INTO c FROM public.cars WHERE id = _car;
  IF NOT FOUND THEN RAISE EXCEPTION 'Véhicule introuvable'; END IF;
  _new_owner := coalesce(_owner, c.owner_id);
  IF _new_owner IS NULL THEN RAISE EXCEPTION 'Ce véhicule n''a pas de propriétaire : choisissez-en un'; END IF;
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = _new_owner) THEN RAISE EXCEPTION 'Propriétaire introuvable'; END IF;
  IF c.seats IS NOT NULL AND b.passengers > c.seats THEN RAISE EXCEPTION 'Ce véhicule n''a que % places', c.seats; END IF;
  b.car_id := c.id; b.owner_id := _new_owner;
  IF b.status::text IN ('approved', 'awaiting_owner', 'confirmed') THEN PERFORM public.transport_assert_slot(b, true); END IF;
  BEGIN
    UPDATE public.booking_requests SET car_id = c.id, car_name = c.name, vehicle_type = coalesce(c.category, ''), owner_id = _new_owner,
      assigned_admin_id = coalesce(assigned_admin_id, auth.uid()), updated_at = now() WHERE id = _id;
  EXCEPTION WHEN exclusion_violation THEN RAISE EXCEPTION 'Conflit : ce véhicule a déjà une réservation confirmée sur ce créneau'; END;
  INSERT INTO public.trip_status_history (booking_request_id, status, changed_by, note) VALUES (_id, 'owner_assigned', auth.uid(), c.name);
  IF b.status::text IN ('approved', 'awaiting_owner', 'confirmed') THEN
    PERFORM public.notify_user(_new_owner, 'Réservation attribuée', 'Réservation ' || b.reference || ' · ' || c.name, '/partenaire');
  END IF;
  PERFORM public.audit('owner_assigned', 'booking_request', _id, jsonb_build_object('car', c.id, 'owner', _new_owner));
END $$;

CREATE OR REPLACE FUNCTION public.admin_transport_set_window(_id uuid, _start timestamptz, _end timestamptz)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE b public.booking_requests%ROWTYPE;
BEGIN
  PERFORM public.assert_admin();
  SELECT * INTO b FROM public.booking_requests WHERE id = _id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Demande introuvable'; END IF;
  IF b.status::text IN ('in_progress', 'completed', 'cancelled', 'rejected') THEN RAISE EXCEPTION 'Demande déjà clôturée ou en cours'; END IF;
  IF _start IS NULL OR _end IS NULL OR _end <= _start OR _end - _start > interval '24 hours' THEN RAISE EXCEPTION 'Créneau invalide (24 h maximum)'; END IF;
  b.service_start_at := _start; b.service_end_at := _end;
  IF b.status::text IN ('approved', 'awaiting_owner', 'confirmed') THEN PERFORM public.transport_assert_slot(b, true); END IF;
  BEGIN
    UPDATE public.booking_requests SET service_start_at = _start, service_end_at = _end, updated_at = now() WHERE id = _id;
  EXCEPTION WHEN exclusion_violation THEN RAISE EXCEPTION 'Conflit : ce véhicule a déjà une réservation confirmée sur ce créneau'; END;
  UPDATE public.journey_stages SET scheduled_at = _start, updated_at = now() WHERE booking_request_id = _id AND stage_no = 1 AND status = 'pending';
  INSERT INTO public.trip_status_history (booking_request_id, status, changed_by, note)
    VALUES (_id, 'schedule_updated', auth.uid(), to_char(_start AT TIME ZONE 'Africa/Tunis', 'DD/MM HH24:MI') || ' → ' || to_char(_end AT TIME ZONE 'Africa/Tunis', 'DD/MM HH24:MI'));
  PERFORM public.audit('schedule_updated', 'booking_request', _id, jsonb_build_object('start', _start, 'end', _end));
END $$;

CREATE OR REPLACE FUNCTION public.admin_transport_log_contact(_id uuid, _target text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM public.assert_admin();
  IF _target NOT IN ('owner', 'client') THEN RAISE EXCEPTION 'Cible invalide'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.booking_requests WHERE id = _id) THEN RAISE EXCEPTION 'Demande introuvable'; END IF;
  INSERT INTO public.trip_status_history (booking_request_id, status, changed_by, note) VALUES (_id, _target || '_contacted', auth.uid(), '');
  PERFORM public.audit(_target || '_contacted', 'booking_request', _id);
END $$;

-- Owner functions
CREATE OR REPLACE FUNCTION public.owner_transport_operations()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT coalesce(jsonb_agg(x.row ORDER BY x.start_at), '[]'::jsonb) FROM (
    SELECT b.service_start_at AS start_at, jsonb_build_object(
      'id', b.id, 'reference', b.reference, 'status', b.status, 'category', b.category,
      'car', CASE WHEN c.id IS NULL THEN NULL ELSE jsonb_build_object('id', c.id, 'name', c.name, 'slug', c.slug) END,
      'service_start_at', b.service_start_at, 'service_end_at', b.service_end_at,
      'wedding_date', b.wedding_date, 'wedding_time', b.wedding_time, 'return_time', b.return_time,
      'trip_type', b.trip_type, 'passengers', b.passengers, 'city', b.city,
      'pickup_address', b.pickup_address, 'pickup_lat', b.pickup_lat, 'pickup_lng', b.pickup_lng,
      'venue', b.venue, 'destination_lat', b.destination_lat, 'destination_lng', b.destination_lng,
      'stops', b.stops, 'requirements', b.message,
      'client_name', b.first_name || ' ' || b.last_name,
      'client_phone', CASE WHEN b.status::text IN ('confirmed', 'in_progress') THEN b.phone END,
      'contact_extra', CASE WHEN b.status::text IN ('confirmed', 'in_progress') THEN b.contact_extra END,
      'stages', coalesce((SELECT jsonb_agg(to_jsonb(s) ORDER BY s.stage_no) FROM public.journey_stages s WHERE s.booking_request_id = b.id), '[]'::jsonb)
    ) AS row
    FROM public.booking_requests b LEFT JOIN public.cars c ON c.id = b.car_id
    WHERE auth.uid() IS NOT NULL AND b.owner_id = auth.uid()
      AND b.status::text IN ('approved', 'awaiting_owner', 'confirmed', 'in_progress', 'completed', 'cancelled')
      AND (b.status::text <> 'cancelled' OR EXISTS (
        SELECT 1 FROM public.trip_status_history h WHERE h.booking_request_id = b.id AND h.status IN ('approved', 'awaiting_owner', 'confirmed')))
  ) x;
$$;

CREATE OR REPLACE FUNCTION public.owner_respond_booking(_id uuid, _accept boolean, _reason text DEFAULT '')
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE b public.booking_requests%ROWTYPE;
BEGIN
  _reason := left(trim(coalesce(_reason, '')), 500);
  SELECT * INTO b FROM public.booking_requests WHERE id = _id FOR UPDATE;
  IF NOT FOUND OR b.owner_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Réservation introuvable'; END IF;
  IF b.status::text NOT IN ('approved', 'awaiting_owner') THEN RAISE EXCEPTION 'Cette réservation n''attend pas votre confirmation'; END IF;
  IF _accept THEN
    PERFORM public.transport_assert_slot(b, true);
    BEGIN UPDATE public.booking_requests SET status = 'confirmed', updated_at = now() WHERE id = b.id;
    EXCEPTION WHEN exclusion_violation THEN RAISE EXCEPTION 'Conflit : votre véhicule a déjà une réservation confirmée sur ce créneau'; END;
    INSERT INTO public.trip_status_history (booking_request_id, status, changed_by, note) VALUES (b.id, 'confirmed', auth.uid(), 'Confirmée par le propriétaire');
    PERFORM public.notify_user(b.client_id, 'Réservation confirmée', 'Demande ' || b.reference || ' confirmée.', '/compte');
    PERFORM public.notify_admins('Réservation confirmée par le propriétaire', b.reference);
  ELSE
    IF _reason = '' THEN RAISE EXCEPTION 'Merci d''indiquer un motif'; END IF;
    UPDATE public.booking_requests SET status = 'under_review', updated_at = now() WHERE id = b.id;
    INSERT INTO public.trip_status_history (booking_request_id, status, changed_by, note) VALUES (b.id, 'owner_declined', auth.uid(), _reason);
    PERFORM public.notify_admins('Réservation refusée par le propriétaire', b.reference || ' : ' || _reason);
  END IF;
  PERFORM public.audit(CASE WHEN _accept THEN 'owner_confirmed' ELSE 'owner_declined' END, 'booking_request', b.id, jsonb_build_object('reason', _reason));
END $$;

CREATE OR REPLACE FUNCTION public.owner_set_availability_mode(_car uuid, _mode text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF _mode NOT IN ('always', 'schedule') THEN RAISE EXCEPTION 'Mode invalide'; END IF;
  UPDATE public.cars SET availability_mode = _mode, updated_at = now()
    WHERE id = _car AND (owner_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));
  IF NOT FOUND THEN RAISE EXCEPTION 'Véhicule introuvable'; END IF;
  PERFORM public.audit('availability_mode', 'car', _car, jsonb_build_object('mode', _mode));
END $$;

-- Journey functions
CREATE OR REPLACE FUNCTION public.journey_start_stage(_stage uuid, _lat double precision DEFAULT NULL, _lng double precision DEFAULT NULL, _accuracy double precision DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE s public.journey_stages%ROWTYPE; b public.booking_requests%ROWTYPE; _uid uuid := auth.uid(); _gps boolean := public.geo_valid(_lat, _lng);
BEGIN
  SELECT booking_request_id INTO b.id FROM public.journey_stages WHERE id = _stage;
  IF b.id IS NULL THEN RAISE EXCEPTION 'Étape introuvable'; END IF;
  SELECT * INTO b FROM public.booking_requests WHERE id = b.id FOR UPDATE;
  IF b.owner_id IS DISTINCT FROM _uid THEN RAISE EXCEPTION 'Seul le propriétaire assigné peut démarrer une étape'; END IF;
  SELECT * INTO s FROM public.journey_stages WHERE id = _stage FOR UPDATE;
  IF s.status IN ('in_progress', 'completed') THEN RETURN jsonb_build_object('stage', to_jsonb(s), 'already', true); END IF;
  IF s.status <> 'pending' THEN RAISE EXCEPTION 'Cette étape n''est plus disponible'; END IF;
  IF b.status::text NOT IN ('confirmed', 'in_progress') THEN RAISE EXCEPTION 'La réservation doit être confirmée avant le départ'; END IF;
  IF b.service_start_at IS NOT NULL AND now() < b.service_start_at - interval '12 hours' THEN
    RAISE EXCEPTION 'Trop tôt : le départ est prévu le %', to_char(b.service_start_at AT TIME ZONE 'Africa/Tunis', 'DD/MM/YYYY HH24:MI');
  END IF;
  IF EXISTS (SELECT 1 FROM public.journey_stages WHERE booking_request_id = b.id AND stage_no < s.stage_no AND status NOT IN ('completed', 'skipped')) THEN
    RAISE EXCEPTION 'Terminez d''abord l''étape précédente';
  END IF;
  IF EXISTS (SELECT 1 FROM public.journey_stages WHERE booking_request_id = b.id AND status = 'in_progress') THEN
    RAISE EXCEPTION 'Une autre étape est déjà en cours';
  END IF;
  IF _lat IS NOT NULL AND NOT _gps THEN RAISE EXCEPTION 'Coordonnées GPS invalides'; END IF;
  UPDATE public.journey_stages SET status = 'in_progress', started_at = now(), started_by = _uid,
    start_lat = CASE WHEN _gps THEN _lat END, start_lng = CASE WHEN _gps THEN _lng END,
    start_accuracy = CASE WHEN _gps THEN _accuracy END, updated_at = now() WHERE id = s.id RETURNING * INTO s;
  IF b.status::text = 'confirmed' THEN
    UPDATE public.booking_requests SET status = 'in_progress', updated_at = now() WHERE id = b.id;
    INSERT INTO public.trip_status_history (booking_request_id, status, changed_by, note) VALUES (b.id, 'in_progress', _uid, 'Départ de l''étape ' || s.stage_no);
  END IF;
  INSERT INTO public.journey_events (booking_request_id, stage_id, event_type, actor_id, actor_role, lat, lng, accuracy, note)
    VALUES (b.id, s.id, 'stage_started', _uid, 'owner', s.start_lat, s.start_lng, s.start_accuracy, CASE WHEN _gps THEN '' ELSE 'GPS indisponible au départ' END);
  INSERT INTO public.live_locations AS l (booking_request_id, stage_id, owner_id, lat, lng, accuracy, recorded_at, received_at, tracking, updated_at)
    VALUES (b.id, s.id, _uid, s.start_lat, s.start_lng, s.start_accuracy, CASE WHEN _gps THEN now() END, CASE WHEN _gps THEN now() END, true, now())
  ON CONFLICT (booking_request_id) DO UPDATE SET stage_id = EXCLUDED.stage_id, owner_id = EXCLUDED.owner_id, tracking = true, updated_at = now(),
    lat = coalesce(EXCLUDED.lat, l.lat), lng = coalesce(EXCLUDED.lng, l.lng), accuracy = coalesce(EXCLUDED.accuracy, l.accuracy),
    recorded_at = coalesce(EXCLUDED.recorded_at, l.recorded_at), received_at = coalesce(EXCLUDED.received_at, l.received_at);
  IF _gps THEN
    INSERT INTO public.gps_location_updates (booking_request_id, stage_id, owner_id, lat, lng, accuracy, source, recorded_at) VALUES (b.id, s.id, _uid, _lat, _lng, _accuracy, 'stage_start', now());
  END IF;
  PERFORM public.notify_admins('Départ : étape ' || s.stage_no, b.reference || ' · ' || s.from_address || ' → ' || s.to_address);
  PERFORM public.notify_user(b.client_id, 'Votre trajet a commencé', 'Demande ' || b.reference || ' : étape ' || s.stage_no || ' en cours.', '/compte');
  RETURN jsonb_build_object('stage', to_jsonb(s), 'already', false);
END $$;

CREATE OR REPLACE FUNCTION public.journey_end_stage(_stage uuid, _lat double precision DEFAULT NULL, _lng double precision DEFAULT NULL, _accuracy double precision DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE s public.journey_stages%ROWTYPE; b public.booking_requests%ROWTYPE; _uid uuid := auth.uid(); _gps boolean := public.geo_valid(_lat, _lng); _done boolean;
BEGIN
  SELECT booking_request_id INTO b.id FROM public.journey_stages WHERE id = _stage;
  IF b.id IS NULL THEN RAISE EXCEPTION 'Étape introuvable'; END IF;
  SELECT * INTO b FROM public.booking_requests WHERE id = b.id FOR UPDATE;
  IF b.owner_id IS DISTINCT FROM _uid THEN RAISE EXCEPTION 'Seul le propriétaire assigné peut terminer une étape'; END IF;
  SELECT * INTO s FROM public.journey_stages WHERE id = _stage FOR UPDATE;
  IF s.status = 'completed' THEN RETURN jsonb_build_object('stage', to_jsonb(s), 'already', true, 'operation_completed', b.status::text = 'completed'); END IF;
  IF s.status <> 'in_progress' THEN RAISE EXCEPTION 'Cette étape n''a pas démarré'; END IF;
  IF _lat IS NOT NULL AND NOT _gps THEN RAISE EXCEPTION 'Coordonnées GPS invalides'; END IF;
  UPDATE public.journey_stages SET status = 'completed', ended_at = now(), ended_by = _uid,
    end_lat = CASE WHEN _gps THEN _lat END, end_lng = CASE WHEN _gps THEN _lng END,
    end_accuracy = CASE WHEN _gps THEN _accuracy END, updated_at = now() WHERE id = s.id RETURNING * INTO s;
  INSERT INTO public.journey_events (booking_request_id, stage_id, event_type, actor_id, actor_role, lat, lng, accuracy, note)
    VALUES (b.id, s.id, 'stage_ended', _uid, 'owner', s.end_lat, s.end_lng, s.end_accuracy, CASE WHEN _gps THEN '' ELSE 'GPS indisponible à l''arrivée' END);
  IF _gps THEN
    INSERT INTO public.gps_location_updates (booking_request_id, stage_id, owner_id, lat, lng, accuracy, source, recorded_at) VALUES (b.id, s.id, _uid, _lat, _lng, _accuracy, 'stage_end', now());
  END IF;
  UPDATE public.live_locations SET tracking = false, updated_at = now(),
    lat = CASE WHEN _gps THEN _lat ELSE lat END, lng = CASE WHEN _gps THEN _lng ELSE lng END,
    accuracy = CASE WHEN _gps THEN _accuracy ELSE accuracy END,
    recorded_at = CASE WHEN _gps THEN now() ELSE recorded_at END, received_at = CASE WHEN _gps THEN now() ELSE received_at END
  WHERE booking_request_id = b.id;
  _done := NOT EXISTS (SELECT 1 FROM public.journey_stages WHERE booking_request_id = b.id AND status = 'pending');
  IF _done THEN
    UPDATE public.booking_requests SET status = 'completed', updated_at = now() WHERE id = b.id;
    INSERT INTO public.trip_status_history (booking_request_id, status, changed_by, note) VALUES (b.id, 'completed', _uid, 'Toutes les étapes sont terminées');
    INSERT INTO public.journey_events (booking_request_id, event_type, actor_id, actor_role) VALUES (b.id, 'operation_completed', _uid, 'owner');
    PERFORM public.notify_admins('Opération terminée', b.reference);
    PERFORM public.notify_user(b.client_id, 'Transport terminé', 'Demande ' || b.reference || ' : arrivée à destination finale.', '/compte');
  ELSE
    PERFORM public.notify_admins('Arrivée : étape ' || s.stage_no, b.reference || ' · ' || s.to_address);
    PERFORM public.notify_user(b.client_id, 'Étape terminée', 'Demande ' || b.reference || ' : étape ' || s.stage_no || ' terminée.', '/compte');
  END IF;
  RETURN jsonb_build_object('stage', to_jsonb(s), 'already', false, 'operation_completed', _done);
END $$;

CREATE OR REPLACE FUNCTION public.journey_mark_stop(_stage uuid, _index int, _lat double precision DEFAULT NULL, _lng double precision DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE s public.journey_stages%ROWTYPE; b public.booking_requests%ROWTYPE;
BEGIN
  SELECT booking_request_id INTO b.id FROM public.journey_stages WHERE id = _stage;
  IF b.id IS NULL THEN RAISE EXCEPTION 'Étape introuvable'; END IF;
  SELECT * INTO b FROM public.booking_requests WHERE id = b.id FOR UPDATE;
  IF b.owner_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Non autorisé'; END IF;
  SELECT * INTO s FROM public.journey_stages WHERE id = _stage FOR UPDATE;
  IF s.status <> 'in_progress' THEN RAISE EXCEPTION 'Cette étape n''est pas en cours'; END IF;
  IF _index < 0 OR _index >= jsonb_array_length(s.stops) THEN RAISE EXCEPTION 'Arrêt introuvable'; END IF;
  IF s.stops->_index ? 'reached_at' THEN RETURN jsonb_build_object('already', true); END IF;
  UPDATE public.journey_stages SET stops = jsonb_set(stops, ARRAY[_index::text, 'reached_at'], to_jsonb(now())), updated_at = now() WHERE id = s.id;
  INSERT INTO public.journey_events (booking_request_id, stage_id, event_type, actor_id, actor_role, lat, lng, note)
    VALUES (b.id, s.id, 'stop_reached', auth.uid(), 'owner', CASE WHEN public.geo_valid(_lat, _lng) THEN _lat END,
            CASE WHEN public.geo_valid(_lat, _lng) THEN _lng END, s.stops->_index->>'address');
  RETURN jsonb_build_object('already', false);
END $$;

CREATE OR REPLACE FUNCTION public.journey_client_signal(_stage uuid, _kind text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE s public.journey_stages%ROWTYPE; b public.booking_requests%ROWTYPE;
BEGIN
  IF _kind NOT IN ('arrival_confirmed', 'completion_requested') THEN RAISE EXCEPTION 'Action inconnue'; END IF;
  SELECT booking_request_id INTO b.id FROM public.journey_stages WHERE id = _stage;
  IF b.id IS NULL THEN RAISE EXCEPTION 'Étape introuvable'; END IF;
  SELECT * INTO b FROM public.booking_requests WHERE id = b.id FOR UPDATE;
  IF b.client_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Non autorisé'; END IF;
  SELECT * INTO s FROM public.journey_stages WHERE id = _stage;
  IF (_kind = 'completion_requested' AND s.status <> 'in_progress') OR (_kind = 'arrival_confirmed' AND s.status NOT IN ('in_progress', 'completed')) THEN
    RAISE EXCEPTION 'Action indisponible pour cette étape';
  END IF;
  IF EXISTS (SELECT 1 FROM public.journey_events WHERE stage_id = s.id AND event_type = _kind AND actor_id = auth.uid()) THEN
    RETURN jsonb_build_object('already', true);
  END IF;
  INSERT INTO public.journey_events (booking_request_id, stage_id, event_type, actor_id, actor_role) VALUES (b.id, s.id, _kind, auth.uid(), 'client');
  PERFORM public.notify_admins(CASE WHEN _kind = 'arrival_confirmed' THEN 'Arrivée confirmée par le client' ELSE 'Le client demande la fin de l''étape' END, b.reference || ' · étape ' || s.stage_no);
  PERFORM public.notify_user(b.owner_id, CASE WHEN _kind = 'arrival_confirmed' THEN 'Arrivée confirmée par le client' ELSE 'Le client demande la fin de l''étape' END, b.reference || ' · étape ' || s.stage_no, '/partenaire');
  RETURN jsonb_build_object('already', false);
END $$;

CREATE OR REPLACE FUNCTION public.journey_push_location(
  _booking uuid, _lat double precision, _lng double precision, _accuracy double precision DEFAULT NULL,
  _heading double precision DEFAULT NULL, _speed double precision DEFAULT NULL, _recorded_at timestamptz DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE b record; _stage uuid; l public.live_locations%ROWTYPE; _rec timestamptz := least(coalesce(_recorded_at, now()), now()); _dt double precision; _dist double precision;
BEGIN
  SELECT id, owner_id, status::text AS status INTO b FROM public.booking_requests WHERE id = _booking;
  IF NOT FOUND OR b.owner_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Non autorisé'; END IF;
  IF b.status <> 'in_progress' THEN RETURN jsonb_build_object('accepted', false, 'reason', 'not_active', 'tracking', false); END IF;
  SELECT id INTO _stage FROM public.journey_stages WHERE booking_request_id = _booking AND status = 'in_progress';
  IF _stage IS NULL THEN RETURN jsonb_build_object('accepted', false, 'reason', 'no_active_stage', 'tracking', false); END IF;
  IF NOT public.geo_valid(_lat, _lng) THEN RETURN jsonb_build_object('accepted', false, 'reason', 'invalid', 'tracking', true); END IF;
  IF _accuracy IS NOT NULL AND (_accuracy < 0 OR _accuracy > 1500) THEN RETURN jsonb_build_object('accepted', false, 'reason', 'inaccurate', 'tracking', true); END IF;
  IF _rec < now() - interval '30 minutes' THEN RETURN jsonb_build_object('accepted', false, 'reason', 'stale', 'tracking', true); END IF;
  SELECT * INTO l FROM public.live_locations WHERE booking_request_id = _booking FOR UPDATE;
  IF FOUND AND l.received_at IS NOT NULL AND l.received_at > now() - interval '2 seconds' THEN
    RETURN jsonb_build_object('accepted', false, 'reason', 'throttled', 'tracking', true);
  END IF;
  IF FOUND AND public.geo_valid(l.lat, l.lng) AND l.recorded_at IS NOT NULL AND _rec > l.recorded_at THEN
    _dt := extract(epoch FROM _rec - l.recorded_at);
    _dist := public.geo_distance_m(l.lat, l.lng, _lat, _lng);
    IF _dist > 500 + coalesce(_accuracy, 0) + coalesce(l.accuracy, 0) AND _dist / greatest(_dt, 1) > 90 THEN
      RETURN jsonb_build_object('accepted', false, 'reason', 'implausible', 'tracking', true);
    END IF;
  END IF;
  INSERT INTO public.gps_location_updates (booking_request_id, stage_id, owner_id, lat, lng, accuracy, heading, speed, recorded_at)
    VALUES (_booking, _stage, auth.uid(), _lat, _lng, _accuracy, _heading, _speed, _rec);
  INSERT INTO public.live_locations AS x (booking_request_id, stage_id, owner_id, lat, lng, accuracy, heading, speed, recorded_at, received_at, tracking, updated_at)
    VALUES (_booking, _stage, auth.uid(), _lat, _lng, _accuracy, _heading, _speed, _rec, now(), true, now())
  ON CONFLICT (booking_request_id) DO UPDATE SET stage_id = EXCLUDED.stage_id, tracking = true, updated_at = now(), received_at = now(),
    lat = CASE WHEN x.recorded_at IS NULL OR EXCLUDED.recorded_at >= x.recorded_at THEN EXCLUDED.lat ELSE x.lat END,
    lng = CASE WHEN x.recorded_at IS NULL OR EXCLUDED.recorded_at >= x.recorded_at THEN EXCLUDED.lng ELSE x.lng END,
    accuracy = CASE WHEN x.recorded_at IS NULL OR EXCLUDED.recorded_at >= x.recorded_at THEN EXCLUDED.accuracy ELSE x.accuracy END,
    heading = CASE WHEN x.recorded_at IS NULL OR EXCLUDED.recorded_at >= x.recorded_at THEN EXCLUDED.heading ELSE x.heading END,
    speed = CASE WHEN x.recorded_at IS NULL OR EXCLUDED.recorded_at >= x.recorded_at THEN EXCLUDED.speed ELSE x.speed END,
    recorded_at = greatest(x.recorded_at, EXCLUDED.recorded_at);
  RETURN jsonb_build_object('accepted', true, 'tracking', true);
END $$;

-- Audit triggers
CREATE OR REPLACE FUNCTION public.cars_audit_trigger()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND public.has_role(auth.uid(), 'admin') THEN
    IF TG_OP = 'DELETE' THEN PERFORM public.audit('car_delete', 'car', OLD.id, jsonb_build_object('name', OLD.name));
    ELSE PERFORM public.audit('car_' || lower(TG_OP), 'car', NEW.id, jsonb_build_object('name', NEW.name, 'active', NEW.active)); END IF;
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS cars_audit ON public.cars;
CREATE TRIGGER cars_audit AFTER INSERT OR UPDATE OR DELETE ON public.cars FOR EACH ROW EXECUTE FUNCTION public.cars_audit_trigger();

CREATE OR REPLACE FUNCTION public.cars_delete_guard()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.booking_requests WHERE car_id = OLD.id AND status::text IN ('approved', 'awaiting_owner', 'confirmed', 'in_progress')) THEN
    RAISE EXCEPTION 'Ce véhicule a des réservations actives : dépubliez-le plutôt que de le supprimer';
  END IF;
  RETURN OLD;
END $$;
DROP TRIGGER IF EXISTS cars_delete_guard ON public.cars;
CREATE TRIGGER cars_delete_guard BEFORE DELETE ON public.cars FOR EACH ROW EXECUTE FUNCTION public.cars_delete_guard();

-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║  STEP 4 — ROW LEVEL SECURITY                                               ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cars ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.car_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.car_videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.car_proposals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.proposal_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicle_change_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gallery ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.car_availability_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journey_stages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journey_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gps_location_updates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

-- Profiles
DROP POLICY IF EXISTS "Profiles visible by owners and admins" ON public.profiles;
CREATE POLICY "Profiles visible by owners and admins" ON public.profiles FOR SELECT USING (auth.uid() = id OR public.has_role(auth.uid(), 'admin'));
DROP POLICY IF EXISTS "Profiles editable by owners" ON public.profiles;
CREATE POLICY "Profiles editable by owners" ON public.profiles FOR ALL USING (auth.uid() = id);

-- User roles
DROP POLICY IF EXISTS "Roles readable by owners and admins" ON public.user_roles;
CREATE POLICY "Roles readable by owners and admins" ON public.user_roles FOR SELECT USING (auth.uid() = user_id OR public.has_role(auth.uid(), 'admin'));

-- Cars
DROP POLICY IF EXISTS "Cars public read active" ON public.cars;
CREATE POLICY "Cars public read active" ON public.cars FOR SELECT USING (active = true OR owner_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));
DROP POLICY IF EXISTS "Cars admin all" ON public.cars;
CREATE POLICY "Cars admin all" ON public.cars FOR ALL USING (public.has_role(auth.uid(), 'admin'));

-- Car images & videos
DROP POLICY IF EXISTS "Car media public read" ON public.car_images;
CREATE POLICY "Car media public read" ON public.car_images FOR SELECT USING (true);
DROP POLICY IF EXISTS "Car media admin all" ON public.car_images;
CREATE POLICY "Car media admin all" ON public.car_images FOR ALL USING (public.has_role(auth.uid(), 'admin'));
DROP POLICY IF EXISTS "Car videos public read" ON public.car_videos;
CREATE POLICY "Car videos public read" ON public.car_videos FOR SELECT USING (true);
DROP POLICY IF EXISTS "Car videos admin all" ON public.car_videos;
CREATE POLICY "Car videos admin all" ON public.car_videos FOR ALL USING (public.has_role(auth.uid(), 'admin'));

-- Car proposals
DROP POLICY IF EXISTS "Anyone can submit car proposals" ON public.car_proposals;
CREATE POLICY "Anyone can submit car proposals" ON public.car_proposals FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "Proposals viewable by submitter or partner or admin" ON public.car_proposals;
CREATE POLICY "Proposals viewable by submitter or partner or admin" ON public.car_proposals FOR SELECT USING (user_id = auth.uid() OR partner_user_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));
DROP POLICY IF EXISTS "Proposals admin all" ON public.car_proposals;
CREATE POLICY "Proposals admin all" ON public.car_proposals FOR ALL USING (public.has_role(auth.uid(), 'admin'));

-- Proposal images
DROP POLICY IF EXISTS "Proposal images insertable" ON public.proposal_images;
CREATE POLICY "Proposal images insertable" ON public.proposal_images FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "Proposal images select" ON public.proposal_images;
CREATE POLICY "Proposal images select" ON public.proposal_images FOR SELECT USING (public.has_role(auth.uid(), 'admin') OR EXISTS (
  SELECT 1 FROM public.car_proposals p WHERE p.id = proposal_id AND (p.user_id = auth.uid() OR p.partner_user_id = auth.uid())));

-- Booking requests
DROP POLICY IF EXISTS "Anyone can create bookings" ON public.booking_requests;
CREATE POLICY "Anyone can create bookings" ON public.booking_requests FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "Bookings viewable by client, assigned partner, or admin" ON public.booking_requests;
CREATE POLICY "Bookings viewable by client, assigned partner, or admin" ON public.booking_requests FOR SELECT USING (
  client_id = auth.uid() OR public.has_role(auth.uid(), 'admin') OR public.is_assigned_partner(id, auth.uid()));
DROP POLICY IF EXISTS "Bookings admin all" ON public.booking_requests;
CREATE POLICY "Bookings admin all" ON public.booking_requests FOR ALL USING (public.has_role(auth.uid(), 'admin'));

-- Trip assignments
DROP POLICY IF EXISTS "Trip assignments partner or admin" ON public.trip_assignments;
CREATE POLICY "Trip assignments partner or admin" ON public.trip_assignments FOR ALL USING (partner_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

-- Trip status history
DROP POLICY IF EXISTS "Trip history select" ON public.trip_status_history;
CREATE POLICY "Trip history select" ON public.trip_status_history FOR SELECT USING (
  public.has_role(auth.uid(), 'admin') OR
  EXISTS (SELECT 1 FROM public.booking_requests b WHERE b.id = booking_request_id AND b.client_id = auth.uid()) OR
  EXISTS (SELECT 1 FROM public.trip_assignments a WHERE a.booking_request_id = booking_request_id AND a.partner_id = auth.uid()));

-- Notifications
DROP POLICY IF EXISTS "Notifications viewable by target user or admin" ON public.notifications;
CREATE POLICY "Notifications viewable by target user or admin" ON public.notifications FOR SELECT USING (user_id = auth.uid() OR (audience = 'admin' AND public.has_role(auth.uid(), 'admin')));
DROP POLICY IF EXISTS "Notifications updateable by target user" ON public.notifications;
CREATE POLICY "Notifications updateable by target user" ON public.notifications FOR UPDATE USING (user_id = auth.uid());

-- Admin notes
DROP POLICY IF EXISTS "Admin notes admin only" ON public.admin_notes;
CREATE POLICY "Admin notes admin only" ON public.admin_notes FOR ALL USING (public.has_role(auth.uid(), 'admin'));

-- Vehicle change requests
DROP POLICY IF EXISTS "Change requests partner or admin" ON public.vehicle_change_requests;
CREATE POLICY "Change requests partner or admin" ON public.vehicle_change_requests FOR ALL USING (partner_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

-- Gallery
DROP POLICY IF EXISTS "Gallery public read" ON public.gallery;
CREATE POLICY "Gallery public read" ON public.gallery FOR SELECT USING (active = true OR public.has_role(auth.uid(), 'admin'));
DROP POLICY IF EXISTS "Gallery admin all" ON public.gallery;
CREATE POLICY "Gallery admin all" ON public.gallery FOR ALL USING (public.has_role(auth.uid(), 'admin'));

-- Availability rules
DROP POLICY IF EXISTS "Availability owner or admin" ON public.car_availability_rules;
CREATE POLICY "Availability owner or admin" ON public.car_availability_rules FOR ALL
  USING (public.has_role(auth.uid(), 'admin') OR EXISTS (SELECT 1 FROM public.cars c WHERE c.id = car_id AND c.owner_id = auth.uid()))
  WITH CHECK (public.has_role(auth.uid(), 'admin') OR EXISTS (SELECT 1 FROM public.cars c WHERE c.id = car_id AND c.owner_id = auth.uid()));

-- Journey stages & events
DROP POLICY IF EXISTS "Journey stages participants" ON public.journey_stages;
CREATE POLICY "Journey stages participants" ON public.journey_stages FOR SELECT USING (public.can_view_booking(booking_request_id, auth.uid()));
DROP POLICY IF EXISTS "Journey events participants" ON public.journey_events;
CREATE POLICY "Journey events participants" ON public.journey_events FOR SELECT USING (public.can_view_booking(booking_request_id, auth.uid()));

-- GPS
DROP POLICY IF EXISTS "GPS history admin or owner" ON public.gps_location_updates;
CREATE POLICY "GPS history admin or owner" ON public.gps_location_updates FOR SELECT USING (
  public.has_role(auth.uid(), 'admin') OR EXISTS (SELECT 1 FROM public.booking_requests b WHERE b.id = booking_request_id AND b.owner_id = auth.uid()));
DROP POLICY IF EXISTS "Live location authorised viewers" ON public.live_locations;
CREATE POLICY "Live location authorised viewers" ON public.live_locations FOR SELECT USING (public.can_view_live_location(booking_request_id, auth.uid()));

-- Audit
DROP POLICY IF EXISTS "Audit admin read" ON public.audit_log;
CREATE POLICY "Audit admin read" ON public.audit_log FOR SELECT USING (public.has_role(auth.uid(), 'admin'));

-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║  STEP 5 — PERMISSIONS                                                       ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝

REVOKE ALL ON FUNCTION public.has_role(uuid, app_role) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO anon, authenticated;
REVOKE ALL ON FUNCTION public.is_assigned_partner(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_assigned_partner(uuid, uuid) TO anon, authenticated;

REVOKE ALL ON public.car_availability_rules, public.journey_stages, public.journey_events,
  public.gps_location_updates, public.live_locations, public.audit_log FROM anon;
GRANT SELECT ON public.journey_stages, public.journey_events, public.gps_location_updates, public.live_locations, public.audit_log TO authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.journey_stages, public.journey_events, public.gps_location_updates, public.live_locations, public.audit_log FROM authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.car_availability_rules TO authenticated;

REVOKE ALL ON FUNCTION public.audit(text, text, uuid, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_user(uuid, text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_admins(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.transport_assert_slot(public.booking_requests, boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.cars_audit_trigger() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.cars_delete_guard() FROM PUBLIC, anon, authenticated;

DO $$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'public.assert_admin()', 'public.claim_partner_account()',
    'public.admin_approve_partner(uuid)', 'public.admin_review_partner(uuid, text, text)',
    'public.admin_set_car_validation(uuid, text)', 'public.admin_assign_trip(uuid, uuid, uuid)',
    'public.admin_set_booking_status(uuid, text, text)', 'public.admin_review_change_request(uuid, boolean)',
    'public.admin_list_clients()',
    'public.partner_respond_assignment(uuid, boolean, text)', 'public.partner_update_trip_status(uuid, text)',
    'public.partner_update_car_availability(uuid, text)', 'public.partner_add_car_photo(uuid, text)',
    'public.can_view_booking(uuid, uuid)', 'public.can_view_live_location(uuid, uuid)',
    'public.car_window_status(uuid, timestamptz, timestamptz, uuid)', 'public.car_calendar_bookings(uuid, date, date)',
    'public.transport_submit_request(jsonb)', 'public.transport_client_cancel(uuid, text)',
    'public.admin_list_owners()', 'public.admin_transport_set_status(uuid, text, text, boolean)',
    'public.admin_transport_assign(uuid, uuid, uuid)', 'public.admin_transport_set_window(uuid, timestamptz, timestamptz)',
    'public.admin_transport_log_contact(uuid, text)', 'public.owner_transport_operations()',
    'public.owner_respond_booking(uuid, boolean, text)', 'public.owner_set_availability_mode(uuid, text)',
    'public.journey_start_stage(uuid, double precision, double precision, double precision)',
    'public.journey_end_stage(uuid, double precision, double precision, double precision)',
    'public.journey_mark_stop(uuid, int, double precision, double precision)', 'public.journey_client_signal(uuid, text)',
    'public.journey_push_location(uuid, double precision, double precision, double precision, double precision, double precision, timestamptz)'
  ] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', f);
  END LOOP;
END $$;

-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║  STEP 6 — STORAGE BUCKETS                                                  ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝

INSERT INTO storage.buckets (id, name, public) VALUES ('car-images', 'car-images', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('proposal-images', 'proposal-images', false) ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "car_images_public_read" ON storage.objects;
CREATE POLICY "car_images_public_read" ON storage.objects FOR SELECT USING (bucket_id = 'car-images');
DROP POLICY IF EXISTS "car_images_partner_upload" ON storage.objects;
CREATE POLICY "car_images_partner_upload" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'car-images' AND (auth.role() = 'authenticated' OR auth.role() = 'service_role'));
DROP POLICY IF EXISTS "car_images_admin_delete" ON storage.objects;
CREATE POLICY "car_images_admin_delete" ON storage.objects FOR DELETE USING (bucket_id = 'car-images' AND public.has_role(auth.uid(), 'admin'));

DROP POLICY IF EXISTS "proposal_images_upload" ON storage.objects;
CREATE POLICY "proposal_images_upload" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'proposal-images');
DROP POLICY IF EXISTS "proposal_images_read" ON storage.objects;
CREATE POLICY "proposal_images_read" ON storage.objects FOR SELECT USING (bucket_id = 'proposal-images' AND (auth.role() = 'authenticated' OR auth.role() = 'service_role'));

-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║  STEP 7 — REALTIME                                                          ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝

DO $$
DECLARE t text;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    FOREACH t IN ARRAY ARRAY['live_locations', 'journey_stages', 'journey_events', 'booking_requests'] LOOP
      IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = t) THEN
        EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
      END IF;
    END LOOP;
  END IF;
END $$;

-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║  STEP 8 — 20 PARTNER USERS & 100 REALISTIC CARS (52 WEDDING + 48 FAMILY)     ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝

-- ==============================================================================
-- Far7tek Seed: 20 Tunisian Partner Users & 100 Cars (52 Wedding + 48 Family)
-- ==============================================================================

-- 1. PARTNER ACCOUNTS (Full GoTrue-compliant)

-- ==============================================================================
-- Fix 500 Internal Server Error on Supabase GoTrue Auth
-- Fixes NULL boolean/string columns (is_sso_user, is_anonymous, tokens) in auth.users
-- and sets up corresponding auth.identities records for email password sign-in.
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. Fix global boolean defaults in auth.users (prevents Go scan crash on NULL)
UPDATE auth.users
SET is_sso_user = false WHERE is_sso_user IS NULL;
UPDATE auth.users
SET is_anonymous = false WHERE is_anonymous IS NULL;
UPDATE auth.users
SET is_super_admin = false WHERE is_super_admin IS NULL;
UPDATE auth.users
SET confirmation_token = COALESCE(confirmation_token, ''),
    recovery_token = COALESCE(recovery_token, ''),
    email_change_token_new = COALESCE(email_change_token_new, ''),
    email_change = COALESCE(email_change, ''),
    phone_change = COALESCE(phone_change, ''),
    phone_change_token = COALESCE(phone_change_token, ''),
    email_change_token_current = COALESCE(email_change_token_current, ''),
    reauthentication_token = COALESCE(reauthentication_token, '');

-- 2. Upsert each partner user with complete GoTrue-compliant fields and identity

-- Partner: partner1@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  'ee1141f3-af04-5ad1-a0f3-658a97737453', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner1@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Mohamed', 'last_name', 'Ben Salem', 'phone', '+216 98 214 550'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Mohamed', 'last_name', 'Ben Salem', 'phone', '+216 98 214 550'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = 'ee1141f3-af04-5ad1-a0f3-658a97737453';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  'ee1141f3-af04-5ad1-a0f3-658a97737453',
  'ee1141f3-af04-5ad1-a0f3-658a97737453',
  json_build_object('sub', 'ee1141f3-af04-5ad1-a0f3-658a97737453', 'email', 'partner1@far7tek.tn')::jsonb,
  'email',
  'ee1141f3-af04-5ad1-a0f3-658a97737453',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('ee1141f3-af04-5ad1-a0f3-658a97737453', 'Mohamed', 'Ben Salem', '+216 98 214 550')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('ee1141f3-af04-5ad1-a0f3-658a97737453', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner2@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '1f33d55e-271e-57ce-b2b7-250e2a2823bd', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner2@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Youssef', 'last_name', 'Trabelsi', 'phone', '+216 22 341 890'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Youssef', 'last_name', 'Trabelsi', 'phone', '+216 22 341 890'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '1f33d55e-271e-57ce-b2b7-250e2a2823bd';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '1f33d55e-271e-57ce-b2b7-250e2a2823bd',
  '1f33d55e-271e-57ce-b2b7-250e2a2823bd',
  json_build_object('sub', '1f33d55e-271e-57ce-b2b7-250e2a2823bd', 'email', 'partner2@far7tek.tn')::jsonb,
  'email',
  '1f33d55e-271e-57ce-b2b7-250e2a2823bd',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('1f33d55e-271e-57ce-b2b7-250e2a2823bd', 'Youssef', 'Trabelsi', '+216 22 341 890')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('1f33d55e-271e-57ce-b2b7-250e2a2823bd', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner3@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '058ae746-39ca-5bf6-bdd7-6dd945132d37', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner3@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Khalil', 'last_name', 'Bouazizi', 'phone', '+216 50 678 123'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Khalil', 'last_name', 'Bouazizi', 'phone', '+216 50 678 123'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '058ae746-39ca-5bf6-bdd7-6dd945132d37';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '058ae746-39ca-5bf6-bdd7-6dd945132d37',
  '058ae746-39ca-5bf6-bdd7-6dd945132d37',
  json_build_object('sub', '058ae746-39ca-5bf6-bdd7-6dd945132d37', 'email', 'partner3@far7tek.tn')::jsonb,
  'email',
  '058ae746-39ca-5bf6-bdd7-6dd945132d37',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('058ae746-39ca-5bf6-bdd7-6dd945132d37', 'Khalil', 'Bouazizi', '+216 50 678 123')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('058ae746-39ca-5bf6-bdd7-6dd945132d37', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner4@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '31f603c0-2685-5239-b304-2e25c2f09c50', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner4@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Karim', 'last_name', 'Dridi', 'phone', '+216 97 452 310'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Karim', 'last_name', 'Dridi', 'phone', '+216 97 452 310'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '31f603c0-2685-5239-b304-2e25c2f09c50';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '31f603c0-2685-5239-b304-2e25c2f09c50',
  '31f603c0-2685-5239-b304-2e25c2f09c50',
  json_build_object('sub', '31f603c0-2685-5239-b304-2e25c2f09c50', 'email', 'partner4@far7tek.tn')::jsonb,
  'email',
  '31f603c0-2685-5239-b304-2e25c2f09c50',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('31f603c0-2685-5239-b304-2e25c2f09c50', 'Karim', 'Dridi', '+216 97 452 310')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('31f603c0-2685-5239-b304-2e25c2f09c50', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner5@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  'd6f066a7-ce2d-57e1-b422-16ce0a1311fc', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner5@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Anis', 'last_name', 'Gharbi', 'phone', '+216 29 118 765'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Anis', 'last_name', 'Gharbi', 'phone', '+216 29 118 765'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = 'd6f066a7-ce2d-57e1-b422-16ce0a1311fc';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  'd6f066a7-ce2d-57e1-b422-16ce0a1311fc',
  'd6f066a7-ce2d-57e1-b422-16ce0a1311fc',
  json_build_object('sub', 'd6f066a7-ce2d-57e1-b422-16ce0a1311fc', 'email', 'partner5@far7tek.tn')::jsonb,
  'email',
  'd6f066a7-ce2d-57e1-b422-16ce0a1311fc',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('d6f066a7-ce2d-57e1-b422-16ce0a1311fc', 'Anis', 'Gharbi', '+216 29 118 765')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('d6f066a7-ce2d-57e1-b422-16ce0a1311fc', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner6@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '2ac6af30-1c87-52fe-a2c1-d460fd518503', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner6@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Sami', 'last_name', 'Mansour', 'phone', '+216 55 902 431'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Sami', 'last_name', 'Mansour', 'phone', '+216 55 902 431'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '2ac6af30-1c87-52fe-a2c1-d460fd518503';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '2ac6af30-1c87-52fe-a2c1-d460fd518503',
  '2ac6af30-1c87-52fe-a2c1-d460fd518503',
  json_build_object('sub', '2ac6af30-1c87-52fe-a2c1-d460fd518503', 'email', 'partner6@far7tek.tn')::jsonb,
  'email',
  '2ac6af30-1c87-52fe-a2c1-d460fd518503',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('2ac6af30-1c87-52fe-a2c1-d460fd518503', 'Sami', 'Mansour', '+216 55 902 431')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('2ac6af30-1c87-52fe-a2c1-d460fd518503', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner7@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '25c6d25e-8789-551c-8451-4414d67f9ca1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner7@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Mehdi', 'last_name', 'Chaabane', 'phone', '+216 26 734 119'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Mehdi', 'last_name', 'Chaabane', 'phone', '+216 26 734 119'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '25c6d25e-8789-551c-8451-4414d67f9ca1';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '25c6d25e-8789-551c-8451-4414d67f9ca1',
  '25c6d25e-8789-551c-8451-4414d67f9ca1',
  json_build_object('sub', '25c6d25e-8789-551c-8451-4414d67f9ca1', 'email', 'partner7@far7tek.tn')::jsonb,
  'email',
  '25c6d25e-8789-551c-8451-4414d67f9ca1',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('25c6d25e-8789-551c-8451-4414d67f9ca1', 'Mehdi', 'Chaabane', '+216 26 734 119')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('25c6d25e-8789-551c-8451-4414d67f9ca1', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner8@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '6476e667-9318-55ea-a06f-1eafc54461a7', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner8@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Skander', 'last_name', 'Khemir', 'phone', '+216 92 884 201'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Skander', 'last_name', 'Khemir', 'phone', '+216 92 884 201'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '6476e667-9318-55ea-a06f-1eafc54461a7';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '6476e667-9318-55ea-a06f-1eafc54461a7',
  '6476e667-9318-55ea-a06f-1eafc54461a7',
  json_build_object('sub', '6476e667-9318-55ea-a06f-1eafc54461a7', 'email', 'partner8@far7tek.tn')::jsonb,
  'email',
  '6476e667-9318-55ea-a06f-1eafc54461a7',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('6476e667-9318-55ea-a06f-1eafc54461a7', 'Skander', 'Khemir', '+216 92 884 201')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('6476e667-9318-55ea-a06f-1eafc54461a7', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner9@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '23338aeb-00c2-526f-bf21-a6fb3c662d7f', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner9@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Zied', 'last_name', 'Jaziri', 'phone', '+216 58 120 944'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Zied', 'last_name', 'Jaziri', 'phone', '+216 58 120 944'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '23338aeb-00c2-526f-bf21-a6fb3c662d7f';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '23338aeb-00c2-526f-bf21-a6fb3c662d7f',
  '23338aeb-00c2-526f-bf21-a6fb3c662d7f',
  json_build_object('sub', '23338aeb-00c2-526f-bf21-a6fb3c662d7f', 'email', 'partner9@far7tek.tn')::jsonb,
  'email',
  '23338aeb-00c2-526f-bf21-a6fb3c662d7f',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('23338aeb-00c2-526f-bf21-a6fb3c662d7f', 'Zied', 'Jaziri', '+216 58 120 944')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('23338aeb-00c2-526f-bf21-a6fb3c662d7f', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner10@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  'cb53d47b-d24f-52d2-bcf8-362ba68cf90b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner10@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Walid', 'last_name', 'Ayari', 'phone', '+216 24 665 302'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Walid', 'last_name', 'Ayari', 'phone', '+216 24 665 302'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = 'cb53d47b-d24f-52d2-bcf8-362ba68cf90b';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  'cb53d47b-d24f-52d2-bcf8-362ba68cf90b',
  'cb53d47b-d24f-52d2-bcf8-362ba68cf90b',
  json_build_object('sub', 'cb53d47b-d24f-52d2-bcf8-362ba68cf90b', 'email', 'partner10@far7tek.tn')::jsonb,
  'email',
  'cb53d47b-d24f-52d2-bcf8-362ba68cf90b',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('cb53d47b-d24f-52d2-bcf8-362ba68cf90b', 'Walid', 'Ayari', '+216 24 665 302')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('cb53d47b-d24f-52d2-bcf8-362ba68cf90b', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner11@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '6eccbdad-f7ee-54c2-96b4-ef7a8ac008c6', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner11@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Marwen', 'last_name', 'Ben Amor', 'phone', '+216 99 378 190'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Marwen', 'last_name', 'Ben Amor', 'phone', '+216 99 378 190'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '6eccbdad-f7ee-54c2-96b4-ef7a8ac008c6';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '6eccbdad-f7ee-54c2-96b4-ef7a8ac008c6',
  '6eccbdad-f7ee-54c2-96b4-ef7a8ac008c6',
  json_build_object('sub', '6eccbdad-f7ee-54c2-96b4-ef7a8ac008c6', 'email', 'partner11@far7tek.tn')::jsonb,
  'email',
  '6eccbdad-f7ee-54c2-96b4-ef7a8ac008c6',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('6eccbdad-f7ee-54c2-96b4-ef7a8ac008c6', 'Marwen', 'Ben Amor', '+216 99 378 190')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('6eccbdad-f7ee-54c2-96b4-ef7a8ac008c6', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner12@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '35fa36c8-c32f-511a-9db3-2f140515ff84', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner12@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Omar', 'last_name', 'Riahi', 'phone', '+216 53 410 822'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Omar', 'last_name', 'Riahi', 'phone', '+216 53 410 822'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '35fa36c8-c32f-511a-9db3-2f140515ff84';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '35fa36c8-c32f-511a-9db3-2f140515ff84',
  '35fa36c8-c32f-511a-9db3-2f140515ff84',
  json_build_object('sub', '35fa36c8-c32f-511a-9db3-2f140515ff84', 'email', 'partner12@far7tek.tn')::jsonb,
  'email',
  '35fa36c8-c32f-511a-9db3-2f140515ff84',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('35fa36c8-c32f-511a-9db3-2f140515ff84', 'Omar', 'Riahi', '+216 53 410 822')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('35fa36c8-c32f-511a-9db3-2f140515ff84', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner13@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '69eff6ee-12e1-501f-9f55-9f30fc2205ea', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner13@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Hamza', 'last_name', 'Belhadj', 'phone', '+216 28 554 901'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Hamza', 'last_name', 'Belhadj', 'phone', '+216 28 554 901'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '69eff6ee-12e1-501f-9f55-9f30fc2205ea';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '69eff6ee-12e1-501f-9f55-9f30fc2205ea',
  '69eff6ee-12e1-501f-9f55-9f30fc2205ea',
  json_build_object('sub', '69eff6ee-12e1-501f-9f55-9f30fc2205ea', 'email', 'partner13@far7tek.tn')::jsonb,
  'email',
  '69eff6ee-12e1-501f-9f55-9f30fc2205ea',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('69eff6ee-12e1-501f-9f55-9f30fc2205ea', 'Hamza', 'Belhadj', '+216 28 554 901')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('69eff6ee-12e1-501f-9f55-9f30fc2205ea', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner14@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '61a078eb-0f69-5d97-9fff-4b4bd5ccfcfc', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner14@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Tarak', 'last_name', 'Zaier', 'phone', '+216 94 231 778'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Tarak', 'last_name', 'Zaier', 'phone', '+216 94 231 778'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '61a078eb-0f69-5d97-9fff-4b4bd5ccfcfc';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '61a078eb-0f69-5d97-9fff-4b4bd5ccfcfc',
  '61a078eb-0f69-5d97-9fff-4b4bd5ccfcfc',
  json_build_object('sub', '61a078eb-0f69-5d97-9fff-4b4bd5ccfcfc', 'email', 'partner14@far7tek.tn')::jsonb,
  'email',
  '61a078eb-0f69-5d97-9fff-4b4bd5ccfcfc',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('61a078eb-0f69-5d97-9fff-4b4bd5ccfcfc', 'Tarak', 'Zaier', '+216 94 231 778')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('61a078eb-0f69-5d97-9fff-4b4bd5ccfcfc', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner15@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  'e4ae4dd2-e903-5513-97ae-407c83c67742', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner15@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Firas', 'last_name', 'Chebbi', 'phone', '+216 51 890 345'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Firas', 'last_name', 'Chebbi', 'phone', '+216 51 890 345'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = 'e4ae4dd2-e903-5513-97ae-407c83c67742';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  'e4ae4dd2-e903-5513-97ae-407c83c67742',
  'e4ae4dd2-e903-5513-97ae-407c83c67742',
  json_build_object('sub', 'e4ae4dd2-e903-5513-97ae-407c83c67742', 'email', 'partner15@far7tek.tn')::jsonb,
  'email',
  'e4ae4dd2-e903-5513-97ae-407c83c67742',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('e4ae4dd2-e903-5513-97ae-407c83c67742', 'Firas', 'Chebbi', '+216 51 890 345')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('e4ae4dd2-e903-5513-97ae-407c83c67742', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner16@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '751c7cb9-930f-5032-a391-66b5c29f355d', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner16@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Nizar', 'last_name', 'Louati', 'phone', '+216 20 443 612'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Nizar', 'last_name', 'Louati', 'phone', '+216 20 443 612'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '751c7cb9-930f-5032-a391-66b5c29f355d';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '751c7cb9-930f-5032-a391-66b5c29f355d',
  '751c7cb9-930f-5032-a391-66b5c29f355d',
  json_build_object('sub', '751c7cb9-930f-5032-a391-66b5c29f355d', 'email', 'partner16@far7tek.tn')::jsonb,
  'email',
  '751c7cb9-930f-5032-a391-66b5c29f355d',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('751c7cb9-930f-5032-a391-66b5c29f355d', 'Nizar', 'Louati', '+216 20 443 612')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('751c7cb9-930f-5032-a391-66b5c29f355d', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner17@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  'fd9cf00c-7bab-59b6-a072-0a287fbefc6f', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner17@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Bilel', 'last_name', 'Messaoudi', 'phone', '+216 96 112 559'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Bilel', 'last_name', 'Messaoudi', 'phone', '+216 96 112 559'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = 'fd9cf00c-7bab-59b6-a072-0a287fbefc6f';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  'fd9cf00c-7bab-59b6-a072-0a287fbefc6f',
  'fd9cf00c-7bab-59b6-a072-0a287fbefc6f',
  json_build_object('sub', 'fd9cf00c-7bab-59b6-a072-0a287fbefc6f', 'email', 'partner17@far7tek.tn')::jsonb,
  'email',
  'fd9cf00c-7bab-59b6-a072-0a287fbefc6f',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('fd9cf00c-7bab-59b6-a072-0a287fbefc6f', 'Bilel', 'Messaoudi', '+216 96 112 559')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('fd9cf00c-7bab-59b6-a072-0a287fbefc6f', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner18@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '77d05462-ef43-5442-9b25-76e8c97851a9', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner18@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Wissem', 'last_name', 'Ben Fredj', 'phone', '+216 54 789 203'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Wissem', 'last_name', 'Ben Fredj', 'phone', '+216 54 789 203'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '77d05462-ef43-5442-9b25-76e8c97851a9';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '77d05462-ef43-5442-9b25-76e8c97851a9',
  '77d05462-ef43-5442-9b25-76e8c97851a9',
  json_build_object('sub', '77d05462-ef43-5442-9b25-76e8c97851a9', 'email', 'partner18@far7tek.tn')::jsonb,
  'email',
  '77d05462-ef43-5442-9b25-76e8c97851a9',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('77d05462-ef43-5442-9b25-76e8c97851a9', 'Wissem', 'Ben Fredj', '+216 54 789 203')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('77d05462-ef43-5442-9b25-76e8c97851a9', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner19@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  'aa941779-ac29-5f31-8d63-0ba467008ed2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner19@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Hichem', 'last_name', 'Guesmi', 'phone', '+216 27 605 114'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Hichem', 'last_name', 'Guesmi', 'phone', '+216 27 605 114'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = 'aa941779-ac29-5f31-8d63-0ba467008ed2';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  'aa941779-ac29-5f31-8d63-0ba467008ed2',
  'aa941779-ac29-5f31-8d63-0ba467008ed2',
  json_build_object('sub', 'aa941779-ac29-5f31-8d63-0ba467008ed2', 'email', 'partner19@far7tek.tn')::jsonb,
  'email',
  'aa941779-ac29-5f31-8d63-0ba467008ed2',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('aa941779-ac29-5f31-8d63-0ba467008ed2', 'Hichem', 'Guesmi', '+216 27 605 114')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('aa941779-ac29-5f31-8d63-0ba467008ed2', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner20@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '542bdad5-7c8c-5023-9594-98af51cc730c', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner20@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Riadh', 'last_name', 'Sassi', 'phone', '+216 95 332 890'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Riadh', 'last_name', 'Sassi', 'phone', '+216 95 332 890'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '542bdad5-7c8c-5023-9594-98af51cc730c';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '542bdad5-7c8c-5023-9594-98af51cc730c',
  '542bdad5-7c8c-5023-9594-98af51cc730c',
  json_build_object('sub', '542bdad5-7c8c-5023-9594-98af51cc730c', 'email', 'partner20@far7tek.tn')::jsonb,
  'email',
  '542bdad5-7c8c-5023-9594-98af51cc730c',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('542bdad5-7c8c-5023-9594-98af51cc730c', 'Riadh', 'Sassi', '+216 95 332 890')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('542bdad5-7c8c-5023-9594-98af51cc730c', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;


-- Also ensure superadmin gets admin role if already exists
DO $$
DECLARE _adm uuid;
BEGIN
  SELECT id INTO _adm FROM auth.users WHERE email = 'superadmin@autoecole.tn';
  IF _adm IS NOT NULL THEN
    INSERT INTO public.user_roles (user_id, role) VALUES (_adm, 'admin') ON CONFLICT DO NOTHING;
  END IF;
END $$;


-- 2. 100 CARS & CAR IMAGES

INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '5f53f226-ef7b-570a-9142-81d634bef8c9', 'Rolls-Royce Ghost', 'Rolls-Royce', 'Ghost',
  'rolls-royce-ghost-1', 2022, 'Blanc', 'Berline de prestige',
  'Élégance royale et raffinement absolu pour une arrivée des mariés mémorable avec chauffeur en tenue.', 'Élégance royale et raffinement absolu pour une arrivée des mariés mémorable avec chauffeur en tenue.',
  1800.00, 'Disponible 7j/7', true, true, 1, 'ee1141f3-af04-5ad1-a0f3-658a97737453', 'active',
  4, 'Tunis', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver', 'water']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '9990415f-2c52-5836-b224-8a4f64d14fff', '5f53f226-ef7b-570a-9142-81d634bef8c9', 'https://images.unsplash.com/photo-1631295868223-63265b40d9e4?auto=format&fit=crop&w=1200&q=80', 'Rolls-Royce Ghost', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '28feb2d6-5592-5557-8642-97bcb73aebcd', 'Rolls-Royce Phantom VIII', 'Rolls-Royce', 'Phantom VIII',
  'rolls-royce-phantom-viii-2', 2023, 'Noir', 'Berline de prestige',
  'Le summum du luxe automobile mondial. Prestation haute couture pour votre mariage.', 'Le summum du luxe automobile mondial. Prestation haute couture pour votre mariage.',
  2400.00, 'Disponible 7j/7', true, true, 2, '1f33d55e-271e-57ce-b2b7-250e2a2823bd', 'active',
  4, 'Sousse', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'uniformed_driver', 'water', 'wifi']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '036eb205-c917-5ca7-a7a4-0f19e257f869', '28feb2d6-5592-5557-8642-97bcb73aebcd', 'https://images.unsplash.com/photo-1563720223185-11003d516935?auto=format&fit=crop&w=1200&q=80', 'Rolls-Royce Phantom VIII', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'c5cf7fe2-3781-53bf-be42-af7f78add149', 'Rolls-Royce Dawn Cabriolet', 'Rolls-Royce', 'Dawn',
  'rolls-royce-dawn-3', 2021, 'Ivoire', 'Cabriolet',
  'Cabriolet de prestige idéal pour des séances photo d''exception et un cortège à ciel ouvert.', 'Cabriolet de prestige idéal pour des séances photo d''exception et un cortège à ciel ouvert.',
  2200.00, 'Disponible 7j/7', true, true, 3, '058ae746-39ca-5bf6-bdd7-6dd945132d37', 'active',
  4, 'Sfax', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'convertible_roof', 'uniformed_driver', 'water']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '65f32f7a-c155-5484-867d-1bcc9410727e', 'c5cf7fe2-3781-53bf-be42-af7f78add149', 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?auto=format&fit=crop&w=1200&q=80', 'Rolls-Royce Dawn Cabriolet', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'f80690cd-365c-5ecc-a5b9-6516e364e464', 'Rolls-Royce Cullinan', 'Rolls-Royce', 'Cullinan',
  'rolls-royce-cullinan-4', 2023, 'Blanc', 'SUV',
  'Le SUV le plus luxueux au monde, prestance incomparable pour le cortège nuptial.', 'Le SUV le plus luxueux au monde, prestance incomparable pour le cortège nuptial.',
  2500.00, 'Disponible 7j/7', true, true, 4, '31f603c0-2685-5239-b304-2e25c2f09c50', 'active',
  4, 'Monastir', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver', 'wifi', 'water']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '87fef1e6-2061-5d77-9025-1d0b5de66e31', 'f80690cd-365c-5ecc-a5b9-6516e364e464', 'https://images.unsplash.com/photo-1617788138017-80ad40651399?auto=format&fit=crop&w=1200&q=80', 'Rolls-Royce Cullinan', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '2cd1d676-f101-5df7-b28f-fae219af4d29', 'Mercedes-Maybach S680 V12', 'Mercedes-Maybach', 'S680',
  'mercedes-maybach-s680-5', 2023, 'Noir', 'Berline de prestige',
  'Sièges massants inclinables, insonorisation parfaite et décoration florale offerte.', 'Sièges massants inclinables, insonorisation parfaite et décoration florale offerte.',
  1400.00, 'Disponible 7j/7', true, true, 5, 'd6f066a7-ce2d-57e1-b422-16ce0a1311fc', 'active',
  4, 'Nabeul', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver', 'water']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '8103461a-28c4-5581-b752-d20319820816', '2cd1d676-f101-5df7-b28f-fae219af4d29', 'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Maybach S680 V12', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'd0084c09-5eea-5e45-8bfd-e465f97d67f0', 'Mercedes-Maybach S580', 'Mercedes-Maybach', 'S580',
  'mercedes-maybach-s580-6', 2022, 'Champagne', 'Berline de prestige',
  'Harmonie parfaite de blanc nacré et champagne avec finitions en bois précieux.', 'Harmonie parfaite de blanc nacré et champagne avec finitions en bois précieux.',
  1250.00, 'Disponible 7j/7', true, true, 6, '2ac6af30-1c87-52fe-a2c1-d460fd518503', 'active',
  4, 'Hammamet', ARRAY['wedding', 'event'], 'automatic', 'hybrid', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver', 'water']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '0e85f466-ddf9-553d-9454-72c058d6650d', 'd0084c09-5eea-5e45-8bfd-e465f97d67f0', 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Maybach S580', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'dedbbf0a-107e-55e5-b5f9-3150779d4ad1', 'Mercedes-Benz Classe S 500 W223', 'Mercedes-Benz', 'Classe S 500',
  'mercedes-benz-classe-s-500-7', 2023, 'Blanc', 'Berline de prestige',
  'Dernière génération de Classe S avec éclairage d''ambiance 64 couleurs et sonorisation Burmester.', 'Dernière génération de Classe S avec éclairage d''ambiance 64 couleurs et sonorisation Burmester.',
  950.00, 'Disponible 7j/7', true, true, 7, '25c6d25e-8789-551c-8451-4414d67f9ca1', 'active',
  4, 'Bizerte', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'c584946d-f788-5ae6-983e-c03114ecaa21', 'dedbbf0a-107e-55e5-b5f9-3150779d4ad1', 'https://images.unsplash.com/photo-1622353219448-656a4220b22a?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz Classe S 500 W223', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '5b35ab6b-24af-5fb6-bfda-54436fd689ce', 'Mercedes-Benz Classe S 400d AMG', 'Mercedes-Benz', 'Classe S 400d',
  'mercedes-benz-classe-s-400d-8', 2022, 'Noir', 'Berline de prestige',
  'Pack AMG complet, vitres teintées et confort princier pour les mariés.', 'Pack AMG complet, vitres teintées et confort princier pour les mariés.',
  850.00, 'Disponible 7j/7', true, true, 8, '6476e667-9318-55ea-a06f-1eafc54461a7', 'active',
  4, 'Tunis', ARRAY['wedding', 'event'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '8e18a722-5579-52cc-be0e-cea4f5ce19ee', '5b35ab6b-24af-5fb6-bfda-54436fd689ce', 'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz Classe S 400d AMG', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '48048715-5957-5824-9926-32021ad31cc7', 'Mercedes-Benz Classe S 350d W222', 'Mercedes-Benz', 'Classe S 350d',
  'mercedes-benz-classe-s-350d-9', 2020, 'Argent', 'Berline de prestige',
  'Élégance intemporelle de la W222, très appréciée pour les cortèges de mariage en Tunisie.', 'Élégance intemporelle de la W222, très appréciée pour les cortèges de mariage en Tunisie.',
  700.00, 'Disponible 7j/7', true, true, 9, '23338aeb-00c2-526f-bf21-a6fb3c662d7f', 'active',
  4, 'Sousse', ARRAY['wedding', 'event'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '6a8b157f-5c80-5b6a-a023-dbec12daed74', '48048715-5957-5824-9926-32021ad31cc7', 'https://images.unsplash.com/photo-1622353219448-656a4220b22a?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz Classe S 350d W222', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '7934420b-becc-58b0-8ee3-52dc84915889', 'Mercedes-Benz Classe E 300 AMG Line W214', 'Mercedes-Benz', 'Classe E 300',
  'mercedes-benz-classe-e-300-10', 2024, 'Blanc', 'Berline de prestige',
  'Toute nouvelle Classe E 2024, technologie Superscreen et design ultra moderne.', 'Toute nouvelle Classe E 2024, technologie Superscreen et design ultra moderne.',
  650.00, 'Disponible 7j/7', true, true, 10, 'cb53d47b-d24f-52d2-bcf8-362ba68cf90b', 'active',
  4, 'Ariana', ARRAY['wedding', 'event'], 'automatic', 'hybrid', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'ea52a76a-e56f-5fdf-a74f-f72b568bd9da', '7934420b-becc-58b0-8ee3-52dc84915889', 'https://images.unsplash.com/photo-1606016159991-dfe4f2746ad5?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz Classe E 300 AMG Line W214', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '72796b04-8e5f-5ccb-991e-408217c8e710', 'Mercedes-Benz Classe E 220d Pack Nuit', 'Mercedes-Benz', 'Classe E 220d',
  'mercedes-benz-classe-e-220d-11', 2022, 'Gris', 'Berline de prestige',
  'Allure sportive et élégante, parfaite pour un cortège jeune et branché.', 'Allure sportive et élégante, parfaite pour un cortège jeune et branché.',
  550.00, 'Disponible 7j/7', true, true, 11, '6eccbdad-f7ee-54c2-96b4-ef7a8ac008c6', 'active',
  4, 'Ben Arous', ARRAY['wedding', 'event'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '89747e0f-a67c-5cab-a99a-b2ed117ba259', '72796b04-8e5f-5ccb-991e-408217c8e710', 'https://images.unsplash.com/photo-1606016159991-dfe4f2746ad5?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz Classe E 220d Pack Nuit', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '2552a85d-0752-503a-9f83-ae473c045e40', 'Mercedes-Benz CLE Coupé 300 AMG', 'Mercedes-Benz', 'CLE Coupé 300',
  'mercedes-benz-cle-coup-300-12', 2024, 'Blanc', 'Cabriolet',
  'Ligne de coupé racée pour une arrivée remarquée devant la mairie et la salle des fêtes.', 'Ligne de coupé racée pour une arrivée remarquée devant la mairie et la salle des fêtes.',
  750.00, 'Disponible 7j/7', true, true, 12, '35fa36c8-c32f-511a-9db3-2f140515ff84', 'active',
  4, 'La Marsa', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'fedbfa39-c4fa-580a-99f3-903d66bc1d73', '2552a85d-0752-503a-9f83-ae473c045e40', 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz CLE Coupé 300 AMG', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '795607ec-8278-53a7-9e9c-fb23cd0f5b34', 'Mercedes-Benz CLS 400d AMG', 'Mercedes-Benz', 'CLS 400d',
  'mercedes-benz-cls-400d-13', 2021, 'Noir', 'Berline de prestige',
  'Berline coupé 4 portes au style sculptural et à l''habitacle raffiné.', 'Berline coupé 4 portes au style sculptural et à l''habitacle raffiné.',
  680.00, 'Disponible 7j/7', true, false, 13, '69eff6ee-12e1-501f-9f55-9f30fc2205ea', 'active',
  4, 'Djerba', ARRAY['wedding', 'event'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '8b1f6fc2-bebe-5a43-87bd-79bcabeb12c1', '795607ec-8278-53a7-9e9c-fb23cd0f5b34', 'https://images.unsplash.com/photo-1617814076367-b759c7d7e738?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz CLS 400d AMG', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '2bb49ec3-40cd-5c2f-abb0-0ca5684c1c8d', 'Mercedes-Benz CLA 200 AMG Line', 'Mercedes-Benz', 'CLA 200',
  'mercedes-benz-cla-200-14', 2023, 'Blanc', 'Berline de prestige',
  'Voiture des mariés très demandée en Tunisie pour son style dynamique et son rapport qualité-prix.', 'Voiture des mariés très demandée en Tunisie pour son style dynamique et son rapport qualité-prix.',
  480.00, 'Disponible 7j/7', true, false, 14, '61a078eb-0f69-5d97-9fff-4b4bd5ccfcfc', 'active',
  4, 'Sfax', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'f4357138-e009-52cd-9fed-b2c1a3dfd7f2', '2bb49ec3-40cd-5c2f-abb0-0ca5684c1c8d', 'https://images.unsplash.com/photo-1580273916550-e323be2ae537?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz CLA 200 AMG Line', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '87a28830-bdfa-58f3-9abf-a18f0a446556', 'Mercedes-AMG G63 V8 Biturbo', 'Mercedes-Benz', 'G63 AMG',
  'mercedes-benz-g63-amg-15', 2022, 'Noir', 'SUV',
  'Prestance colossale, sonorité envoûtante du V8 AMG pour ouvrir le cortège nuptial.', 'Prestance colossale, sonorité envoûtante du V8 AMG pour ouvrir le cortège nuptial.',
  1300.00, 'Disponible 7j/7', true, false, 15, 'e4ae4dd2-e903-5513-97ae-407c83c67742', 'active',
  4, 'Mahdia', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver', 'bluetooth_audio']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '35b1f569-b050-5cb4-898f-ae2230aa0566', '87a28830-bdfa-58f3-9abf-a18f0a446556', 'https://images.unsplash.com/photo-1520031441872-265e4ff70366?auto=format&fit=crop&w=1200&q=80', 'Mercedes-AMG G63 V8 Biturbo', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'cbd10172-427f-56e6-9c8e-73e83e5ca693', 'Mercedes-Benz GLE 350de Coupé AMG', 'Mercedes-Benz', 'GLE 350de Coupé',
  'mercedes-benz-gle-350de-coup-16', 2023, 'Blanc', 'SUV',
  'SUV Coupé premium alliant modernité, grand confort et allure athlétique.', 'SUV Coupé premium alliant modernité, grand confort et allure athlétique.',
  750.00, 'Disponible 7j/7', true, false, 16, '751c7cb9-930f-5032-a391-66b5c29f355d', 'active',
  4, 'Sousse', ARRAY['wedding', 'event'], 'automatic', 'hybrid', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'ef417091-5c35-5bde-a527-9d4751273d4c', 'cbd10172-427f-56e6-9c8e-73e83e5ca693', 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz GLE 350de Coupé AMG', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'fba28cae-19b7-584f-9028-22e1ccc54f49', 'Porsche Panamera 4S', 'Porsche', 'Panamera 4S',
  'porsche-panamera-4s-17', 2022, 'Blanc', 'Berline de prestige',
  'Performance et prestance allemande pour une entrée triomphale des mariés.', 'Performance et prestance allemande pour une entrée triomphale des mariés.',
  1100.00, 'Disponible 7j/7', true, false, 17, 'fd9cf00c-7bab-59b6-a072-0a287fbefc6f', 'active',
  4, 'Kairouan', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '76879a3f-6a00-5fa8-bd88-3721f13a8763', 'fba28cae-19b7-584f-9028-22e1ccc54f49', 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=1200&q=80', 'Porsche Panamera 4S', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '9693c638-dc16-5673-9ccb-2b620938030a', 'Porsche Panamera GTS', 'Porsche', 'Panamera GTS',
  'porsche-panamera-gts-18', 2021, 'Noir', 'Berline de prestige',
  'Version GTS avec échappement sport et intérieur Alcantara/cuir noir surpiqué.', 'Version GTS avec échappement sport et intérieur Alcantara/cuir noir surpiqué.',
  1200.00, 'Disponible 7j/7', true, false, 18, '77d05462-ef43-5442-9b25-76e8c97851a9', 'active',
  4, 'Monastir', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '0bd3e00e-ec2a-5097-9c46-064c9b22b30e', '9693c638-dc16-5673-9ccb-2b620938030a', 'https://images.unsplash.com/photo-1580273916550-e323be2ae537?auto=format&fit=crop&w=1200&q=80', 'Porsche Panamera GTS', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'a2bdc4e4-118c-55e2-8b1f-2f478937bd13', 'Porsche Macan GTS', 'Porsche', 'Macan GTS',
  'porsche-macan-gts-19', 2023, 'Blanc', 'SUV',
  'SUV compact prestigieux parfait pour les séances photos à Sidi Bou Saïd ou La Marsa.', 'SUV compact prestigieux parfait pour les séances photos à Sidi Bou Saïd ou La Marsa.',
  700.00, 'Disponible 7j/7', true, false, 19, 'aa941779-ac29-5f31-8d63-0ba467008ed2', 'active',
  4, 'Tunis', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'ff00da58-eabf-5893-9c61-8ee82c7f254a', 'a2bdc4e4-118c-55e2-8b1f-2f478937bd13', 'https://images.unsplash.com/photo-1614162692292-7ac56d7f7f1e?auto=format&fit=crop&w=1200&q=80', 'Porsche Macan GTS', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'a48bbcf4-5574-5c31-9f34-7f2c65aaadb0', 'Porsche Cayenne Coupé Platinum', 'Porsche', 'Cayenne Coupé',
  'porsche-cayenne-coup-20', 2023, 'Gris', 'SUV',
  'Design musclé et finitions Platinum Edition pour sublimer votre journée.', 'Design musclé et finitions Platinum Edition pour sublimer votre journée.',
  850.00, 'Disponible 7j/7', true, false, 20, '542bdad5-7c8c-5023-9594-98af51cc730c', 'active',
  4, 'Gammarth', ARRAY['wedding', 'event'], 'automatic', 'hybrid', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'a335d4d0-6825-587e-a84e-7a9e41bd76bb', 'a48bbcf4-5574-5c31-9f34-7f2c65aaadb0', 'https://images.unsplash.com/photo-1502877338535-766e1452684a?auto=format&fit=crop&w=1200&q=80', 'Porsche Cayenne Coupé Platinum', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '611eced2-9165-57b0-bf05-96e3206b541b', 'Porsche Taycan 4S', 'Porsche', 'Taycan 4S',
  'porsche-taycan-4s-21', 2022, 'Bleu', 'Berline de prestige',
  'Berline 100% électrique avant-gardiste au silence feutré pour les mariés.', 'Berline 100% électrique avant-gardiste au silence feutré pour les mariés.',
  900.00, 'Disponible 7j/7', true, false, 21, 'ee1141f3-af04-5ad1-a0f3-658a97737453', 'active',
  4, 'Tunis', ARRAY['wedding', 'event'], 'automatic', 'electric', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'e67fef77-1a5c-5076-aa15-5dda4595985a', '611eced2-9165-57b0-bf05-96e3206b541b', 'https://images.unsplash.com/photo-1617788138017-80ad40651399?auto=format&fit=crop&w=1200&q=80', 'Porsche Taycan 4S', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'a7302eac-516a-557b-83a5-cc8156c87f5d', 'BMW Série 7 740i G70', 'BMW', 'Série 7 740i',
  'bmw-s-rie-7-740i-22', 2023, 'Noir', 'Berline de prestige',
  'La nouvelle Série 7 avec écran cinéma 31 pouces arrière et calandre Iconic Glow.', 'La nouvelle Série 7 avec écran cinéma 31 pouces arrière et calandre Iconic Glow.',
  1150.00, 'Disponible 7j/7', true, false, 22, '1f33d55e-271e-57ce-b2b7-250e2a2823bd', 'active',
  4, 'Sousse', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver', 'wifi']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '3bccfaba-6230-533b-93a4-304839174621', 'a7302eac-516a-557b-83a5-cc8156c87f5d', 'https://images.unsplash.com/photo-1555215695-3004980ad54e?auto=format&fit=crop&w=1200&q=80', 'BMW Série 7 740i G70', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '74a14c23-90fb-5025-8dac-e7df4d180359', 'BMW Série 7 730d M Sport G11', 'BMW', 'Série 7 730d',
  'bmw-s-rie-7-730d-23', 2021, 'Blanc', 'Berline de prestige',
  'Confort princier et allure M Sport plébiscitée pour les mariages tunisiens.', 'Confort princier et allure M Sport plébiscitée pour les mariages tunisiens.',
  800.00, 'Disponible 7j/7', true, false, 23, '058ae746-39ca-5bf6-bdd7-6dd945132d37', 'active',
  4, 'Sfax', ARRAY['wedding', 'event'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '85ab88b8-0653-5ccb-81d5-cb7076bcadb1', '74a14c23-90fb-5025-8dac-e7df4d180359', 'https://images.unsplash.com/photo-1555215695-3004980ad54e?auto=format&fit=crop&w=1200&q=80', 'BMW Série 7 730d M Sport G11', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '91816af6-ee3a-5683-ab81-58425e8fe506', 'BMW Série 5 530i M Sport G30', 'BMW', 'Série 5 530i',
  'bmw-s-rie-5-530i-24', 2022, 'Blanc', 'Berline de prestige',
  'Berline d''affaires par excellence, très demandée pour les cortèges.', 'Berline d''affaires par excellence, très demandée pour les cortèges.',
  600.00, 'Disponible 7j/7', true, false, 24, '31f603c0-2685-5239-b304-2e25c2f09c50', 'active',
  4, 'Monastir', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'ec94ef43-0a75-5125-9b5f-2553054ed069', '91816af6-ee3a-5683-ab81-58425e8fe506', 'https://images.unsplash.com/photo-1523983388277-336a66bf9bcd?auto=format&fit=crop&w=1200&q=80', 'BMW Série 5 530i M Sport G30', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'b2ab4d44-0095-556f-8057-965ef86616f9', 'BMW Série 4 Gran Coupé 420i', 'BMW', 'Série 4 Gran Coupé',
  'bmw-s-rie-4-gran-coup-25', 2023, 'Bleu', 'Berline de prestige',
  'Couleur Bleu Portimao éclatante pour des photos de mariage spectaculaires.', 'Couleur Bleu Portimao éclatante pour des photos de mariage spectaculaires.',
  550.00, 'Disponible 7j/7', true, false, 25, 'd6f066a7-ce2d-57e1-b422-16ce0a1311fc', 'active',
  4, 'Nabeul', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '4935187b-9714-567f-a17c-83467cb3873f', 'b2ab4d44-0095-556f-8057-965ef86616f9', 'https://images.unsplash.com/photo-1556189250-72ba954cfc2b?auto=format&fit=crop&w=1200&q=80', 'BMW Série 4 Gran Coupé 420i', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '2642af19-c3fc-5d27-a310-2e0f6af9d799', 'BMW Série 8 Gran Coupé M850i', 'BMW', 'Série 8 Gran Coupé',
  'bmw-s-rie-8-gran-coup-26', 2022, 'Noir', 'Berline de prestige',
  'Coupé 4 portes d''élite avec moteur V8 Biturbo de 530 chevaux.', 'Coupé 4 portes d''élite avec moteur V8 Biturbo de 530 chevaux.',
  1300.00, 'Disponible 7j/7', true, false, 26, '2ac6af30-1c87-52fe-a2c1-d460fd518503', 'active',
  4, 'Hammamet', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'c0b83ec9-0a4c-556e-9021-156c40f8b50e', '2642af19-c3fc-5d27-a310-2e0f6af9d799', 'https://images.unsplash.com/photo-1580273916550-e323be2ae537?auto=format&fit=crop&w=1200&q=80', 'BMW Série 8 Gran Coupé M850i', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'b9079c97-2440-5a56-ae09-30caf7bd51eb', 'BMW X7 xDrive40i M Sport', 'BMW', 'X7',
  'bmw-x7-27', 2023, 'Blanc', 'SUV',
  'Majestueux SUV BMW offrant une prestance colossale et un habitacle très généreux.', 'Majestueux SUV BMW offrant une prestance colossale et un habitacle très généreux.',
  1000.00, 'Disponible 7j/7', true, false, 27, '25c6d25e-8789-551c-8451-4414d67f9ca1', 'active',
  5, 'Bizerte', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'de2cce76-41d8-5731-9915-8422ef619294', 'b9079c97-2440-5a56-ae09-30caf7bd51eb', 'https://images.unsplash.com/photo-1506015391300-4802dc74de2e?auto=format&fit=crop&w=1200&q=80', 'BMW X7 xDrive40i M Sport', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '58fdcece-afe6-5f0e-bc57-3ff82ddee46a', 'BMW X6 xDrive30d M Sport', 'BMW', 'X6',
  'bmw-x6-28', 2022, 'Gris', 'SUV',
  'Pionnier du segment SUV Coupé au design expressif et percutant.', 'Pionnier du segment SUV Coupé au design expressif et percutant.',
  750.00, 'Disponible 7j/7', true, false, 28, '6476e667-9318-55ea-a06f-1eafc54461a7', 'active',
  4, 'Tunis', ARRAY['wedding', 'event'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '881b2413-4f97-585b-99ab-d0bafea9aed9', '58fdcece-afe6-5f0e-bc57-3ff82ddee46a', 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&w=1200&q=80', 'BMW X6 xDrive30d M Sport', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'bf90e59e-5ace-561f-98e9-b49cfafdaee8', 'Audi A8 L 55 TFSI Quattro', 'Audi', 'A8 L',
  'audi-a8-l-29', 2022, 'Noir', 'Berline de prestige',
  'Version longue avec espace aux jambes impérial et projecteurs Digital Matrix LED.', 'Version longue avec espace aux jambes impérial et projecteurs Digital Matrix LED.',
  850.00, 'Disponible 7j/7', true, false, 29, '23338aeb-00c2-526f-bf21-a6fb3c662d7f', 'active',
  4, 'Sousse', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '5da4f7da-d0b9-5f59-a1f5-9faa251c06a5', 'bf90e59e-5ace-561f-98e9-b49cfafdaee8', 'https://images.unsplash.com/photo-1606016159991-dfe4f2746ad5?auto=format&fit=crop&w=1200&q=80', 'Audi A8 L 55 TFSI Quattro', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '994e2694-53e6-5ff3-9d09-4047e0454d2c', 'Audi A7 Sportback 45 TFSI S-Line', 'Audi', 'A7 Sportback',
  'audi-a7-sportback-30', 2023, 'Blanc', 'Berline de prestige',
  'Ligne de toit fuyante spectaculaire et signature lumineuse animée.', 'Ligne de toit fuyante spectaculaire et signature lumineuse animée.',
  700.00, 'Disponible 7j/7', true, false, 30, 'cb53d47b-d24f-52d2-bcf8-362ba68cf90b', 'active',
  4, 'Ariana', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'a8c5a5f4-a36d-59a8-8b82-160b51847dad', '994e2694-53e6-5ff3-9d09-4047e0454d2c', 'https://images.unsplash.com/photo-1541348263662-e0c8de4259ba?auto=format&fit=crop&w=1200&q=80', 'Audi A7 Sportback 45 TFSI S-Line', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '787e0fcc-1766-5f4d-95ea-7a3d7c9aff71', 'Audi A6 S-Line 40 TDI', 'Audi', 'A6',
  'audi-a6-31', 2022, 'Argent', 'Berline de prestige',
  'Finition S-Line complète, sobre, statutaire et très confortable.', 'Finition S-Line complète, sobre, statutaire et très confortable.',
  550.00, 'Disponible 7j/7', true, false, 31, '6eccbdad-f7ee-54c2-96b4-ef7a8ac008c6', 'active',
  4, 'Ben Arous', ARRAY['wedding', 'event'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'e757cbad-f8ae-5acb-bf0c-50f6a2d3394f', '787e0fcc-1766-5f4d-95ea-7a3d7c9aff71', 'https://images.unsplash.com/photo-1603584173870-7f23fdae1b7a?auto=format&fit=crop&w=1200&q=80', 'Audi A6 S-Line 40 TDI', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '9ce8456a-2c65-5305-92bd-743efaf3035b', 'Audi Q8 S-Line 50 TDI', 'Audi', 'Q8',
  'audi-q8-32', 2023, 'Blanc', 'SUV',
  'Vaisseau amiral de la gamme Q, portes sans encadrement et design avant-gardiste.', 'Vaisseau amiral de la gamme Q, portes sans encadrement et design avant-gardiste.',
  800.00, 'Disponible 7j/7', true, false, 32, '35fa36c8-c32f-511a-9db3-2f140515ff84', 'active',
  4, 'La Marsa', ARRAY['wedding', 'event'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'cc2f97dc-ca7f-5f8a-8dc4-a7a4a1198c1f', '9ce8456a-2c65-5305-92bd-743efaf3035b', 'https://images.unsplash.com/photo-1542282088-72c9c27ed0cd?auto=format&fit=crop&w=1200&q=80', 'Audi Q8 S-Line 50 TDI', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '6ad31e35-86cb-5e61-a957-279419221674', 'Audi A5 Sportback S-Line', 'Audi', 'A5 Sportback',
  'audi-a5-sportback-33', 2021, 'Gris', 'Berline de prestige',
  'L''élégance sportive allemande accessible pour votre cortège.', 'L''élégance sportive allemande accessible pour votre cortège.',
  480.00, 'Disponible 7j/7', true, false, 33, '69eff6ee-12e1-501f-9f55-9f30fc2205ea', 'active',
  4, 'Djerba', ARRAY['wedding', 'event'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'a7cd879c-b569-54b6-a569-a31b3a759848', '6ad31e35-86cb-5e61-a957-279419221674', 'https://images.unsplash.com/photo-1541348263662-e0c8de4259ba?auto=format&fit=crop&w=1200&q=80', 'Audi A5 Sportback S-Line', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'f22ff51b-1972-58d5-bd9d-d8abfbeaa626', 'Range Rover Vogue Autobiography', 'Land Rover', 'Range Rover Vogue',
  'land-rover-range-rover-vogue-34', 2023, 'Blanc', 'SUV',
  'Le roi des SUV de luxe. Raffinement britannique suprême pour les mariés.', 'Le roi des SUV de luxe. Raffinement britannique suprême pour les mariés.',
  1200.00, 'Disponible 7j/7', true, false, 34, '61a078eb-0f69-5d97-9fff-4b4bd5ccfcfc', 'active',
  4, 'Sfax', ARRAY['wedding', 'event'], 'automatic', 'hybrid', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver', 'water']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '47b6617e-5f99-575f-b0bf-fb7f3971f663', 'f22ff51b-1972-58d5-bd9d-d8abfbeaa626', 'https://images.unsplash.com/photo-1542282088-72c9c27ed0cd?auto=format&fit=crop&w=1200&q=80', 'Range Rover Vogue Autobiography', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'f32472a6-9e79-53d6-bd71-d196c0b6836b', 'Range Rover Sport HSE Dynamic', 'Land Rover', 'Range Rover Sport',
  'land-rover-range-rover-sport-35', 2022, 'Noir', 'SUV',
  'Allure musclée et toit contrasté pour un cortège imposant.', 'Allure musclée et toit contrasté pour un cortège imposant.',
  850.00, 'Disponible 7j/7', true, false, 35, 'e4ae4dd2-e903-5513-97ae-407c83c67742', 'active',
  4, 'Mahdia', ARRAY['wedding', 'event'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '80b9deee-69ec-5288-9c42-92e39f39f8cd', 'f32472a6-9e79-53d6-bd71-d196c0b6836b', 'https://images.unsplash.com/photo-1563720223185-11003d516935?auto=format&fit=crop&w=1200&q=80', 'Range Rover Sport HSE Dynamic', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '0364d319-25f0-58f0-ae61-ecffa01e3e3c', 'Range Rover Velar R-Dynamic', 'Land Rover', 'Range Rover Velar',
  'land-rover-range-rover-velar-36', 2022, 'Ivoire', 'SUV',
  'Poignées affleurantes et design épuré récompensé dans le monde entier.', 'Poignées affleurantes et design épuré récompensé dans le monde entier.',
  650.00, 'Disponible 7j/7', true, false, 36, '751c7cb9-930f-5032-a391-66b5c29f355d', 'active',
  4, 'Sousse', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '955ce7e1-c521-58cc-8de2-0323cfd2c22e', '0364d319-25f0-58f0-ae61-ecffa01e3e3c', 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?auto=format&fit=crop&w=1200&q=80', 'Range Rover Velar R-Dynamic', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'bd65894b-e4c6-5231-a49e-4aacf86f2dfa', 'Range Rover Evoque HSE', 'Land Rover', 'Range Rover Evoque',
  'land-rover-range-rover-evoque-37', 2022, 'Blanc', 'SUV',
  'SUV compact glamour idéal pour les mariages dans les villes côtières.', 'SUV compact glamour idéal pour les mariages dans les villes côtières.',
  480.00, 'Disponible 7j/7', true, false, 37, 'fd9cf00c-7bab-59b6-a072-0a287fbefc6f', 'active',
  4, 'Kairouan', ARRAY['wedding', 'event'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '548a4396-0b4d-5d3a-8f1b-fb1b8f6fe061', 'bd65894b-e4c6-5231-a49e-4aacf86f2dfa', 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&w=1200&q=80', 'Range Rover Evoque HSE', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '1a3a2743-4469-504f-bf12-590651ffe6f2', 'Jaguar XF Portfolio', 'Jaguar', 'XF',
  'jaguar-xf-38', 2022, 'Blanc', 'Berline de prestige',
  'L''élégance féline anglaise dans une berline racée.', 'L''élégance féline anglaise dans une berline racée.',
  550.00, 'Disponible 7j/7', true, false, 38, '77d05462-ef43-5442-9b25-76e8c97851a9', 'active',
  4, 'Monastir', ARRAY['wedding', 'event'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '6a4a050b-086a-56b7-b851-8b7589b0b716', '1a3a2743-4469-504f-bf12-590651ffe6f2', 'https://images.unsplash.com/photo-1542282088-72c9c27ed0cd?auto=format&fit=crop&w=1200&q=80', 'Jaguar XF Portfolio', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'a45a9081-59d5-515b-b7ec-0071d46f146c', 'Jaguar XJ L Sovereign', 'Jaguar', 'XJ L',
  'jaguar-xj-l-39', 2020, 'Noir', 'Berline de prestige',
  'Version limousine longue au charme aristocratique indéniable.', 'Version limousine longue au charme aristocratique indéniable.',
  700.00, 'Disponible 7j/7', true, false, 39, 'aa941779-ac29-5f31-8d63-0ba467008ed2', 'active',
  4, 'Tunis', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '3ef268df-338a-5d21-a276-c285381463ae', 'a45a9081-59d5-515b-b7ec-0071d46f146c', 'https://images.unsplash.com/photo-1563720223185-11003d516935?auto=format&fit=crop&w=1200&q=80', 'Jaguar XJ L Sovereign', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '8dadd781-393d-5d5e-8bb4-2b0c52f01f98', 'Maserati Ghibli Modena', 'Maserati', 'Ghibli',
  'maserati-ghibli-40', 2022, 'Blanc', 'Berline de prestige',
  'Le son mythique du moteur Ferrari sous le capot d''une berline italienne sculpturale.', 'Le son mythique du moteur Ferrari sous le capot d''une berline italienne sculpturale.',
  800.00, 'Disponible 7j/7', true, false, 40, '542bdad5-7c8c-5023-9594-98af51cc730c', 'active',
  4, 'Gammarth', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '52114922-1727-53a9-aaf8-d6ce799b8f87', '8dadd781-393d-5d5e-8bb4-2b0c52f01f98', 'https://images.unsplash.com/photo-1617814076367-b759c7d7e738?auto=format&fit=crop&w=1200&q=80', 'Maserati Ghibli Modena', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '89e24515-8a0d-5935-b7ca-efe9fd3af153', 'Maserati Levante GranLusso', 'Maserati', 'Levante',
  'maserati-levante-41', 2021, 'Bleu', 'SUV',
  'Intérieur soyeux Ermenegildo Zegna et style italien inimitable.', 'Intérieur soyeux Ermenegildo Zegna et style italien inimitable.',
  850.00, 'Disponible 7j/7', true, false, 41, 'ee1141f3-af04-5ad1-a0f3-658a97737453', 'active',
  4, 'Tunis', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'c1edf8dc-b1f3-513a-ac5d-18f25729de41', '89e24515-8a0d-5935-b7ca-efe9fd3af153', 'https://images.unsplash.com/photo-1502877338535-766e1452684a?auto=format&fit=crop&w=1200&q=80', 'Maserati Levante GranLusso', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'a4404890-3107-5867-a467-ecbb2301cedf', 'Bentley Continental GT', 'Bentley', 'Continental GT',
  'bentley-continental-gt-42', 2021, 'Blanc', 'Berline de prestige',
  'Grand Tourer d''exception associant artisanat anglais et performances supersoniques.', 'Grand Tourer d''exception associant artisanat anglais et performances supersoniques.',
  1900.00, 'Disponible 7j/7', true, false, 42, '1f33d55e-271e-57ce-b2b7-250e2a2823bd', 'active',
  4, 'Sousse', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver', 'water']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'c86c0bca-6ba9-5a47-a3e9-0158a0a7d632', 'a4404890-3107-5867-a467-ecbb2301cedf', 'https://images.unsplash.com/photo-1563720223185-11003d516935?auto=format&fit=crop&w=1200&q=80', 'Bentley Continental GT', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '04ce00c8-010e-5554-9c26-c737c3ee6b9f', 'Bentley Flying Spur V8', 'Bentley', 'Flying Spur',
  'bentley-flying-spur-43', 2022, 'Noir', 'Berline de prestige',
  'Mascotte Flying B rétractable et habitacle cousu main.', 'Mascotte Flying B rétractable et habitacle cousu main.',
  2100.00, 'Disponible 7j/7', true, false, 43, '058ae746-39ca-5bf6-bdd7-6dd945132d37', 'active',
  4, 'Sfax', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver', 'wifi', 'water']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '60edce2a-0c27-53dc-a6d1-db7eb225d1ba', '04ce00c8-010e-5554-9c26-c737c3ee6b9f', 'https://images.unsplash.com/photo-1631295868223-63265b40d9e4?auto=format&fit=crop&w=1200&q=80', 'Bentley Flying Spur V8', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '34b63051-28f5-5b91-ada7-b319b0ea914b', 'Chrysler 300C Limousine Stretch 9m', 'Chrysler', '300C Limousine',
  'chrysler-300c-limousine-44', 2019, 'Blanc', 'Limousine',
  'Véritable limousine américaine de 9 mètres avec bar lumineux, ciel étoilé et sono VIP.', 'Véritable limousine américaine de 9 mètres avec bar lumineux, ciel étoilé et sono VIP.',
  1100.00, 'Disponible 7j/7', true, false, 44, '31f603c0-2685-5239-b304-2e25c2f09c50', 'active',
  8, 'Monastir', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'uniformed_driver', 'water', 'bluetooth_audio']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'bdf3ccef-a0df-529a-8354-135590d1cc08', '34b63051-28f5-5b91-ada7-b319b0ea914b', 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=1200&q=80', 'Chrysler 300C Limousine Stretch 9m', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '7898dcd3-3985-5049-a6fc-f5f06ba94c6f', 'Chrysler 300C Luxury Sedan', 'Chrysler', '300C',
  'chrysler-300c-45', 2020, 'Noir', 'Berline de prestige',
  'Calandre chromée majestueuse style Bentley pour un budget très doux.', 'Calandre chromée majestueuse style Bentley pour un budget très doux.',
  500.00, 'Disponible 7j/7', true, false, 45, 'd6f066a7-ce2d-57e1-b422-16ce0a1311fc', 'active',
  4, 'Nabeul', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'ribbons', 'sunroof']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '3bff2e48-5028-5248-beb1-b30f0f0a973b', '7898dcd3-3985-5049-a6fc-f5f06ba94c6f', 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?auto=format&fit=crop&w=1200&q=80', 'Chrysler 300C Luxury Sedan', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '4fa912d4-7a47-5d39-8452-a1cc4d45889e', 'Citroën Traction Avant 11B', 'Citroën', 'Traction Avant',
  'citro-n-traction-avant-46', 1954, 'Noir', 'Voiture de collection',
  'Véritable légende française entièrement restaurée. Idéale pour des mariages vintage.', 'Véritable légende française entièrement restaurée. Idéale pour des mariages vintage.',
  800.00, 'Disponible 7j/7', true, false, 46, '2ac6af30-1c87-52fe-a2c1-d460fd518503', 'active',
  4, 'Hammamet', ARRAY['wedding', 'event'], 'manual', 'petrol', ARRAY['leather_seats', 'flower_decoration', 'ribbons', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '2bd02914-32ba-54a6-a5f9-15010fa40783', '4fa912d4-7a47-5d39-8452-a1cc4d45889e', 'https://images.unsplash.com/photo-1508974239320-0a029497e820?auto=format&fit=crop&w=1200&q=80', 'Citroën Traction Avant 11B', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '1c969b89-f70d-50f7-8239-b7867c85df82', 'Peugeot 404 Cabriolet Pininfarina', 'Peugeot', '404 Cabriolet',
  'peugeot-404-cabriolet-47', 1968, 'Blanc', 'Voiture de collection',
  'Dessinée par Pininfarina, le chic méditerranéen pour vos photos de mariage.', 'Dessinée par Pininfarina, le chic méditerranéen pour vos photos de mariage.',
  750.00, 'Disponible 7j/7', true, false, 47, '25c6d25e-8789-551c-8451-4414d67f9ca1', 'active',
  4, 'Bizerte', ARRAY['wedding', 'event'], 'manual', 'petrol', ARRAY['leather_seats', 'flower_decoration', 'convertible_roof', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '6782910a-cd41-5c05-b3c7-25f3c26e9ea9', '1c969b89-f70d-50f7-8239-b7867c85df82', 'https://images.unsplash.com/photo-1508974239320-0a029497e820?auto=format&fit=crop&w=1200&q=80', 'Peugeot 404 Cabriolet Pininfarina', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '682ae64e-136d-5cb8-b293-880fa20727b5', 'Volkswagen Coccinelle 1303 Cabriolet', 'Volkswagen', 'Coccinelle Cabriolet',
  'volkswagen-coccinelle-cabriolet-48', 1974, 'Blanc', 'Voiture de collection',
  'Une icône rétro pleine de joie et d''amour pour une fête inoubliable.', 'Une icône rétro pleine de joie et d''amour pour une fête inoubliable.',
  600.00, 'Disponible 7j/7', true, false, 48, '6476e667-9318-55ea-a06f-1eafc54461a7', 'active',
  4, 'Tunis', ARRAY['wedding', 'event'], 'manual', 'petrol', ARRAY['flower_decoration', 'convertible_roof', 'ribbons']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'fbb92f82-8a02-5ac5-9c1f-ce1a284f2c27', '682ae64e-136d-5cb8-b293-880fa20727b5', 'https://images.unsplash.com/photo-1508974239320-0a029497e820?auto=format&fit=crop&w=1200&q=80', 'Volkswagen Coccinelle 1303 Cabriolet', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '7d570a70-307d-59a1-8f0e-9c4d47c5ee94', 'Mercedes-Benz 280 SE W108', 'Mercedes-Benz', '280 SE',
  'mercedes-benz-280-se-49', 1970, 'Ivoire', 'Voiture de collection',
  'La grande dame de Stuttgart. Intérieur boisé et chrome étincelant.', 'La grande dame de Stuttgart. Intérieur boisé et chrome étincelant.',
  850.00, 'Disponible 7j/7', true, false, 49, '23338aeb-00c2-526f-bf21-a6fb3c662d7f', 'active',
  4, 'Sousse', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['leather_seats', 'flower_decoration', 'sunroof', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'f95a97c2-a367-5eda-8cb0-4f1714202f74', '7d570a70-307d-59a1-8f0e-9c4d47c5ee94', 'https://images.unsplash.com/photo-1508974239320-0a029497e820?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz 280 SE W108', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '9269647d-7b51-5c24-b071-81d4c157fbb1', 'Ford Mustang Fastback V8 1967', 'Ford', 'Mustang Fastback',
  'ford-mustang-fastback-50', 1967, 'Rouge', 'Voiture de collection',
  'Muscle car mythique des années 60 pour une entrée pleine de caractère et de passion.', 'Muscle car mythique des années 60 pour une entrée pleine de caractère et de passion.',
  900.00, 'Disponible 7j/7', true, false, 50, 'cb53d47b-d24f-52d2-bcf8-362ba68cf90b', 'active',
  4, 'Ariana', ARRAY['wedding', 'event'], 'manual', 'petrol', ARRAY['leather_seats', 'flower_decoration', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '8f912c7d-dd45-5370-9312-3981c524749e', '9269647d-7b51-5c24-b071-81d4c157fbb1', 'https://images.unsplash.com/photo-1584345604476-8ec5e12e42dd?auto=format&fit=crop&w=1200&q=80', 'Ford Mustang Fastback V8 1967', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '735170da-b5a9-5ea6-a860-f91c170d2bac', 'Jaguar Mark II 3.8', 'Jaguar', 'Mark II',
  'jaguar-mark-ii-51', 1962, 'Ivoire', 'Voiture de collection',
  'Restaurée à l''état concours, boiseries en ronce de noyer et cuir anglais.', 'Restaurée à l''état concours, boiseries en ronce de noyer et cuir anglais.',
  900.00, 'Disponible 7j/7', true, false, 51, '6eccbdad-f7ee-54c2-96b4-ef7a8ac008c6', 'active',
  4, 'Ben Arous', ARRAY['wedding', 'event'], 'manual', 'petrol', ARRAY['leather_seats', 'flower_decoration', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '96f2c9ba-898f-570f-93b2-cbd412c68d1d', '735170da-b5a9-5ea6-a860-f91c170d2bac', 'https://images.unsplash.com/photo-1508974239320-0a029497e820?auto=format&fit=crop&w=1200&q=80', 'Jaguar Mark II 3.8', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '3df0545c-c759-537b-b098-6c973f57c324', 'Aston Martin DB11 V8', 'Aston Martin', 'DB11',
  'aston-martin-db11-52', 2022, 'Argent', 'Berline de prestige',
  'Allure James Bond britannique, prestige et sonorité noble pour une arrivée de mariage grandiose.', 'Allure James Bond britannique, prestige et sonorité noble pour une arrivée de mariage grandiose.',
  1750.00, 'Disponible 7j/7', true, false, 52, '35fa36c8-c32f-511a-9db3-2f140515ff84', 'active',
  4, 'La Marsa', ARRAY['wedding', 'event'], 'automatic', 'petrol', ARRAY['air_conditioning', 'leather_seats', 'flower_decoration', 'uniformed_driver', 'bluetooth_audio']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'c2371e09-0e1e-5947-9ed6-6b98ffe99d66', '3df0545c-c759-537b-b098-6c973f57c324', 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?auto=format&fit=crop&w=1200&q=80', 'Aston Martin DB11 V8', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '4a443880-3c41-54ce-95af-351c967f86ee', 'Mercedes-Benz Classe V 250d Exclusive', 'Mercedes-Benz', 'Classe V 250d',
  'mercedes-benz-classe-v-250d-53', 2023, 'Noir', 'Van / minibus',
  'Salon VIP sur roues avec sièges en vis-à-vis, table pliante et climatisation tri-zone.', 'Salon VIP sur roues avec sièges en vis-à-vis, table pliante et climatisation tri-zone.',
  600.00, 'Disponible 7j/7', true, false, 53, '69eff6ee-12e1-501f-9f55-9f30fc2205ea', 'active',
  7, 'Djerba', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'usb_charging', 'wifi', 'large_trunk', 'uniformed_driver', 'child_seats']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '83d4c696-34d2-5b01-8655-eb6f094cd41b', '4a443880-3c41-54ce-95af-351c967f86ee', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz Classe V 250d Exclusive', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '506f80d2-4c06-5501-9060-a29ccd19f7e8', 'Mercedes-Benz Classe V 300d AMG Line', 'Mercedes-Benz', 'Classe V 300d',
  'mercedes-benz-classe-v-300d-54', 2022, 'Gris', 'Van / minibus',
  'Idéal pour transporter la belle-famille et les invités d''honneur avec un maximum de confort.', 'Idéal pour transporter la belle-famille et les invités d''honneur avec un maximum de confort.',
  650.00, 'Disponible 7j/7', true, false, 54, '61a078eb-0f69-5d97-9fff-4b4bd5ccfcfc', 'active',
  8, 'Sfax', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'usb_charging', 'large_trunk', 'uniformed_driver', 'child_seats']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '229a4236-e14d-5f82-9c7e-ee614dd59fd7', '506f80d2-4c06-5501-9060-a29ccd19f7e8', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz Classe V 300d AMG Line', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'd233e91d-a359-5536-9a07-3291acb0178a', 'Mercedes-Benz Vito Tourer PRO', 'Mercedes-Benz', 'Vito Tourer',
  'mercedes-benz-vito-tourer-55', 2022, 'Blanc', 'Van / minibus',
  'Navette 9 places spacieuse pour les transferts vers la salle des fêtes ou l''aéroport.', 'Navette 9 places spacieuse pour les transferts vers la salle des fêtes ou l''aéroport.',
  450.00, 'Disponible 7j/7', true, false, 55, 'e4ae4dd2-e903-5513-97ae-407c83c67742', 'active',
  9, 'Mahdia', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'usb_charging', 'large_trunk', 'child_seats']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '9b2e8852-0c81-5378-9338-37e9ba92a546', 'd233e91d-a359-5536-9a07-3291acb0178a', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz Vito Tourer PRO', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '942fef47-843b-5b26-b83b-b1f141c18c14', 'Mercedes-Benz Vito Select Long', 'Mercedes-Benz', 'Vito Select',
  'mercedes-benz-vito-select-56', 2021, 'Noir', 'Van / minibus',
  'Confortable et économique pour toute la famille lors des soirées de mariage.', 'Confortable et économique pour toute la famille lors des soirées de mariage.',
  480.00, 'Disponible 7j/7', true, false, 56, '751c7cb9-930f-5032-a391-66b5c29f355d', 'active',
  9, 'Sousse', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'child_seats']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '6a96849c-a762-50c8-818e-bfd1a6ee4033', '942fef47-843b-5b26-b83b-b1f141c18c14', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz Vito Select Long', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '3cbd3d0d-b818-5622-9b0e-7fc7079d3e41', 'Mercedes-Benz Sprinter 519 VIP Lounge', 'Mercedes-Benz', 'Sprinter VIP',
  'mercedes-benz-sprinter-vip-57', 2023, 'Noir', 'Van / minibus',
  'Minibus grand luxe 16 places équipé d''écrans vidéo et sièges cuir inclinables.', 'Minibus grand luxe 16 places équipé d''écrans vidéo et sièges cuir inclinables.',
  950.00, 'Disponible 7j/7', true, false, 57, 'fd9cf00c-7bab-59b6-a072-0a287fbefc6f', 'active',
  16, 'Kairouan', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'usb_charging', 'wifi', 'large_trunk', 'uniformed_driver']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '9d878b19-26b6-56ea-806e-bff54b634a23', '3cbd3d0d-b818-5622-9b0e-7fc7079d3e41', 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz Sprinter 519 VIP Lounge', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '769bfcd7-2efe-5cf5-b288-d8194d461518', 'Mercedes-Benz Sprinter Transfer', 'Mercedes-Benz', 'Sprinter Transfer',
  'mercedes-benz-sprinter-transfer-58', 2021, 'Blanc', 'Van / minibus',
  'Parfait pour acheminer les invités en toute sécurité entre les hôtels et le lieu de fête.', 'Parfait pour acheminer les invités en toute sécurité entre les hôtels et le lieu de fête.',
  750.00, 'Disponible 7j/7', true, false, 58, '77d05462-ef43-5442-9b25-76e8c97851a9', 'active',
  15, 'Monastir', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'usb_charging']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '74ac3b4f-bde0-557e-87b2-f79680a3790d', '769bfcd7-2efe-5cf5-b288-d8194d461518', 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz Sprinter Transfer', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'b7449611-7a3f-5cba-873d-6cc71fd7e43b', 'Volkswagen Caravelle T6.1 Highline', 'Volkswagen', 'Caravelle T6.1',
  'volkswagen-caravelle-t6-1-59', 2023, 'Noir', 'Van / minibus',
  'La référence du transport familial en Tunisie, grand confort et coffre très spacieux.', 'La référence du transport familial en Tunisie, grand confort et coffre très spacieux.',
  480.00, 'Disponible 7j/7', true, false, 59, 'aa941779-ac29-5f31-8d63-0ba467008ed2', 'active',
  9, 'Tunis', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'usb_charging', 'child_seats', 'uniformed_driver']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'b0f66975-e923-5613-89e8-344cc2d8e94b', 'b7449611-7a3f-5cba-873d-6cc71fd7e43b', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Volkswagen Caravelle T6.1 Highline', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '85f21ac4-4eba-5702-96e7-d050f879cae7', 'Volkswagen Caravelle T6 Trendline', 'Volkswagen', 'Caravelle T6',
  'volkswagen-caravelle-t6-60', 2020, 'Gris', 'Van / minibus',
  'Robuste et climatisé, idéal pour les navettes de mariage en Tunisie.', 'Robuste et climatisé, idéal pour les navettes de mariage en Tunisie.',
  420.00, 'Disponible 7j/7', true, false, 60, '542bdad5-7c8c-5023-9594-98af51cc730c', 'active',
  9, 'Gammarth', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'child_seats']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '4d82d553-9b02-5870-ba38-a4ae85671a1f', '85f21ac4-4eba-5702-96e7-d050f879cae7', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Volkswagen Caravelle T6 Trendline', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '995b8593-bc2f-5cf2-860c-2d9962a5d662', 'Volkswagen Multivan T6.1 Comfortline', 'Volkswagen', 'Multivan T6.1',
  'volkswagen-multivan-t6-1-61', 2022, 'Blanc', 'Van / minibus',
  'Modulable et luxueux, fauteuils pivotants pour un trajet convivial en famille.', 'Modulable et luxueux, fauteuils pivotants pour un trajet convivial en famille.',
  550.00, 'Disponible 7j/7', true, false, 61, 'ee1141f3-af04-5ad1-a0f3-658a97737453', 'active',
  7, 'Tunis', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'usb_charging', 'child_seats', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '581e5b58-fb3d-5ca2-aefe-45f37e6392bd', '995b8593-bc2f-5cf2-860c-2d9962a5d662', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Volkswagen Multivan T6.1 Comfortline', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'f85c7d3b-15e7-5b8a-8009-21f0cdc56f56', 'Volkswagen Transporter Shuttle 9 Places', 'Volkswagen', 'Transporter Shuttle',
  'volkswagen-transporter-shuttle-62', 2021, 'Argent', 'Van / minibus',
  'Transport de groupe fiable et ponctuel pour votre cortège familial.', 'Transport de groupe fiable et ponctuel pour votre cortège familial.',
  400.00, 'Disponible 7j/7', true, false, 62, '1f33d55e-271e-57ce-b2b7-250e2a2823bd', 'active',
  9, 'Sousse', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'child_seats']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '1aca57c0-05ee-5600-8e9a-0a82b0f0a73a', 'f85c7d3b-15e7-5b8a-8009-21f0cdc56f56', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Volkswagen Transporter Shuttle 9 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '9550be54-1b16-5de9-881c-7167bbbdc91f', 'Volkswagen Tiguan Allspace R-Line', 'Volkswagen', 'Tiguan Allspace',
  'volkswagen-tiguan-allspace-63', 2023, 'Blanc', 'SUV',
  'SUV 7 places élégant pour accompagner les mariés et transporter les proches.', 'SUV 7 places élégant pour accompagner les mariés et transporter les proches.',
  420.00, 'Disponible 7j/7', true, false, 63, '058ae746-39ca-5bf6-bdd7-6dd945132d37', 'active',
  7, 'Sfax', ARRAY['family', 'private'], 'automatic', 'petrol', ARRAY['air_conditioning', 'sunroof', 'child_seats', 'large_trunk']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '9ec02de7-fb8e-52ce-9db5-6875af5f1216', '9550be54-1b16-5de9-881c-7167bbbdc91f', 'https://images.unsplash.com/photo-1502877338535-766e1452684a?auto=format&fit=crop&w=1200&q=80', 'Volkswagen Tiguan Allspace R-Line', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '368af0a0-cbda-55eb-ad4b-e0a0673eed58', 'Volkswagen Touran Family', 'Volkswagen', 'Touran',
  'volkswagen-touran-64', 2021, 'Gris', 'Van / minibus',
  'Monospace familial moderne et sécurisant avec fixations Isofix multiples.', 'Monospace familial moderne et sécurisant avec fixations Isofix multiples.',
  320.00, 'Disponible 7j/7', true, false, 64, '31f603c0-2685-5239-b304-2e25c2f09c50', 'active',
  7, 'Monastir', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'child_seats', 'large_trunk']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '2b7a6231-0def-5680-8146-c242f74a7f11', '368af0a0-cbda-55eb-ad4b-e0a0673eed58', 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=1200&q=80', 'Volkswagen Touran Family', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '95c3c3e2-f451-5801-861a-920f4c003a40', 'Hyundai Staria Premium 9 Places', 'Hyundai', 'Staria Premium',
  'hyundai-staria-premium-65', 2023, 'Noir', 'Van / minibus',
  'Design futuriste spectaculaire et habitacle ultra moderne pour toute la famille.', 'Design futuriste spectaculaire et habitacle ultra moderne pour toute la famille.',
  550.00, 'Disponible 7j/7', true, false, 65, 'd6f066a7-ce2d-57e1-b422-16ce0a1311fc', 'active',
  9, 'Nabeul', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'usb_charging', 'wifi', 'large_trunk', 'uniformed_driver']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '50d8278e-8d3e-5406-8fab-f71f617a22f3', '95c3c3e2-f451-5801-861a-920f4c003a40', 'https://images.unsplash.com/photo-1617788138017-80ad40651399?auto=format&fit=crop&w=1200&q=80', 'Hyundai Staria Premium 9 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'e4bea56d-5ca2-5d7c-960c-c42d757e3be9', 'Hyundai Staria Lounge 7 Places VIP', 'Hyundai', 'Staria Lounge',
  'hyundai-staria-lounge-66', 2024, 'Blanc', 'Van / minibus',
  'Fauteuils relaxation digne d''une première classe aérienne.', 'Fauteuils relaxation digne d''une première classe aérienne.',
  620.00, 'Disponible 7j/7', true, false, 66, '2ac6af30-1c87-52fe-a2c1-d460fd518503', 'active',
  7, 'Hammamet', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'usb_charging', 'wifi', 'large_trunk', 'uniformed_driver']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '7e301a64-4b9e-5967-b7b6-2b50b68c313a', 'e4bea56d-5ca2-5d7c-960c-c42d757e3be9', 'https://images.unsplash.com/photo-1617788138017-80ad40651399?auto=format&fit=crop&w=1200&q=80', 'Hyundai Staria Lounge 7 Places VIP', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '65479bb3-c718-5d69-a087-e54378707423', 'Hyundai H-1 Travel Royale 9 Places', 'Hyundai', 'H-1 Travel',
  'hyundai-h-1-travel-67', 2022, 'Argent', 'Van / minibus',
  'Le véhicule de transport familial le plus populaire en Tunisie.', 'Le véhicule de transport familial le plus populaire en Tunisie.',
  380.00, 'Disponible 7j/7', true, false, 67, '25c6d25e-8789-551c-8451-4414d67f9ca1', 'active',
  9, 'Bizerte', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'usb_charging', 'child_seats']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'd299b17e-0a8a-5955-87c3-a9ebb0474d28', '65479bb3-c718-5d69-a087-e54378707423', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Hyundai H-1 Travel Royale 9 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '54ab4683-ee40-5bd7-ae58-742ff192c36b', 'Hyundai H-1 GLX 9 Places', 'Hyundai', 'H-1 GLX',
  'hyundai-h-1-glx-68', 2020, 'Noir', 'Van / minibus',
  'Conduite souple, grand coffre et excellente climatisation pour l''été tunisien.', 'Conduite souple, grand coffre et excellente climatisation pour l''été tunisien.',
  350.00, 'Disponible 7j/7', true, false, 68, '6476e667-9318-55ea-a06f-1eafc54461a7', 'active',
  9, 'Tunis', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'child_seats']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '286e28b4-09bd-5b42-86ce-1ebf54ce9ad1', '54ab4683-ee40-5bd7-ae58-742ff192c36b', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Hyundai H-1 GLX 9 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'e64814c5-3e58-5e0b-a428-da58ddaa5050', 'Hyundai Santa Fe Calligraphy 7 Places', 'Hyundai', 'Santa Fe',
  'hyundai-santa-fe-69', 2023, 'Noir', 'SUV',
  'Grand SUV familial raffiné avec 3 rangées de sièges en cuir Nappa.', 'Grand SUV familial raffiné avec 3 rangées de sièges en cuir Nappa.',
  480.00, 'Disponible 7j/7', true, false, 69, '23338aeb-00c2-526f-bf21-a6fb3c662d7f', 'active',
  7, 'Sousse', ARRAY['family', 'private'], 'automatic', 'hybrid', ARRAY['air_conditioning', 'leather_seats', 'sunroof', 'child_seats', 'large_trunk']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'adaac196-b18c-531c-97d4-dfef23855018', 'e64814c5-3e58-5e0b-a428-da58ddaa5050', 'https://images.unsplash.com/photo-1502877338535-766e1452684a?auto=format&fit=crop&w=1200&q=80', 'Hyundai Santa Fe Calligraphy 7 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '1a7f14f5-f272-5be0-851f-d5e7038fd344', 'Toyota HiAce Grand Cabin VIP 12 Places', 'Toyota', 'HiAce Grand Cabin',
  'toyota-hiace-grand-cabin-70', 2023, 'Blanc', 'Van / minibus',
  'Spacieux, toit surélevé, parfait pour transporter toute la grande famille réunie.', 'Spacieux, toit surélevé, parfait pour transporter toute la grande famille réunie.',
  650.00, 'Disponible 7j/7', true, false, 70, 'cb53d47b-d24f-52d2-bcf8-362ba68cf90b', 'active',
  12, 'Ariana', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'usb_charging', 'large_trunk', 'uniformed_driver']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'dab1f580-a0e0-5a97-8a55-04d60156c8b4', '1a7f14f5-f272-5be0-851f-d5e7038fd344', 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80', 'Toyota HiAce Grand Cabin VIP 12 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'a749ae8f-ff55-5283-9bb4-bf5af8bc9b78', 'Toyota HiAce Commuter 14 Places', 'Toyota', 'HiAce Commuter',
  'toyota-hiace-commuter-71', 2021, 'Blanc', 'Van / minibus',
  'Idéal pour le transport groupé des invités entre la ville et la banlieue.', 'Idéal pour le transport groupé des invités entre la ville et la banlieue.',
  600.00, 'Disponible 7j/7', true, false, 71, '6eccbdad-f7ee-54c2-96b4-ef7a8ac008c6', 'active',
  14, 'Ben Arous', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'dafc312e-924f-5e27-823c-eac5dc9415c6', 'a749ae8f-ff55-5283-9bb4-bf5af8bc9b78', 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80', 'Toyota HiAce Commuter 14 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '5f052345-e8c5-5de0-bc6b-5a9d14170287', 'Toyota Proace Verso VIP 9 Places', 'Toyota', 'Proace Verso',
  'toyota-proace-verso-72', 2022, 'Gris', 'Van / minibus',
  'Très confortable, insonorisé et modulable pour vos trajets de fête.', 'Très confortable, insonorisé et modulable pour vos trajets de fête.',
  460.00, 'Disponible 7j/7', true, false, 72, '35fa36c8-c32f-511a-9db3-2f140515ff84', 'active',
  9, 'La Marsa', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'child_seats', 'usb_charging']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '1aca6d71-db30-5a3c-8379-2ac7f6f0c991', '5f052345-e8c5-5de0-bc6b-5a9d14170287', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Toyota Proace Verso VIP 9 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '79404adf-af64-50fd-a543-5d10a73de206', 'Toyota Land Cruiser Prado VX 7 Places', 'Toyota', 'Land Cruiser Prado',
  'toyota-land-cruiser-prado-73', 2022, 'Blanc', 'SUV',
  'Le baroudeur de luxe idéal pour les trajets familiaux partout en Tunisie.', 'Le baroudeur de luxe idéal pour les trajets familiaux partout en Tunisie.',
  650.00, 'Disponible 7j/7', true, false, 73, '69eff6ee-12e1-501f-9f55-9f30fc2205ea', 'active',
  7, 'Djerba', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'sunroof', 'large_trunk', 'child_seats']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'fef2ac79-c242-51ee-b7d6-28d357ebf3d9', '79404adf-af64-50fd-a543-5d10a73de206', 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&w=1200&q=80', 'Toyota Land Cruiser Prado VX 7 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'a5ea5490-fcde-5066-94e0-a6c689c4759c', 'Peugeot Traveller VIP Business 8 Places', 'Peugeot', 'Traveller VIP',
  'peugeot-traveller-vip-74', 2023, 'Noir', 'Van / minibus',
  'Finition Business VIP avec sièges individuels en cuir et toit vitré panoramique.', 'Finition Business VIP avec sièges individuels en cuir et toit vitré panoramique.',
  500.00, 'Disponible 7j/7', true, false, 74, '61a078eb-0f69-5d97-9fff-4b4bd5ccfcfc', 'active',
  8, 'Sfax', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'usb_charging', 'large_trunk', 'child_seats', 'uniformed_driver']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'c930654a-9380-5cd9-8097-42dddd82f5b9', 'a5ea5490-fcde-5066-94e0-a6c689c4759c', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Peugeot Traveller VIP Business 8 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '29ba7af7-7517-5090-ad3f-9a48d9f0d6d9', 'Peugeot Traveller Allure 9 Places', 'Peugeot', 'Traveller Allure',
  'peugeot-traveller-allure-75', 2022, 'Blanc', 'Van / minibus',
  'Espace généreux pour 9 passagers avec leurs bagages et tenues de fête.', 'Espace généreux pour 9 passagers avec leurs bagages et tenues de fête.',
  440.00, 'Disponible 7j/7', true, false, 75, 'e4ae4dd2-e903-5513-97ae-407c83c67742', 'active',
  9, 'Mahdia', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'child_seats']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'b0f6bbaf-a9bb-5100-bce6-7533dd95c4ab', '29ba7af7-7517-5090-ad3f-9a48d9f0d6d9', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Peugeot Traveller Allure 9 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '397197f8-ce34-53a9-95e4-8fcaf2775e3b', 'Peugeot Expert Combi 9 Places', 'Peugeot', 'Expert Combi',
  'peugeot-expert-combi-76', 2021, 'Gris', 'Van / minibus',
  'Rapport qualité/prix imbattable pour transporter les proches sereinement.', 'Rapport qualité/prix imbattable pour transporter les proches sereinement.',
  380.00, 'Disponible 7j/7', true, false, 76, '751c7cb9-930f-5032-a391-66b5c29f355d', 'active',
  9, 'Sousse', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'bc67263d-7a4f-5ba1-95d7-085f8cdd7dfa', '397197f8-ce34-53a9-95e4-8fcaf2775e3b', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Peugeot Expert Combi 9 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'b0b69ffd-6e22-563e-93e7-31ec0879012e', 'Peugeot 5008 GT Line 7 Places', 'Peugeot', '5008 GT Line',
  'peugeot-5008-gt-line-77', 2023, 'Bleu', 'SUV',
  'SUV 7 places élégant au design félin, idéal pour accompagner le cortège.', 'SUV 7 places élégant au design félin, idéal pour accompagner le cortège.',
  390.00, 'Disponible 7j/7', true, false, 77, 'fd9cf00c-7bab-59b6-a072-0a287fbefc6f', 'active',
  7, 'Kairouan', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'sunroof', 'child_seats', 'large_trunk']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '278b0211-4f2f-589e-95be-882a465fa594', 'b0b69ffd-6e22-563e-93e7-31ec0879012e', 'https://images.unsplash.com/photo-1502877338535-766e1452684a?auto=format&fit=crop&w=1200&q=80', 'Peugeot 5008 GT Line 7 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'd66ae054-23bf-590b-932b-01fb747c7024', 'Citroën SpaceTourer Business Lounge', 'Citroën', 'SpaceTourer Lounge',
  'citro-n-spacetourer-lounge-78', 2022, 'Noir', 'Van / minibus',
  'Suspension ultra confortable propre à Citroën pour un trajet sans secousses.', 'Suspension ultra confortable propre à Citroën pour un trajet sans secousses.',
  480.00, 'Disponible 7j/7', true, false, 78, '77d05462-ef43-5442-9b25-76e8c97851a9', 'active',
  8, 'Monastir', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'usb_charging', 'child_seats', 'large_trunk']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '99c94365-384a-5675-a845-102c6276fafb', 'd66ae054-23bf-590b-932b-01fb747c7024', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Citroën SpaceTourer Business Lounge', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '0f76c607-a808-5c12-9a56-38e58471dfa2', 'Citroën SpaceTourer Feel 9 Places', 'Citroën', 'SpaceTourer Feel',
  'citro-n-spacetourer-feel-79', 2021, 'Blanc', 'Van / minibus',
  'Navette 9 places lumineuse et agréable pour les sorties en famille.', 'Navette 9 places lumineuse et agréable pour les sorties en famille.',
  420.00, 'Disponible 7j/7', true, false, 79, 'aa941779-ac29-5f31-8d63-0ba467008ed2', 'active',
  9, 'Tunis', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'child_seats']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'c25a652f-3217-5036-ac69-293cf3547788', '0f76c607-a808-5c12-9a56-38e58471dfa2', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Citroën SpaceTourer Feel 9 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '9e2f8f4a-868f-573e-97a5-de3f5398fdcf', 'Citroën Grand C4 SpaceTourer 7 Places', 'Citroën', 'Grand C4 SpaceTourer',
  'citro-n-grand-c4-spacetourer-80', 2021, 'Gris', 'Van / minibus',
  'Pare-brise panoramique grandiose pour admirer le cortège sur la route.', 'Pare-brise panoramique grandiose pour admirer le cortège sur la route.',
  320.00, 'Disponible 7j/7', true, false, 80, '542bdad5-7c8c-5023-9594-98af51cc730c', 'active',
  7, 'Gammarth', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'child_seats', 'large_trunk']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '4e7bc2c6-af72-5d67-8809-4791a8005d14', '9e2f8f4a-868f-573e-97a5-de3f5398fdcf', 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=1200&q=80', 'Citroën Grand C4 SpaceTourer 7 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'a5c86916-f5a6-5b84-95f4-970e5ba01511', 'Renault Trafic Passenger SpaceClass', 'Renault', 'Trafic SpaceClass',
  'renault-trafic-spaceclass-81', 2023, 'Noir', 'Van / minibus',
  'La version haut de gamme du Trafic avec sellerie cuir et sièges pivotants.', 'La version haut de gamme du Trafic avec sellerie cuir et sièges pivotants.',
  490.00, 'Disponible 7j/7', true, false, 81, 'ee1141f3-af04-5ad1-a0f3-658a97737453', 'active',
  8, 'Tunis', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'usb_charging', 'large_trunk', 'uniformed_driver']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'f151c71c-d8bf-58a0-8f73-be0e9a91dc38', 'a5c86916-f5a6-5b84-95f4-970e5ba01511', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Renault Trafic Passenger SpaceClass', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'c4077253-7e23-5ac7-bab8-fff7acab89a0', 'Renault Trafic Grand Passenger 9 Places', 'Renault', 'Trafic Passenger',
  'renault-trafic-passenger-82', 2022, 'Blanc', 'Van / minibus',
  'Châssis long offrant un coffre géant même avec 9 passagers à bord.', 'Châssis long offrant un coffre géant même avec 9 passagers à bord.',
  410.00, 'Disponible 7j/7', true, false, 82, '1f33d55e-271e-57ce-b2b7-250e2a2823bd', 'active',
  9, 'Sousse', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'child_seats']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '757a8703-c8f6-5173-804e-dbf7d8e7d245', 'c4077253-7e23-5ac7-bab8-fff7acab89a0', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Renault Trafic Grand Passenger 9 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '11cff5bc-2923-5b86-9862-5189e603f165', 'Renault Espace V Initiale Paris 7 Places', 'Renault', 'Espace V',
  'renault-espace-v-83', 2022, 'Noir', 'Van / minibus',
  'Finition Initiale Paris avec cuir Nappa et système audio Bose.', 'Finition Initiale Paris avec cuir Nappa et système audio Bose.',
  460.00, 'Disponible 7j/7', true, false, 83, '058ae746-39ca-5bf6-bdd7-6dd945132d37', 'active',
  7, 'Sfax', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'sunroof', 'child_seats', 'large_trunk']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '60ec353f-86d6-586e-9eb0-416deb3c7a92', '11cff5bc-2923-5b86-9862-5189e603f165', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Renault Espace V Initiale Paris 7 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'a8b09015-3d08-5823-a92a-0d4a20a237ac', 'Renault Grand Scénic Bose Edition 7 Places', 'Renault', 'Grand Scénic',
  'renault-grand-sc-nic-84', 2020, 'Bordeaux', 'Van / minibus',
  'Monospace compact moderne équipé de jantes 20 pouces et sonorisation Bose.', 'Monospace compact moderne équipé de jantes 20 pouces et sonorisation Bose.',
  300.00, 'Disponible 7j/7', true, false, 84, '31f603c0-2685-5239-b304-2e25c2f09c50', 'active',
  7, 'Monastir', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'child_seats', 'large_trunk']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'b67defb1-dea8-587b-8d46-742b1804db2e', 'a8b09015-3d08-5823-a92a-0d4a20a237ac', 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=1200&q=80', 'Renault Grand Scénic Bose Edition 7 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '9d600f9a-a47d-591a-8851-9a2585f10356', 'Ford Tourneo Custom Titanium X 8 Places', 'Ford', 'Tourneo Custom',
  'ford-tourneo-custom-85', 2023, 'Bleu', 'Van / minibus',
  'Intérieur grand confort avec configuration salon et insonorisation renforcée.', 'Intérieur grand confort avec configuration salon et insonorisation renforcée.',
  520.00, 'Disponible 7j/7', true, false, 85, 'd6f066a7-ce2d-57e1-b422-16ce0a1311fc', 'active',
  8, 'Nabeul', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'usb_charging', 'large_trunk', 'child_seats', 'uniformed_driver']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'cdca0bcd-3f83-57c2-9f88-73cd69bef62f', '9d600f9a-a47d-591a-8851-9a2585f10356', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Ford Tourneo Custom Titanium X 8 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'ac235325-e191-54cf-a9e3-c606c5197088', 'Ford Tourneo Custom 9 Places', 'Ford', 'Tourneo Custom',
  'ford-tourneo-custom-86', 2021, 'Gris', 'Van / minibus',
  'Robuste et pratique pour tous les déplacements des familles et témoins.', 'Robuste et pratique pour tous les déplacements des familles et témoins.',
  430.00, 'Disponible 7j/7', true, false, 86, '2ac6af30-1c87-52fe-a2c1-d460fd518503', 'active',
  9, 'Hammamet', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'child_seats']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '385df926-ce24-5151-ad62-0d115bc71b5b', 'ac235325-e191-54cf-a9e3-c606c5197088', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Ford Tourneo Custom 9 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '9f539f4f-d634-5c6e-86c9-24e374d82492', 'Ford Transit Minibus 14 Places', 'Ford', 'Transit Minibus',
  'ford-transit-minibus-87', 2022, 'Blanc', 'Van / minibus',
  'Idéal pour acheminer les grands groupes d''invités d''une ville à l''autre.', 'Idéal pour acheminer les grands groupes d''invités d''une ville à l''autre.',
  680.00, 'Disponible 7j/7', true, false, 87, '25c6d25e-8789-551c-8451-4414d67f9ca1', 'active',
  14, 'Bizerte', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '187b6ff2-4a44-5e3e-a0d7-cdd82395f1d2', '9f539f4f-d634-5c6e-86c9-24e374d82492', 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80', 'Ford Transit Minibus 14 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '35ba26a0-4997-5eef-ac73-278e6d645a70', 'Kia Carnival Limousine 7 Places VIP', 'Kia', 'Carnival Limousine',
  'kia-carnival-limousine-88', 2023, 'Noir', 'Van / minibus',
  'Le luxe coréen ultime avec sièges lounge et portes latérales coulissantes électriques.', 'Le luxe coréen ultime avec sièges lounge et portes latérales coulissantes électriques.',
  580.00, 'Disponible 7j/7', true, false, 88, '6476e667-9318-55ea-a06f-1eafc54461a7', 'active',
  7, 'Tunis', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'usb_charging', 'wifi', 'large_trunk', 'uniformed_driver']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '6fc27af5-b625-51d1-ac6f-7cd9b115f657', '35ba26a0-4997-5eef-ac73-278e6d645a70', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Kia Carnival Limousine 7 Places VIP', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '9afa50ec-47e2-5867-a7ab-dc4f70758b7c', 'Kia Carnival SX 8 Places', 'Kia', 'Carnival SX',
  'kia-carnival-sx-89', 2022, 'Blanc', 'Van / minibus',
  'Spacieux, moderne et idéal pour les familles nombreuses.', 'Spacieux, moderne et idéal pour les familles nombreuses.',
  510.00, 'Disponible 7j/7', true, false, 89, '23338aeb-00c2-526f-bf21-a6fb3c662d7f', 'active',
  8, 'Sousse', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'usb_charging', 'child_seats', 'large_trunk']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '19ecf06a-decb-51ca-95b1-18c3126c71fa', '9afa50ec-47e2-5867-a7ab-dc4f70758b7c', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Kia Carnival SX 8 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '48e26396-8fae-57e4-a54d-b16b701c3912', 'Kia Sorento GT-Line 7 Places', 'Kia', 'Sorento GT-Line',
  'kia-sorento-gt-line-90', 2023, 'Gris', 'SUV',
  'Grand SUV moderne très bien insonorisé avec 7 vraies places.', 'Grand SUV moderne très bien insonorisé avec 7 vraies places.',
  460.00, 'Disponible 7j/7', true, false, 90, 'cb53d47b-d24f-52d2-bcf8-362ba68cf90b', 'active',
  7, 'Ariana', ARRAY['family', 'private'], 'automatic', 'hybrid', ARRAY['air_conditioning', 'leather_seats', 'sunroof', 'child_seats', 'large_trunk']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '9f7f3c35-5dd9-5c32-b108-3222495eaf35', '48e26396-8fae-57e4-a54d-b16b701c3912', 'https://images.unsplash.com/photo-1502877338535-766e1452684a?auto=format&fit=crop&w=1200&q=80', 'Kia Sorento GT-Line 7 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'f7efc470-f299-5af9-b122-e230e77ffa61', 'Dacia Jogger Extreme 7 Places', 'Dacia', 'Jogger Extreme',
  'dacia-jogger-extreme-91', 2023, 'Gris', 'Van / minibus',
  'Solution économique et récente pour transporter jusqu''à 7 personnes.', 'Solution économique et récente pour transporter jusqu''à 7 personnes.',
  240.00, 'Disponible 7j/7', true, false, 91, '6eccbdad-f7ee-54c2-96b4-ef7a8ac008c6', 'active',
  7, 'Ben Arous', ARRAY['family', 'private'], 'manual', 'petrol', ARRAY['air_conditioning', 'child_seats', 'large_trunk']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'a3cdce27-448e-5897-8a40-b2a5a328b775', 'f7efc470-f299-5af9-b122-e230e77ffa61', 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=1200&q=80', 'Dacia Jogger Extreme 7 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '904a4cff-1b79-5461-9a75-a3b382f59ebc', 'Dacia Lodgy Stepway 7 Places', 'Dacia', 'Lodgy Stepway',
  'dacia-lodgy-stepway-92', 2021, 'Bleu', 'Van / minibus',
  'Très économique et robuste pour les trajets vers la salle des fêtes.', 'Très économique et robuste pour les trajets vers la salle des fêtes.',
  220.00, 'Disponible 7j/7', true, false, 92, '35fa36c8-c32f-511a-9db3-2f140515ff84', 'active',
  7, 'La Marsa', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'child_seats', 'large_trunk']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'ccb86e63-0595-5d15-bc36-e61774f29d1f', '904a4cff-1b79-5461-9a75-a3b382f59ebc', 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=1200&q=80', 'Dacia Lodgy Stepway 7 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '00a7ea9d-c7d9-5c52-b3aa-f6f33e60ddc8', 'Nissan NV300 Combi 9 Places', 'Nissan', 'NV300',
  'nissan-nv300-93', 2022, 'Blanc', 'Van / minibus',
  'Minibus pratique et fiable pour les groupes d''invités.', 'Minibus pratique et fiable pour les groupes d''invités.',
  390.00, 'Disponible 7j/7', true, false, 93, '69eff6ee-12e1-501f-9f55-9f30fc2205ea', 'active',
  9, 'Djerba', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'a26afcf2-e0f8-5cb5-b7cf-09051a7c7b04', '00a7ea9d-c7d9-5c52-b3aa-f6f33e60ddc8', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Nissan NV300 Combi 9 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'a44aa441-d90e-58b2-8ef7-89df347c59e7', 'Opel Zafira Life Innovation 9 Places', 'Opel', 'Zafira Life',
  'opel-zafira-life-94', 2022, 'Gris', 'Van / minibus',
  'Navette moderne et confortable conçue pour les longs trajets en famille.', 'Navette moderne et confortable conçue pour les longs trajets en famille.',
  440.00, 'Disponible 7j/7', true, false, 94, '61a078eb-0f69-5d97-9fff-4b4bd5ccfcfc', 'active',
  9, 'Sfax', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'child_seats']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '9ec886dd-16d0-585f-ae27-e8054b2f6d36', 'a44aa441-d90e-58b2-8ef7-89df347c59e7', 'https://images.unsplash.com/photo-1559297434-fae8a1916a79?auto=format&fit=crop&w=1200&q=80', 'Opel Zafira Life Innovation 9 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '4d056b79-c1aa-587f-b3fe-b6df4bd39065', 'Fiat Ducato Panorama 15 Places', 'Fiat', 'Ducato Panorama',
  'fiat-ducato-panorama-95', 2022, 'Blanc', 'Van / minibus',
  'Minibus 15 places très spacieux pour les cortèges de mariage inter-villes.', 'Minibus 15 places très spacieux pour les cortèges de mariage inter-villes.',
  700.00, 'Disponible 7j/7', true, false, 95, 'e4ae4dd2-e903-5513-97ae-407c83c67742', 'active',
  15, 'Mahdia', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '6477866d-bb12-557e-bb1a-2d8d5422143d', '4d056b79-c1aa-587f-b3fe-b6df4bd39065', 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80', 'Fiat Ducato Panorama 15 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '962ddf4b-eb74-5cea-a7d9-194e77e28c0f', 'Iveco Daily Minibus VIP 16 Places', 'Iveco', 'Daily VIP',
  'iveco-daily-vip-96', 2023, 'Noir', 'Van / minibus',
  'Prestation grand luxe pour déplacer l''ensemble de la délégation nuptiale.', 'Prestation grand luxe pour déplacer l''ensemble de la délégation nuptiale.',
  900.00, 'Disponible 7j/7', true, false, 96, '751c7cb9-930f-5032-a391-66b5c29f355d', 'active',
  16, 'Sousse', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'large_trunk', 'uniformed_driver', 'wifi']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '7010dcf5-5926-5805-87e2-342d1efbbd9e', '962ddf4b-eb74-5cea-a7d9-194e77e28c0f', 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80', 'Iveco Daily Minibus VIP 16 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '9cb6bc29-db91-5154-a986-4caaca7acb0f', 'Mercedes-Benz Sprinter 519 VIP 19 Places', 'Mercedes-Benz', 'Sprinter 519 VIP',
  'mercedes-benz-sprinter-519-vip-97', 2023, 'Noir', 'Van / minibus',
  'Minibus VIP grand format pour les délégations familiales nombreuses et cortèges prestigieux.', 'Minibus VIP grand format pour les délégations familiales nombreuses et cortèges prestigieux.',
  1100.00, 'Disponible 7j/7', true, false, 97, 'fd9cf00c-7bab-59b6-a072-0a287fbefc6f', 'active',
  19, 'Kairouan', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'leather_seats', 'large_trunk', 'uniformed_driver', 'wifi', 'usb_charging']::text[], true, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'b337ea25-7587-5469-a605-97b220405104', '9cb6bc29-db91-5154-a986-4caaca7acb0f', 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80', 'Mercedes-Benz Sprinter 519 VIP 19 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  'c76ffc28-c11c-5251-9775-4b36de8351c6', 'Peugeot Rifter Long 7 Places', 'Peugeot', 'Rifter Long',
  'peugeot-rifter-long-98', 2022, 'Gris', 'Van / minibus',
  'Ludospace 7 places économique et modulable pour le transport d''invités.', 'Ludospace 7 places économique et modulable pour le transport d''invités.',
  280.00, 'Disponible 7j/7', true, false, 98, '77d05462-ef43-5442-9b25-76e8c97851a9', 'active',
  7, 'Monastir', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'child_seats', 'large_trunk']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  'b357cbfe-e125-5ff8-aa7b-362151f00a57', 'c76ffc28-c11c-5251-9775-4b36de8351c6', 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=1200&q=80', 'Peugeot Rifter Long 7 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '775ad15b-8017-5232-8e27-4afdce493b5e', 'Ford Galaxy Titanium 7 Places', 'Ford', 'Galaxy Titanium',
  'ford-galaxy-titanium-99', 2021, 'Noir', 'Van / minibus',
  'Grand monospace 7 places confortable avec toit vitré et climatisation arrière.', 'Grand monospace 7 places confortable avec toit vitré et climatisation arrière.',
  340.00, 'Disponible 7j/7', true, false, 99, 'aa941779-ac29-5f31-8d63-0ba467008ed2', 'active',
  7, 'Tunis', ARRAY['family', 'private'], 'automatic', 'diesel', ARRAY['air_conditioning', 'child_seats', 'large_trunk', 'sunroof']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '9480414c-52cb-5c6a-ad73-33f57a3a6792', '775ad15b-8017-5232-8e27-4afdce493b5e', 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=1200&q=80', 'Ford Galaxy Titanium 7 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES (
  '44b9539e-f157-5735-bbca-288a9cbd73f0', 'Toyota Coaster VIP 22 Places', 'Toyota', 'Coaster VIP',
  'toyota-coaster-vip-100', 2022, 'Blanc', 'Van / minibus',
  'Autocar moyen format parfait pour les grands mariages réunissant deux familles de villes différentes.', 'Autocar moyen format parfait pour les grands mariages réunissant deux familles de villes différentes.',
  1000.00, 'Disponible 7j/7', true, false, 100, '542bdad5-7c8c-5023-9594-98af51cc730c', 'active',
  22, 'Gammarth', ARRAY['family', 'private'], 'manual', 'diesel', ARRAY['air_conditioning', 'large_trunk', 'uniformed_driver']::text[], false, 'always'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, price_from = EXCLUDED.price_from, services = EXCLUDED.services,
  availability_mode = 'always', active = true, validation_status = 'active';

INSERT INTO public.car_images (
  id, car_id, storage_path, alt_text, is_cover, sort_order
) VALUES (
  '636d6318-e005-5281-83b2-757aef285800', '44b9539e-f157-5735-bbca-288a9cbd73f0', 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80', 'Toyota Coaster VIP 22 Places', true, 1
) ON CONFLICT (id) DO NOTHING;


-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║  ✅ DONE — All tables, functions, RLS, storage, users & 100 cars are ready.  ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝
