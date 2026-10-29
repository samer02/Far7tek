-- Client requests
ALTER TABLE public.booking_requests
  ADD COLUMN client_id uuid,
  ADD COLUMN pickup_address text NOT NULL DEFAULT '',
  ADD COLUMN destination_type text NOT NULL DEFAULT '',
  ADD COLUMN return_time time,
  ADD COLUMN passengers integer NOT NULL DEFAULT 1,
  ADD COLUMN vehicle_type text NOT NULL DEFAULT '',
  ADD COLUMN trip_type text NOT NULL DEFAULT 'one_way',
  ADD COLUMN reference text NOT NULL DEFAULT upper(substr(md5(random()::text),1,8));
ALTER TABLE public.booking_requests ALTER COLUMN status SET DEFAULT 'pending';
CREATE INDEX IF NOT EXISTS booking_requests_client_idx ON public.booking_requests(client_id);

CREATE POLICY "Clients create own requests" ON public.booking_requests FOR INSERT TO authenticated
  WITH CHECK (client_id = auth.uid() AND status = 'pending');
CREATE POLICY "Clients read own requests" ON public.booking_requests FOR SELECT TO authenticated
  USING (client_id = auth.uid());

-- Partner applications
ALTER TABLE public.car_proposals
  ADD COLUMN user_id uuid,
  ADD COLUMN address text NOT NULL DEFAULT '',
  ADD COLUMN extra_info text NOT NULL DEFAULT '',
  ADD COLUMN seats integer NOT NULL DEFAULT 4,
  ADD COLUMN vehicle_condition text NOT NULL DEFAULT '',
  ADD COLUMN services text[] NOT NULL DEFAULT '{}',
  ADD COLUMN rejection_reason text,
  ADD COLUMN info_request text,
  ADD COLUMN partner_user_id uuid,
  ADD COLUMN car_id uuid REFERENCES public.cars(id);
ALTER TABLE public.car_proposals ALTER COLUMN desired_rate SET DEFAULT 0;
ALTER TABLE public.car_proposals ALTER COLUMN status SET DEFAULT 'pending';
CREATE POLICY "Guests create pending proposals" ON public.car_proposals FOR INSERT TO anon, authenticated
  WITH CHECK (status = 'pending' AND partner_user_id IS NULL AND car_id IS NULL);

ALTER TABLE public.proposal_images ADD COLUMN kind text NOT NULL DEFAULT 'exterior';

-- Vehicles
ALTER TABLE public.cars
  ADD COLUMN owner_id uuid,
  ADD COLUMN validation_status text NOT NULL DEFAULT 'active',
  ADD COLUMN seats integer,
  ADD COLUMN city text,
  ADD COLUMN services text[] NOT NULL DEFAULT '{}';
CREATE INDEX IF NOT EXISTS cars_owner_idx ON public.cars(owner_id);
CREATE POLICY "Partners read own cars" ON public.cars FOR SELECT TO authenticated USING (owner_id = auth.uid());
CREATE POLICY "Partners read own car images" ON public.car_images FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.cars c WHERE c.id = car_images.car_id AND c.owner_id = auth.uid()));

-- Assignments
CREATE TABLE public.trip_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_request_id uuid NOT NULL REFERENCES public.booking_requests(id) ON DELETE CASCADE,
  partner_id uuid NOT NULL,
  car_id uuid REFERENCES public.cars(id),
  status text NOT NULL DEFAULT 'proposed',
  rejection_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.trip_assignments TO authenticated;
GRANT ALL ON public.trip_assignments TO service_role;
ALTER TABLE public.trip_assignments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins manage assignments" ON public.trip_assignments FOR ALL TO authenticated
  USING (public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'admin'));
CREATE POLICY "Partners read own assignments" ON public.trip_assignments FOR SELECT TO authenticated
  USING (partner_id = auth.uid());
GRANT INSERT, UPDATE, DELETE ON public.trip_assignments TO authenticated;

CREATE OR REPLACE FUNCTION public.is_assigned_partner(_booking uuid, _user uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.trip_assignments WHERE booking_request_id = _booking AND partner_id = _user AND status <> 'rejected')
$$;
CREATE POLICY "Partners read assigned requests" ON public.booking_requests FOR SELECT TO authenticated
  USING (public.is_assigned_partner(id, auth.uid()));

