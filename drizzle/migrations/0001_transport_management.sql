-- Marriage & family transport management: catalog fields, request workflow, owner availability,
-- multi-stage journeys and live GPS tracking.
-- Run once in Supabase Studio -> SQL Editor, after setup_external_db.sql. The script is idempotent.
-- Every write goes through SECURITY DEFINER functions below; tables only expose reads through RLS.

CREATE EXTENSION IF NOT EXISTS btree_gist;

-- New request statuses. They are only referenced inside function bodies or as text, because a value
-- added by ALTER TYPE cannot be used by DDL in the same transaction.
ALTER TYPE public.booking_status ADD VALUE IF NOT EXISTS 'under_review';
ALTER TYPE public.booking_status ADD VALUE IF NOT EXISTS 'approved';
ALTER TYPE public.booking_status ADD VALUE IF NOT EXISTS 'awaiting_owner';

-- ---------------------------------------------------------------------------------------------
-- Catalog
-- ---------------------------------------------------------------------------------------------
ALTER TABLE public.cars
  ADD COLUMN IF NOT EXISTS transmission text,
  ADD COLUMN IF NOT EXISTS fuel_type text,
  ADD COLUMN IF NOT EXISTS equipment text[] NOT NULL DEFAULT '{}'::text[],
  ADD COLUMN IF NOT EXISTS is_new_arrival boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS availability_mode text NOT NULL DEFAULT 'always';

