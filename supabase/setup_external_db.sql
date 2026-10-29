-- ==============================================================================
-- Far7tek / Mariage & Transport Privé - Schéma complet Supabase
-- Exécutez ce script dans : Supabase Studio -> SQL Editor -> New Query -> Run
-- ==============================================================================

-- 1. Extensions nécessaires
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. Types Énumérés (Enums)
DO $$ BEGIN
  CREATE TYPE public.app_role AS ENUM ('admin', 'editor', 'partner');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE public.booking_status AS ENUM (
    'new', 'contacted', 'pending', 'confirmed', 'cancelled', 'accepted', 'rejected', 'in_progress', 'completed'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE public.proposal_status AS ENUM (
    'new', 'reviewing', 'accepted', 'rejected', 'pending', 'info_requested', 'approved'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- 3. Tables principales

-- PROFILES
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name TEXT DEFAULT '' NOT NULL,
  last_name TEXT DEFAULT '' NOT NULL,
  phone TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- USER ROLES
CREATE TABLE IF NOT EXISTS public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.app_role NOT NULL,
  CONSTRAINT user_roles_user_id_role_key UNIQUE (user_id, role)
);

-- CARS
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

-- CAR IMAGES
CREATE TABLE IF NOT EXISTS public.car_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  car_id UUID NOT NULL REFERENCES public.cars(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL,
  alt_text TEXT NOT NULL DEFAULT '',
  is_cover BOOLEAN NOT NULL DEFAULT false,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- CAR VIDEOS
CREATE TABLE IF NOT EXISTS public.car_videos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  car_id UUID NOT NULL REFERENCES public.cars(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL,
  title TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- CAR PROPOSALS
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

-- PROPOSAL IMAGES
CREATE TABLE IF NOT EXISTS public.proposal_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proposal_id UUID NOT NULL REFERENCES public.car_proposals(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL,
  kind TEXT NOT NULL DEFAULT 'exterior',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- BOOKING REQUESTS
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

-- TRIP ASSIGNMENTS
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

-- TRIP STATUS HISTORY
CREATE TABLE IF NOT EXISTS public.trip_status_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_request_id UUID NOT NULL REFERENCES public.booking_requests(id) ON DELETE CASCADE,
  status TEXT NOT NULL,
  changed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  note TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- VEHICLE CHANGE REQUESTS
CREATE TABLE IF NOT EXISTS public.vehicle_change_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  car_id UUID NOT NULL REFERENCES public.cars(id) ON DELETE CASCADE,
  partner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  changes JSONB NOT NULL DEFAULT '{}'::jsonb,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ADMIN NOTES
CREATE TABLE IF NOT EXISTS public.admin_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  booking_request_id UUID REFERENCES public.booking_requests(id) ON DELETE CASCADE,
  car_proposal_id UUID REFERENCES public.car_proposals(id) ON DELETE CASCADE,
  note TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- NOTIFICATIONS
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

-- GALLERY
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

-- 4. Fonctions de Sécurité de Base

CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role app_role)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role
  );
$$;

CREATE OR REPLACE FUNCTION public.is_assigned_partner(_booking uuid, _user uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.trip_assignments
    WHERE booking_request_id = _booking AND partner_id = _user AND status = 'accepted'
  );
$$;

CREATE OR REPLACE FUNCTION public.assert_admin()
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT public.has_role(auth.uid(), 'admin') THEN
    RAISE EXCEPTION 'Accès réservé aux administrateurs';
  END IF;
END $$;

-- 5. Fonctions Métier (Partenaires, Réservations, Administration)

CREATE OR REPLACE FUNCTION public.link_partner_account(_user uuid)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  _email text;
  _n integer := 0;
  p record;
BEGIN
  SELECT email INTO _email FROM auth.users WHERE id = _user AND email_confirmed_at IS NOT NULL;
  IF _email IS NULL THEN RETURN 0; END IF;
  FOR p IN SELECT * FROM public.car_proposals
           WHERE status = 'approved' AND partner_user_id IS NULL AND lower(email) = lower(_email)
  LOOP
    UPDATE public.car_proposals SET partner_user_id = _user, updated_at = now() WHERE id = p.id;
    IF p.car_id IS NOT NULL THEN
      UPDATE public.cars SET owner_id = _user, updated_at = now() WHERE id = p.car_id AND owner_id IS NULL;
    END IF;
    INSERT INTO public.profiles (id, first_name, last_name, phone)
      VALUES (_user, p.first_name, p.last_name, p.phone)
      ON CONFLICT (id) DO UPDATE SET
        first_name = CASE WHEN profiles.first_name = '' THEN EXCLUDED.first_name ELSE profiles.first_name END,
        last_name = CASE WHEN profiles.last_name = '' THEN EXCLUDED.last_name ELSE profiles.last_name END,
        phone = COALESCE(profiles.phone, EXCLUDED.phone);
    INSERT INTO public.notifications (user_id, title, body, link)
      VALUES (_user, 'Dossier accepté', 'Bienvenue parmi nos partenaires. Votre véhicule sera publié après validation finale.', '/partenaire');
    _n := _n + 1;
  END LOOP;
  IF _n > 0 THEN
    INSERT INTO public.user_roles (user_id, role) VALUES (_user, 'partner') ON CONFLICT (user_id, role) DO NOTHING;
  END IF;
  RETURN _n;
END $$;

CREATE OR REPLACE FUNCTION public.on_auth_user_confirmed()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.email_confirmed_at IS NOT NULL THEN
    BEGIN
      PERFORM public.link_partner_account(NEW.id);
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'link_partner_account failed: %', SQLERRM;
    END;
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

CREATE OR REPLACE FUNCTION public.admin_approve_partner(_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  p public.car_proposals%ROWTYPE;
  _car uuid;
  _uid uuid;
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
  IF _uid IS NOT NULL THEN
    PERFORM public.link_partner_account(_uid);
  END IF;

  RETURN jsonb_build_object('car_id', _car, 'linked', _uid IS NOT NULL, 'email', p.email, 'already', false);
END $$;

CREATE OR REPLACE FUNCTION public.admin_review_partner(_id uuid, _action text, _message text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM public.assert_admin();
  _message := trim(coalesce(_message, ''));
  IF _action NOT IN ('reject', 'info', 'reviewing') THEN RAISE EXCEPTION 'Action inconnue'; END IF;
  IF _action <> 'reviewing' AND _message = '' THEN RAISE EXCEPTION 'Merci d’indiquer un motif ou un message'; END IF;
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
  IF NOT public.has_role(_partner, 'partner') THEN RAISE EXCEPTION 'Ce partenaire n’a pas encore activé son compte'; END IF;
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
    FROM auth.users u
    ORDER BY u.created_at DESC
    LIMIT 1000;
END $$;

CREATE OR REPLACE FUNCTION public.partner_respond_assignment(_id uuid, _accept boolean, _reason text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE a public.trip_assignments%ROWTYPE; b record;
BEGIN
  _reason := trim(coalesce(_reason, ''));
  SELECT * INTO a FROM public.trip_assignments WHERE id = _id FOR UPDATE;
  IF NOT FOUND OR a.partner_id <> auth.uid() THEN RAISE EXCEPTION 'Demande introuvable'; END IF;
  IF a.status <> 'proposed' THEN RAISE EXCEPTION 'Demande déjà traitée'; END IF;
  IF NOT _accept AND _reason = '' THEN RAISE EXCEPTION 'Merci d’indiquer un motif de refus'; END IF;
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
    RAISE EXCEPTION 'Vous devez d’abord accepter cette demande';
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

-- Permissions d'exécution
REVOKE ALL ON FUNCTION public.has_role(uuid, app_role) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO anon, authenticated;

REVOKE ALL ON FUNCTION public.is_assigned_partner(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_assigned_partner(uuid, uuid) TO anon, authenticated;

REVOKE ALL ON FUNCTION public.assert_admin() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.claim_partner_account() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_approve_partner(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_review_partner(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_set_car_validation(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_assign_trip(uuid, uuid, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_set_booking_status(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_review_change_request(uuid, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_list_clients() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.partner_respond_assignment(uuid, boolean, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.partner_update_trip_status(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.partner_update_car_availability(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.partner_add_car_photo(uuid, text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.assert_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_partner_account() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_approve_partner(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_partner(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_car_validation(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_assign_trip(uuid, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_booking_status(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_change_request(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_clients() TO authenticated;
GRANT EXECUTE ON FUNCTION public.partner_respond_assignment(uuid, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.partner_update_trip_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.partner_update_car_availability(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.partner_add_car_photo(uuid, text) TO authenticated;

-- 6. Politiques de Sécurité (Row Level Security - RLS)

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

-- Politiques PROFILES
DROP POLICY IF EXISTS "Profiles visible by owners and admins" ON public.profiles;
CREATE POLICY "Profiles visible by owners and admins" ON public.profiles
  FOR SELECT USING (auth.uid() = id OR public.has_role(auth.uid(), 'admin'));

DROP POLICY IF EXISTS "Profiles editable by owners" ON public.profiles;
CREATE POLICY "Profiles editable by owners" ON public.profiles
  FOR ALL USING (auth.uid() = id);

-- Politiques USER_ROLES
DROP POLICY IF EXISTS "Roles readable by owners and admins" ON public.user_roles;
CREATE POLICY "Roles readable by owners and admins" ON public.user_roles
  FOR SELECT USING (auth.uid() = user_id OR public.has_role(auth.uid(), 'admin'));

-- Politiques CARS
DROP POLICY IF EXISTS "Cars public read active" ON public.cars;
CREATE POLICY "Cars public read active" ON public.cars
  FOR SELECT USING (active = true OR owner_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

DROP POLICY IF EXISTS "Cars admin all" ON public.cars;
CREATE POLICY "Cars admin all" ON public.cars
  FOR ALL USING (public.has_role(auth.uid(), 'admin'));

-- Politiques CAR IMAGES & VIDEOS
DROP POLICY IF EXISTS "Car media public read" ON public.car_images;
CREATE POLICY "Car media public read" ON public.car_images FOR SELECT USING (true);

DROP POLICY IF EXISTS "Car media admin all" ON public.car_images;
CREATE POLICY "Car media admin all" ON public.car_images FOR ALL USING (public.has_role(auth.uid(), 'admin'));

DROP POLICY IF EXISTS "Car videos public read" ON public.car_videos;
CREATE POLICY "Car videos public read" ON public.car_videos FOR SELECT USING (true);

DROP POLICY IF EXISTS "Car videos admin all" ON public.car_videos;
CREATE POLICY "Car videos admin all" ON public.car_videos FOR ALL USING (public.has_role(auth.uid(), 'admin'));

-- Politiques CAR PROPOSALS
DROP POLICY IF EXISTS "Anyone can submit car proposals" ON public.car_proposals;
CREATE POLICY "Anyone can submit car proposals" ON public.car_proposals
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Proposals viewable by submitter or partner or admin" ON public.car_proposals;
CREATE POLICY "Proposals viewable by submitter or partner or admin" ON public.car_proposals
  FOR SELECT USING (user_id = auth.uid() OR partner_user_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

DROP POLICY IF EXISTS "Proposals admin all" ON public.car_proposals;
CREATE POLICY "Proposals admin all" ON public.car_proposals
  FOR ALL USING (public.has_role(auth.uid(), 'admin'));

-- Politiques PROPOSAL IMAGES
DROP POLICY IF EXISTS "Proposal images insertable" ON public.proposal_images;
CREATE POLICY "Proposal images insertable" ON public.proposal_images FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Proposal images select" ON public.proposal_images;
CREATE POLICY "Proposal images select" ON public.proposal_images
  FOR SELECT USING (public.has_role(auth.uid(), 'admin') OR EXISTS (
    SELECT 1 FROM public.car_proposals p WHERE p.id = proposal_id AND (p.user_id = auth.uid() OR p.partner_user_id = auth.uid())
  ));

-- Politiques BOOKING REQUESTS
DROP POLICY IF EXISTS "Anyone can create bookings" ON public.booking_requests;
CREATE POLICY "Anyone can create bookings" ON public.booking_requests FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Bookings viewable by client, assigned partner, or admin" ON public.booking_requests;
CREATE POLICY "Bookings viewable by client, assigned partner, or admin" ON public.booking_requests
  FOR SELECT USING (
    client_id = auth.uid() OR
    public.has_role(auth.uid(), 'admin') OR
    public.is_assigned_partner(id, auth.uid())
  );

DROP POLICY IF EXISTS "Bookings admin all" ON public.booking_requests;
CREATE POLICY "Bookings admin all" ON public.booking_requests FOR ALL USING (public.has_role(auth.uid(), 'admin'));

-- Politiques TRIP ASSIGNMENTS
DROP POLICY IF EXISTS "Trip assignments partner or admin" ON public.trip_assignments;
CREATE POLICY "Trip assignments partner or admin" ON public.trip_assignments
  FOR ALL USING (partner_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

-- Politiques TRIP STATUS HISTORY
DROP POLICY IF EXISTS "Trip history select" ON public.trip_status_history;
CREATE POLICY "Trip history select" ON public.trip_status_history
  FOR SELECT USING (
    public.has_role(auth.uid(), 'admin') OR
    EXISTS (SELECT 1 FROM public.booking_requests b WHERE b.id = booking_request_id AND b.client_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.trip_assignments a WHERE a.booking_request_id = booking_request_id AND a.partner_id = auth.uid())
  );

-- Politiques NOTIFICATIONS
DROP POLICY IF EXISTS "Notifications viewable by target user or admin" ON public.notifications;
CREATE POLICY "Notifications viewable by target user or admin" ON public.notifications
  FOR SELECT USING (user_id = auth.uid() OR (audience = 'admin' AND public.has_role(auth.uid(), 'admin')));

DROP POLICY IF EXISTS "Notifications updateable by target user" ON public.notifications;
CREATE POLICY "Notifications updateable by target user" ON public.notifications
  FOR UPDATE USING (user_id = auth.uid());

-- Politiques ADMIN NOTES
DROP POLICY IF EXISTS "Admin notes admin only" ON public.admin_notes;
CREATE POLICY "Admin notes admin only" ON public.admin_notes FOR ALL USING (public.has_role(auth.uid(), 'admin'));

-- Politiques VEHICLE CHANGE REQUESTS
DROP POLICY IF EXISTS "Change requests partner or admin" ON public.vehicle_change_requests;
CREATE POLICY "Change requests partner or admin" ON public.vehicle_change_requests
  FOR ALL USING (partner_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

-- Politiques GALLERY
DROP POLICY IF EXISTS "Gallery public read" ON public.gallery;
CREATE POLICY "Gallery public read" ON public.gallery FOR SELECT USING (active = true OR public.has_role(auth.uid(), 'admin'));

DROP POLICY IF EXISTS "Gallery admin all" ON public.gallery;
CREATE POLICY "Gallery admin all" ON public.gallery FOR ALL USING (public.has_role(auth.uid(), 'admin'));

-- 7. Buckets de Stockage Supabase

INSERT INTO storage.buckets (id, name, public)
VALUES ('car-images', 'car-images', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('proposal-images', 'proposal-images', false)
ON CONFLICT (id) DO NOTHING;

-- Politiques Storage pour car-images (public en lecture)
DROP POLICY IF EXISTS "car_images_public_read" ON storage.objects;
CREATE POLICY "car_images_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'car-images');

DROP POLICY IF EXISTS "car_images_partner_upload" ON storage.objects;
CREATE POLICY "car_images_partner_upload" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'car-images' AND (auth.role() = 'authenticated' OR auth.role() = 'service_role'));

-- Politiques Storage pour proposal-images
DROP POLICY IF EXISTS "proposal_images_upload" ON storage.objects;
CREATE POLICY "proposal_images_upload" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'proposal-images');

DROP POLICY IF EXISTS "proposal_images_read" ON storage.objects;
CREATE POLICY "proposal_images_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'proposal-images' AND (auth.role() = 'authenticated' OR auth.role() = 'service_role'));

-- 8. Données Initiales (Véhicules de démonstration)

INSERT INTO public.cars (id, name, brand, model, slug, year, color, category, short_description, description, price_from, availability, active, featured, sort_order, validation_status, seats, city, services)
VALUES
(
  '07ac7bf9-41db-4763-9b8e-5cf33c2c1a0d',
  'Rolls-Royce Ghost',
  'Rolls-Royce',
  'Ghost',
  'rolls-royce-ghost',
  2022,
  'Blanc nacré',
  'Berline de prestige',
  'Silence absolu et élégance intemporelle pour l''arrivée des mariés.',
  'Berline d''exception avec intérieur cuir crème, idéale pour le cortège des mariés. Décoration florale possible sur demande.',
  1500.00,
  'Week-ends et jours fériés',
  true,
  true,
  1,
  'active',
  4,
  'Sfax',
  ARRAY['wedding', 'event']
),
(
  '1d2048d8-24e6-4cee-8eca-9b8623d4a12d',
  'Mercedes-Maybach S680',
  'Mercedes-Maybach',
  'S680',
  'maybach-s680',
  2023,
  'Noir obsidienne',
  'Berline de prestige',
  'Confort de première classe pour les mariés et leurs proches.',
  'Limousine de luxe avec sièges arrière inclinables, parfaite pour les trajets vers la salle des fêtes.',
  1200.00,
  'Toute l''année',
  true,
  true,
  2,
  'active',
  4,
  'Tunis',
  ARRAY['wedding', 'family', 'private']
),
(
  'c780f696-3e6b-44ef-9305-f4a4f92a4ebd',
  'Jaguar Mark II',
  'Jaguar',
  'Mark II',
  'jaguar-mark-ii',
  1962,
  'Ivoire',
  'Voiture de collection',
  'Le charme rétro d''une icône des années 60.',
  'Voiture de collection restaurée, pour des photos de mariage inoubliables et une arrivée remarquée.',
  900.00,
  'Avril à octobre',
  true,
  false,
  3,
  'active',
  4,
  'Sousse',
  ARRAY['wedding', 'event']
)
ON CONFLICT (id) DO NOTHING;