-- Status history
CREATE TABLE public.trip_status_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_request_id uuid NOT NULL REFERENCES public.booking_requests(id) ON DELETE CASCADE,
  status text NOT NULL,
  changed_by uuid,
  note text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.trip_status_history TO authenticated;
GRANT ALL ON public.trip_status_history TO service_role;
ALTER TABLE public.trip_status_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Read history of visible requests" ON public.trip_status_history FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(),'admin') OR public.is_assigned_partner(booking_request_id, auth.uid())
    OR EXISTS (SELECT 1 FROM public.booking_requests b WHERE b.id = booking_request_id AND b.client_id = auth.uid()));

-- Notifications
CREATE TABLE public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid,
  audience text NOT NULL DEFAULT 'user',
  title text NOT NULL,
  body text NOT NULL DEFAULT '',
  link text,
  read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, UPDATE ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Read own notifications" ON public.notifications FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR (audience = 'admin' AND public.has_role(auth.uid(),'admin')));
CREATE POLICY "Mark own notifications" ON public.notifications FOR UPDATE TO authenticated
  USING (user_id = auth.uid() OR (audience = 'admin' AND public.has_role(auth.uid(),'admin')))
  WITH CHECK (user_id = auth.uid() OR (audience = 'admin' AND public.has_role(auth.uid(),'admin')));

-- Vehicle change requests
CREATE TABLE public.vehicle_change_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  car_id uuid NOT NULL REFERENCES public.cars(id) ON DELETE CASCADE,
  partner_id uuid NOT NULL,
  changes jsonb NOT NULL DEFAULT '{}',
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT ON public.vehicle_change_requests TO authenticated;
GRANT ALL ON public.vehicle_change_requests TO service_role;
GRANT UPDATE, DELETE ON public.vehicle_change_requests TO authenticated;
ALTER TABLE public.vehicle_change_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins manage change requests" ON public.vehicle_change_requests FOR ALL TO authenticated
  USING (public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'admin'));
CREATE POLICY "Partners read own change requests" ON public.vehicle_change_requests FOR SELECT TO authenticated
  USING (partner_id = auth.uid());
CREATE POLICY "Partners submit change requests" ON public.vehicle_change_requests FOR INSERT TO authenticated
  WITH CHECK (partner_id = auth.uid() AND status = 'pending'
    AND EXISTS (SELECT 1 FROM public.cars c WHERE c.id = car_id AND c.owner_id = auth.uid()));

-- Event triggers
CREATE OR REPLACE FUNCTION public.on_booking_created() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.trip_status_history(booking_request_id, status, changed_by, note)
    VALUES (NEW.id, NEW.status::text, NEW.client_id, 'Demande créée');
  INSERT INTO public.notifications(audience, title, body, link)
    VALUES ('admin', 'Nouvelle demande client', NEW.first_name || ' ' || NEW.last_name || ' — ' || NEW.service_type, '/admin/demandes');
  IF NEW.client_id IS NOT NULL THEN
    INSERT INTO public.notifications(user_id, title, body, link)
      VALUES (NEW.client_id, 'Demande reçue', 'Votre demande ' || NEW.reference || ' a bien été reçue. Un responsable vous contactera.', '/compte');
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER booking_created AFTER INSERT ON public.booking_requests FOR EACH ROW EXECUTE FUNCTION public.on_booking_created();

CREATE OR REPLACE FUNCTION public.on_proposal_created() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.notifications(audience, title, body, link)
    VALUES ('admin', 'Nouvelle candidature partenaire', NEW.first_name || ' ' || NEW.last_name || ' — ' || NEW.brand || ' ' || NEW.model, '/admin/partenaires');
  RETURN NEW;
END $$;
CREATE TRIGGER proposal_created AFTER INSERT ON public.car_proposals FOR EACH ROW EXECUTE FUNCTION public.on_proposal_created();

-- Storage: partners upload photos of their own vehicle under their user folder
CREATE POLICY "Partners upload own car media" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'car-images' AND (storage.foldername(name))[1] = auth.uid()::text AND public.has_role(auth.uid(),'partner'));