DO $$ BEGIN
  ALTER TABLE public.cars ADD CONSTRAINT cars_availability_mode_check CHECK (availability_mode IN ('always', 'schedule'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DROP POLICY IF EXISTS "car_images_admin_delete" ON storage.objects;
CREATE POLICY "car_images_admin_delete" ON storage.objects
  FOR DELETE USING (bucket_id = 'car-images' AND public.has_role(auth.uid(), 'admin'));

-- ---------------------------------------------------------------------------------------------
-- Requests (booking_requests is the transportation request / booking record)
-- ---------------------------------------------------------------------------------------------
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
-- Hard guarantee against double-booking a car, even under concurrent approvals.
DO $$ BEGIN
  ALTER TABLE public.booking_requests ADD CONSTRAINT booking_requests_no_overlap
    EXCLUDE USING gist (car_id WITH =, tstzrange(service_start_at, service_end_at, '[)') WITH &&)
    WHERE (car_id IS NOT NULL AND service_start_at IS NOT NULL AND service_end_at IS NOT NULL
           AND status IN ('confirmed', 'in_progress'));
EXCEPTION WHEN duplicate_object OR duplicate_table THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS booking_requests_owner_idx ON public.booking_requests (owner_id);
CREATE INDEX IF NOT EXISTS booking_requests_client_idx ON public.booking_requests (client_id);
CREATE INDEX IF NOT EXISTS booking_requests_car_window_idx ON public.booking_requests (car_id, service_start_at);

-- ---------------------------------------------------------------------------------------------
-- Owner availability
-- ---------------------------------------------------------------------------------------------
-- weekly: repeats every week on `weekday` (0 = Sunday, like extract(dow)).
-- dates: applies from date_from to date_to inclusive (single day when equal).
-- No hours = the whole day. Several rows for the same day = several periods.
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

-- ---------------------------------------------------------------------------------------------
-- Journeys and GPS
-- ---------------------------------------------------------------------------------------------
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
-- At most one running stage per booking.
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

-- Latest known position per booking (what the live map subscribes to).
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

-- ---------------------------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------------------------
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

-- Who may read a booking's journey data: admins, the client, and the assigned owner once the admin approved it.
CREATE OR REPLACE FUNCTION public.can_view_booking(_booking uuid, _user uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT _user IS NOT NULL AND (
    public.has_role(_user, 'admin')
    OR EXISTS (SELECT 1 FROM public.booking_requests b WHERE b.id = _booking AND (
      b.client_id = _user
      OR (b.owner_id = _user AND b.status::text IN ('approved', 'awaiting_owner', 'confirmed', 'in_progress', 'completed', 'cancelled')))));
$$;

-- Live position: admins, the operating owner, and the client only while their own operation is running.
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

-- ---------------------------------------------------------------------------------------------
-- Availability check (the authority used by submit, approve and confirm)
-- Returns: available | unavailable | booked | invalid | unknown
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.car_window_status(_car uuid, _start timestamptz, _end timestamptz, _ignore uuid DEFAULT NULL)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  _mode text;
  _ls timestamp;
  _le timestamp;
  _d date;
  _from time;
  _to time;
  _ok boolean;
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
    ELSIF _mode = 'always' THEN
      _ok := true;
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

-- Bookings on one car for the owner/admin calendar (no client details).
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

-- ---------------------------------------------------------------------------------------------
-- Client
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.transport_submit_request(_data jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  _uid uuid := auth.uid();
  _email text;
  _car uuid;
  _car_name text;
  _car_type text;
  _owner uuid;
  _seats int;
  _services text[];
  _cat text := _data->>'category';
  _first text := left(trim(coalesce(_data->>'first_name', '')), 80);
  _last text := left(trim(coalesce(_data->>'last_name', '')), 80);
  _phone text := trim(coalesce(_data->>'phone', ''));
  _city text := left(trim(coalesce(_data->>'city', '')), 80);
  _pickup text := left(trim(coalesce(_data->>'pickup_address', '')), 250);
  _dest text := left(trim(coalesce(_data->>'destination_address', '')), 250);
  _round boolean := coalesce((_data->>'round_trip')::boolean, false);
  _stops jsonb := coalesce(_data->'stops', '[]'::jsonb);
  _clean jsonb := '[]'::jsonb;
  st jsonb;
  _a text;
  _la double precision;
  _lo double precision;
  _date date;
  _time time;
  _ret time;
  _pass int;
  _plat double precision;
  _plng double precision;
  _dlat double precision;
  _dlng double precision;
  _start timestamptz;
  _ret_at timestamptz;
  _end timestamptz;
  _avail text := NULL;
  _ref text;
  _id uuid;
BEGIN
  IF _uid IS NULL THEN RAISE EXCEPTION 'Connexion requise'; END IF;
  IF _cat IS NULL OR _cat NOT IN ('wedding', 'family') THEN RAISE EXCEPTION 'Catégorie invalide'; END IF;
  BEGIN
    _date := (_data->>'date')::date;
    _time := (_data->>'time')::time;
    _ret := NULLIF(_data->>'return_time', '')::time;
    _pass := (_data->>'passengers')::int;
    _plat := (_data->>'pickup_lat')::double precision;
    _plng := (_data->>'pickup_lng')::double precision;
    _dlat := (_data->>'destination_lat')::double precision;
    _dlng := (_data->>'destination_lng')::double precision;
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
     OR length(coalesce(_data->>'contact_extra', '')) > 300 THEN
    RAISE EXCEPTION 'Texte trop long';
  END IF;

  IF jsonb_typeof(_stops) <> 'array' OR jsonb_array_length(_stops) > 5 THEN RAISE EXCEPTION 'Arrêts invalides (5 maximum)'; END IF;
  FOR st IN SELECT value FROM jsonb_array_elements(_stops) LOOP
    _a := left(trim(coalesce(st->>'address', '')), 250);
    BEGIN
      _la := (st->>'lat')::double precision;
      _lo := (st->>'lng')::double precision;
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
  ELSE
    _end := _start + interval '3 hours';
  END IF;

  IF _car IS NOT NULL THEN
    _avail := public.car_window_status(_car, _start, _end);
    IF _avail = 'booked' THEN RAISE EXCEPTION 'Ce véhicule est déjà réservé sur ce créneau'; END IF;
  END IF;

  LOOP
    _ref := 'F7-' || upper(substr(md5(gen_random_uuid()::text), 1, 6));
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.booking_requests WHERE reference = _ref);
  END LOOP;
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

-- ---------------------------------------------------------------------------------------------
-- Admin
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_list_owners()
RETURNS TABLE (id uuid, first_name text, last_name text, phone text, email text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM public.assert_admin();
  RETURN QUERY
    SELECT u.id, coalesce(p.first_name, ''), coalesce(p.last_name, ''), p.phone, u.email::text
    FROM auth.users u
    LEFT JOIN public.profiles p ON p.id = u.id
    WHERE EXISTS (SELECT 1 FROM public.user_roles r WHERE r.user_id = u.id AND r.role = 'partner')
       OR EXISTS (SELECT 1 FROM public.cars c WHERE c.owner_id = u.id)
    ORDER BY p.last_name, p.first_name;
END $$;

-- Internal: hold/confirm checks shared by admin and owner actions.
CREATE OR REPLACE FUNCTION public.transport_assert_slot(b public.booking_requests, _override boolean)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _avail text;
BEGIN
  IF b.car_id IS NULL OR b.owner_id IS NULL THEN RAISE EXCEPTION 'Attribuez d’abord un véhicule et son propriétaire'; END IF;
  IF b.service_start_at IS NULL OR b.service_end_at IS NULL THEN RAISE EXCEPTION 'Créneau horaire manquant'; END IF;
  -- Serialises concurrent approvals on the same car.
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
DECLARE
  b public.booking_requests%ROWTYPE;
  _from text;
  _avail text := NULL;
  _ok boolean;
  _title text;
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

  IF _status IN ('approved', 'awaiting_owner', 'confirmed') THEN
    _avail := public.transport_assert_slot(b, _override);
  END IF;

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
    UPDATE public.journey_stages SET
      status = CASE WHEN _status = 'completed' THEN 'completed' ELSE 'cancelled' END,
      ended_at = now(), ended_by = auth.uid(), notes = trim(notes || ' Clôturée par l’administration.'), updated_at = now()
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
    WHEN 'under_review' THEN 'Demande en cours d’étude'
    WHEN 'approved' THEN 'Demande approuvée'
    WHEN 'awaiting_owner' THEN 'Demande approuvée'
    WHEN 'confirmed' THEN 'Réservation confirmée'
    WHEN 'rejected' THEN 'Demande refusée'
    WHEN 'cancelled' THEN 'Demande annulée'
    WHEN 'completed' THEN 'Transport terminé'
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
DECLARE
  b public.booking_requests%ROWTYPE;
  c record;
  _new_owner uuid;
BEGIN
  PERFORM public.assert_admin();
  SELECT * INTO b FROM public.booking_requests WHERE id = _id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Demande introuvable'; END IF;
  IF b.status::text IN ('in_progress', 'completed', 'cancelled', 'rejected') THEN RAISE EXCEPTION 'Demande déjà clôturée ou en cours'; END IF;
  SELECT id, name, category, owner_id, seats INTO c FROM public.cars WHERE id = _car;
  IF NOT FOUND THEN RAISE EXCEPTION 'Véhicule introuvable'; END IF;
  _new_owner := coalesce(_owner, c.owner_id);
  IF _new_owner IS NULL THEN RAISE EXCEPTION 'Ce véhicule n’a pas de propriétaire : choisissez-en un'; END IF;
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = _new_owner) THEN RAISE EXCEPTION 'Propriétaire introuvable'; END IF;
  IF c.seats IS NOT NULL AND b.passengers > c.seats THEN RAISE EXCEPTION 'Ce véhicule n’a que % places', c.seats; END IF;

  b.car_id := c.id;
  b.owner_id := _new_owner;
  IF b.status::text IN ('approved', 'awaiting_owner', 'confirmed') THEN
    PERFORM public.transport_assert_slot(b, true);
  END IF;
  BEGIN
    UPDATE public.booking_requests SET car_id = c.id, car_name = c.name, vehicle_type = coalesce(c.category, ''), owner_id = _new_owner,
      assigned_admin_id = coalesce(assigned_admin_id, auth.uid()), updated_at = now()
    WHERE id = _id;
  EXCEPTION WHEN exclusion_violation THEN
    RAISE EXCEPTION 'Conflit : ce véhicule a déjà une réservation confirmée sur ce créneau';
  END;
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
  b.service_start_at := _start;
  b.service_end_at := _end;
  IF b.status::text IN ('approved', 'awaiting_owner', 'confirmed') THEN
    PERFORM public.transport_assert_slot(b, true);
  END IF;
  BEGIN
    UPDATE public.booking_requests SET service_start_at = _start, service_end_at = _end, updated_at = now() WHERE id = _id;
  EXCEPTION WHEN exclusion_violation THEN
    RAISE EXCEPTION 'Conflit : ce véhicule a déjà une réservation confirmée sur ce créneau';
  END;
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

-- ---------------------------------------------------------------------------------------------
-- Owner
-- ---------------------------------------------------------------------------------------------
-- Operations assigned to the calling owner. Client phone and coordination details are only shared
-- once the booking is confirmed; the client's private note to the admin is never shared.
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
    FROM public.booking_requests b
    LEFT JOIN public.cars c ON c.id = b.car_id
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
  IF b.status::text NOT IN ('approved', 'awaiting_owner') THEN RAISE EXCEPTION 'Cette réservation n’attend pas votre confirmation'; END IF;
  IF _accept THEN
    PERFORM public.transport_assert_slot(b, true);
    BEGIN
      UPDATE public.booking_requests SET status = 'confirmed', updated_at = now() WHERE id = b.id;
    EXCEPTION WHEN exclusion_violation THEN
      RAISE EXCEPTION 'Conflit : votre véhicule a déjà une réservation confirmée sur ce créneau';
    END;
    INSERT INTO public.trip_status_history (booking_request_id, status, changed_by, note) VALUES (b.id, 'confirmed', auth.uid(), 'Confirmée par le propriétaire');
    PERFORM public.notify_user(b.client_id, 'Réservation confirmée', 'Demande ' || b.reference || ' confirmée.', '/compte');
    PERFORM public.notify_admins('Réservation confirmée par le propriétaire', b.reference);
  ELSE
    IF _reason = '' THEN RAISE EXCEPTION 'Merci d’indiquer un motif'; END IF;
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

-- ---------------------------------------------------------------------------------------------
-- Journey actions (owner drives the stages; the client can signal arrival / ask for completion)
-- ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.journey_start_stage(_stage uuid, _lat double precision DEFAULT NULL, _lng double precision DEFAULT NULL, _accuracy double precision DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  s public.journey_stages%ROWTYPE;
  b public.booking_requests%ROWTYPE;
  _uid uuid := auth.uid();
  _gps boolean := public.geo_valid(_lat, _lng);
BEGIN
  SELECT booking_request_id INTO b.id FROM public.journey_stages WHERE id = _stage;
  IF b.id IS NULL THEN RAISE EXCEPTION 'Étape introuvable'; END IF;
  -- Lock the booking first: concurrent Start clicks are serialised here.
  SELECT * INTO b FROM public.booking_requests WHERE id = b.id FOR UPDATE;
  IF b.owner_id IS DISTINCT FROM _uid THEN RAISE EXCEPTION 'Seul le propriétaire assigné peut démarrer une étape'; END IF;
  SELECT * INTO s FROM public.journey_stages WHERE id = _stage FOR UPDATE;
  IF s.status IN ('in_progress', 'completed') THEN RETURN jsonb_build_object('stage', to_jsonb(s), 'already', true); END IF;
  IF s.status <> 'pending' THEN RAISE EXCEPTION 'Cette étape n’est plus disponible'; END IF;
  IF b.status::text NOT IN ('confirmed', 'in_progress') THEN RAISE EXCEPTION 'La réservation doit être confirmée avant le départ'; END IF;
  IF b.service_start_at IS NOT NULL AND now() < b.service_start_at - interval '12 hours' THEN
    RAISE EXCEPTION 'Trop tôt : le départ est prévu le %', to_char(b.service_start_at AT TIME ZONE 'Africa/Tunis', 'DD/MM/YYYY HH24:MI');
  END IF;
  IF EXISTS (SELECT 1 FROM public.journey_stages WHERE booking_request_id = b.id AND stage_no < s.stage_no AND status NOT IN ('completed', 'skipped')) THEN
    RAISE EXCEPTION 'Terminez d’abord l’étape précédente';
  END IF;
  IF EXISTS (SELECT 1 FROM public.journey_stages WHERE booking_request_id = b.id AND status = 'in_progress') THEN
    RAISE EXCEPTION 'Une autre étape est déjà en cours';
  END IF;
  IF _lat IS NOT NULL AND NOT _gps THEN RAISE EXCEPTION 'Coordonnées GPS invalides'; END IF;

  UPDATE public.journey_stages SET status = 'in_progress', started_at = now(), started_by = _uid,
    start_lat = CASE WHEN _gps THEN _lat END, start_lng = CASE WHEN _gps THEN _lng END,
    start_accuracy = CASE WHEN _gps THEN _accuracy END, updated_at = now()
  WHERE id = s.id RETURNING * INTO s;

  IF b.status::text = 'confirmed' THEN
    UPDATE public.booking_requests SET status = 'in_progress', updated_at = now() WHERE id = b.id;
    INSERT INTO public.trip_status_history (booking_request_id, status, changed_by, note) VALUES (b.id, 'in_progress', _uid, 'Départ de l’étape ' || s.stage_no);
  END IF;

  INSERT INTO public.journey_events (booking_request_id, stage_id, event_type, actor_id, actor_role, lat, lng, accuracy, note)
    VALUES (b.id, s.id, 'stage_started', _uid, 'owner', s.start_lat, s.start_lng, s.start_accuracy, CASE WHEN _gps THEN '' ELSE 'GPS indisponible au départ' END);

  INSERT INTO public.live_locations AS l (booking_request_id, stage_id, owner_id, lat, lng, accuracy, recorded_at, received_at, tracking, updated_at)
    VALUES (b.id, s.id, _uid, s.start_lat, s.start_lng, s.start_accuracy, CASE WHEN _gps THEN now() END, CASE WHEN _gps THEN now() END, true, now())
  ON CONFLICT (booking_request_id) DO UPDATE SET stage_id = EXCLUDED.stage_id, owner_id = EXCLUDED.owner_id, tracking = true, updated_at = now(),
    lat = coalesce(EXCLUDED.lat, l.lat), lng = coalesce(EXCLUDED.lng, l.lng), accuracy = coalesce(EXCLUDED.accuracy, l.accuracy),
    recorded_at = coalesce(EXCLUDED.recorded_at, l.recorded_at), received_at = coalesce(EXCLUDED.received_at, l.received_at);
  IF _gps THEN
    INSERT INTO public.gps_location_updates (booking_request_id, stage_id, owner_id, lat, lng, accuracy, source, recorded_at)
      VALUES (b.id, s.id, _uid, _lat, _lng, _accuracy, 'stage_start', now());
  END IF;

  PERFORM public.notify_admins('Départ : étape ' || s.stage_no, b.reference || ' · ' || s.from_address || ' → ' || s.to_address);
  PERFORM public.notify_user(b.client_id, 'Votre trajet a commencé', 'Demande ' || b.reference || ' : étape ' || s.stage_no || ' en cours.', '/compte');
  RETURN jsonb_build_object('stage', to_jsonb(s), 'already', false);
END $$;

CREATE OR REPLACE FUNCTION public.journey_end_stage(_stage uuid, _lat double precision DEFAULT NULL, _lng double precision DEFAULT NULL, _accuracy double precision DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  s public.journey_stages%ROWTYPE;
  b public.booking_requests%ROWTYPE;
  _uid uuid := auth.uid();
  _gps boolean := public.geo_valid(_lat, _lng);
  _done boolean;
BEGIN
  SELECT booking_request_id INTO b.id FROM public.journey_stages WHERE id = _stage;
  IF b.id IS NULL THEN RAISE EXCEPTION 'Étape introuvable'; END IF;
  SELECT * INTO b FROM public.booking_requests WHERE id = b.id FOR UPDATE;
  IF b.owner_id IS DISTINCT FROM _uid THEN RAISE EXCEPTION 'Seul le propriétaire assigné peut terminer une étape'; END IF;
  SELECT * INTO s FROM public.journey_stages WHERE id = _stage FOR UPDATE;
  IF s.status = 'completed' THEN RETURN jsonb_build_object('stage', to_jsonb(s), 'already', true, 'operation_completed', b.status::text = 'completed'); END IF;
  IF s.status <> 'in_progress' THEN RAISE EXCEPTION 'Cette étape n’a pas démarré'; END IF;
  IF _lat IS NOT NULL AND NOT _gps THEN RAISE EXCEPTION 'Coordonnées GPS invalides'; END IF;

  UPDATE public.journey_stages SET status = 'completed', ended_at = now(), ended_by = _uid,
    end_lat = CASE WHEN _gps THEN _lat END, end_lng = CASE WHEN _gps THEN _lng END,
    end_accuracy = CASE WHEN _gps THEN _accuracy END, updated_at = now()
  WHERE id = s.id RETURNING * INTO s;

  INSERT INTO public.journey_events (booking_request_id, stage_id, event_type, actor_id, actor_role, lat, lng, accuracy, note)
    VALUES (b.id, s.id, 'stage_ended', _uid, 'owner', s.end_lat, s.end_lng, s.end_accuracy, CASE WHEN _gps THEN '' ELSE 'GPS indisponible à l’arrivée' END);
  IF _gps THEN
    INSERT INTO public.gps_location_updates (booking_request_id, stage_id, owner_id, lat, lng, accuracy, source, recorded_at)
      VALUES (b.id, s.id, _uid, _lat, _lng, _accuracy, 'stage_end', now());
  END IF;
  -- Tracking pauses between stages and stops for good after the last one.
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
DECLARE
  s public.journey_stages%ROWTYPE;
  b public.booking_requests%ROWTYPE;
BEGIN
  SELECT booking_request_id INTO b.id FROM public.journey_stages WHERE id = _stage;
  IF b.id IS NULL THEN RAISE EXCEPTION 'Étape introuvable'; END IF;
  SELECT * INTO b FROM public.booking_requests WHERE id = b.id FOR UPDATE;
  IF b.owner_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Non autorisé'; END IF;
  SELECT * INTO s FROM public.journey_stages WHERE id = _stage FOR UPDATE;
  IF s.status <> 'in_progress' THEN RAISE EXCEPTION 'Cette étape n’est pas en cours'; END IF;
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
DECLARE
  s public.journey_stages%ROWTYPE;
  b public.booking_requests%ROWTYPE;
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
  PERFORM public.notify_admins(CASE WHEN _kind = 'arrival_confirmed' THEN 'Arrivée confirmée par le client' ELSE 'Le client demande la fin de l’étape' END, b.reference || ' · étape ' || s.stage_no);
  PERFORM public.notify_user(b.owner_id, CASE WHEN _kind = 'arrival_confirmed' THEN 'Arrivée confirmée par le client' ELSE 'Le client demande la fin de l’étape' END, b.reference || ' · étape ' || s.stage_no, '/partenaire');
  RETURN jsonb_build_object('already', false);
END $$;

-- GPS position from the operating owner's device. Accepted only while a stage is running.
CREATE OR REPLACE FUNCTION public.journey_push_location(
  _booking uuid, _lat double precision, _lng double precision, _accuracy double precision DEFAULT NULL,
  _heading double precision DEFAULT NULL, _speed double precision DEFAULT NULL, _recorded_at timestamptz DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  b record;
  _stage uuid;
  l public.live_locations%ROWTYPE;
  _rec timestamptz := least(coalesce(_recorded_at, now()), now());
  _dt double precision;
  _dist double precision;
BEGIN
  SELECT id, owner_id, status::text AS status INTO b FROM public.booking_requests WHERE id = _booking;
  IF NOT FOUND OR b.owner_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Non autorisé'; END IF;
  IF b.status <> 'in_progress' THEN RETURN jsonb_build_object('accepted', false, 'reason', 'not_active', 'tracking', false); END IF;
  SELECT id INTO _stage FROM public.journey_stages WHERE booking_request_id = _booking AND status = 'in_progress';
  IF _stage IS NULL THEN RETURN jsonb_build_object('accepted', false, 'reason', 'no_active_stage', 'tracking', false); END IF;
  IF NOT public.geo_valid(_lat, _lng) THEN RETURN jsonb_build_object('accepted', false, 'reason', 'invalid', 'tracking', true); END IF;
  IF _accuracy IS NOT NULL AND (_accuracy < 0 OR _accuracy > 1500) THEN
    RETURN jsonb_build_object('accepted', false, 'reason', 'inaccurate', 'tracking', true);
  END IF;
  IF _rec < now() - interval '30 minutes' THEN RETURN jsonb_build_object('accepted', false, 'reason', 'stale', 'tracking', true); END IF;

  SELECT * INTO l FROM public.live_locations WHERE booking_request_id = _booking FOR UPDATE;
  IF FOUND AND l.received_at IS NOT NULL AND l.received_at > now() - interval '2 seconds' THEN
    RETURN jsonb_build_object('accepted', false, 'reason', 'throttled', 'tracking', true);
  END IF;
  IF FOUND AND public.geo_valid(l.lat, l.lng) AND l.recorded_at IS NOT NULL AND _rec > l.recorded_at THEN
    _dt := extract(epoch FROM _rec - l.recorded_at);
    _dist := public.geo_distance_m(l.lat, l.lng, _lat, _lng);
    -- Faster than ~320 km/h beyond the reported accuracy is a GPS glitch, not a car.
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

-- Catalog changes made directly by admins through RLS are audited too.
CREATE OR REPLACE FUNCTION public.cars_audit_trigger()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND public.has_role(auth.uid(), 'admin') THEN
    IF TG_OP = 'DELETE' THEN
      PERFORM public.audit('car_delete', 'car', OLD.id, jsonb_build_object('name', OLD.name));
    ELSE
      PERFORM public.audit('car_' || lower(TG_OP), 'car', NEW.id, jsonb_build_object('name', NEW.name, 'active', NEW.active));
    END IF;
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS cars_audit ON public.cars;
CREATE TRIGGER cars_audit AFTER INSERT OR UPDATE OR DELETE ON public.cars FOR EACH ROW EXECUTE FUNCTION public.cars_audit_trigger();

-- Deleting a car would silently detach it from bookings that still hold its time slot.
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

-- ---------------------------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------------------------
ALTER TABLE public.car_availability_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journey_stages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journey_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gps_location_updates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Availability owner or admin" ON public.car_availability_rules;
CREATE POLICY "Availability owner or admin" ON public.car_availability_rules FOR ALL
  USING (public.has_role(auth.uid(), 'admin') OR EXISTS (SELECT 1 FROM public.cars c WHERE c.id = car_id AND c.owner_id = auth.uid()))
  WITH CHECK (public.has_role(auth.uid(), 'admin') OR EXISTS (SELECT 1 FROM public.cars c WHERE c.id = car_id AND c.owner_id = auth.uid()));

DROP POLICY IF EXISTS "Journey stages participants" ON public.journey_stages;
CREATE POLICY "Journey stages participants" ON public.journey_stages FOR SELECT USING (public.can_view_booking(booking_request_id, auth.uid()));

DROP POLICY IF EXISTS "Journey events participants" ON public.journey_events;
CREATE POLICY "Journey events participants" ON public.journey_events FOR SELECT USING (public.can_view_booking(booking_request_id, auth.uid()));

DROP POLICY IF EXISTS "GPS history admin or owner" ON public.gps_location_updates;
CREATE POLICY "GPS history admin or owner" ON public.gps_location_updates FOR SELECT USING (
  public.has_role(auth.uid(), 'admin') OR EXISTS (SELECT 1 FROM public.booking_requests b WHERE b.id = booking_request_id AND b.owner_id = auth.uid()));

DROP POLICY IF EXISTS "Live location authorised viewers" ON public.live_locations;
CREATE POLICY "Live location authorised viewers" ON public.live_locations FOR SELECT USING (public.can_view_live_location(booking_request_id, auth.uid()));

DROP POLICY IF EXISTS "Audit admin read" ON public.audit_log;
CREATE POLICY "Audit admin read" ON public.audit_log FOR SELECT USING (public.has_role(auth.uid(), 'admin'));

REVOKE ALL ON public.car_availability_rules, public.journey_stages, public.journey_events,
  public.gps_location_updates, public.live_locations, public.audit_log FROM anon;
GRANT SELECT ON public.journey_stages, public.journey_events, public.gps_location_updates, public.live_locations, public.audit_log TO authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.journey_stages, public.journey_events, public.gps_location_updates, public.live_locations, public.audit_log FROM authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.car_availability_rules TO authenticated;

-- ---------------------------------------------------------------------------------------------
-- Function privileges
-- ---------------------------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------------------------
-- Realtime (Supabase applies the RLS policies above to every subscriber)
-- ---------------------------------------------------------------------------------------------
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
