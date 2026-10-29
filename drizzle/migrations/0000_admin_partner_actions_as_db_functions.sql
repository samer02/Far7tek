-- Admin and partner actions as database functions so they work on any hosting (no server secret needed).

CREATE OR REPLACE FUNCTION public.assert_admin()
RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT public.has_role(auth.uid(), 'admin') THEN
    RAISE EXCEPTION 'Accès réservé aux administrateurs';
  END IF;
END $$;

-- Links approved applications to the account using the same (confirmed) e-mail.
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
REVOKE ALL ON FUNCTION public.link_partner_account(uuid) FROM PUBLIC, anon, authenticated;

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
REVOKE ALL ON FUNCTION public.on_auth_user_confirmed() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS far7tek_partner_link ON auth.users;
CREATE TRIGGER far7tek_partner_link
  AFTER INSERT OR UPDATE OF email_confirmed_at ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.on_auth_user_confirmed();

-- Signed-in user can claim their own approved application (e.g. account created before approval).
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