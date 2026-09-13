CREATE TYPE public.app_role AS ENUM ('admin', 'editor');
CREATE TYPE public.booking_status AS ENUM ('new', 'contacted', 'pending', 'confirmed', 'cancelled');
CREATE TYPE public.proposal_status AS ENUM ('new', 'reviewing', 'accepted', 'rejected');

CREATE TABLE public.profiles (
  id uuid PRIMARY KEY,
  first_name text NOT NULL DEFAULT '',
  last_name text NOT NULL DEFAULT '',
  avatar_url text,
  phone text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own profile" ON public.profiles FOR SELECT TO authenticated USING (id = auth.uid());
CREATE POLICY "Users create own profile" ON public.profiles FOR INSERT TO authenticated WITH CHECK (id = auth.uid());
CREATE POLICY "Users update own profile" ON public.profiles FOR UPDATE TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());

CREATE TABLE public.user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  role public.app_role NOT NULL,
  UNIQUE (user_id, role)
);
GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own roles" ON public.user_roles FOR SELECT TO authenticated USING (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role public.app_role)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role)
$$;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO authenticated;

CREATE TABLE public.cars (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  brand text NOT NULL,
  model text NOT NULL,
  slug text NOT NULL UNIQUE,
  year integer,
  color text,
  category text NOT NULL,
  short_description text NOT NULL DEFAULT '',
  description text NOT NULL DEFAULT '',
  features jsonb NOT NULL DEFAULT '{}'::jsonb,
  service_information jsonb NOT NULL DEFAULT '{}'::jsonb,
  price_from numeric(10,2),
  availability text NOT NULL DEFAULT 'Sur demande',
  active boolean NOT NULL DEFAULT true,
  featured boolean NOT NULL DEFAULT false,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.cars TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.cars TO authenticated;
GRANT ALL ON public.cars TO service_role;
ALTER TABLE public.cars ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public reads active cars" ON public.cars FOR SELECT TO anon, authenticated USING (active OR public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins manage cars" ON public.cars FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE TABLE public.car_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  car_id uuid NOT NULL REFERENCES public.cars(id) ON DELETE CASCADE,
  storage_path text NOT NULL,
  alt_text text NOT NULL DEFAULT '',
  is_cover boolean NOT NULL DEFAULT false,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.car_images TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.car_images TO authenticated;
GRANT ALL ON public.car_images TO service_role;
ALTER TABLE public.car_images ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public reads active car images" ON public.car_images FOR SELECT TO anon, authenticated USING (EXISTS (SELECT 1 FROM public.cars c WHERE c.id = car_id AND c.active));
CREATE POLICY "Admins manage car images" ON public.car_images FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE TABLE public.car_videos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  car_id uuid NOT NULL REFERENCES public.cars(id) ON DELETE CASCADE,
  storage_path text NOT NULL,
  title text NOT NULL DEFAULT '',
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.car_videos TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.car_videos TO authenticated;
GRANT ALL ON public.car_videos TO service_role;
ALTER TABLE public.car_videos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public reads active car videos" ON public.car_videos FOR SELECT TO anon, authenticated USING (EXISTS (SELECT 1 FROM public.cars c WHERE c.id = car_id AND c.active));
CREATE POLICY "Admins manage car videos" ON public.car_videos FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE TABLE public.booking_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name text NOT NULL,
  last_name text NOT NULL,
  phone text NOT NULL,
  email text NOT NULL,
  wedding_date date NOT NULL,
  wedding_time time NOT NULL,
  city text NOT NULL,
  venue text NOT NULL,
  car_id uuid REFERENCES public.cars(id) ON DELETE SET NULL,
  car_name text NOT NULL,
  service_type text NOT NULL,
  message text NOT NULL DEFAULT '',
  status public.booking_status NOT NULL DEFAULT 'new',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT INSERT ON public.booking_requests TO anon, authenticated;
GRANT SELECT, UPDATE, DELETE ON public.booking_requests TO authenticated;
GRANT ALL ON public.booking_requests TO service_role;
ALTER TABLE public.booking_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Guests create booking requests" ON public.booking_requests FOR INSERT TO anon, authenticated WITH CHECK (status = 'new');
CREATE POLICY "Admins manage booking requests" ON public.booking_requests FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE TABLE public.car_proposals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name text NOT NULL,
  last_name text NOT NULL,
  phone text NOT NULL,
  email text NOT NULL,
  city text NOT NULL,
  brand text NOT NULL,
  model text NOT NULL,
  year integer NOT NULL,
  color text NOT NULL,
  vehicle_type text NOT NULL,
  description text NOT NULL,
  availability text NOT NULL,
  travel_zone text NOT NULL,
  schedules text NOT NULL,
  desired_rate numeric(10,2) NOT NULL,
  message text NOT NULL DEFAULT '',
  status public.proposal_status NOT NULL DEFAULT 'new',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT INSERT ON public.car_proposals TO anon, authenticated;
GRANT SELECT, UPDATE, DELETE ON public.car_proposals TO authenticated;
GRANT ALL ON public.car_proposals TO service_role;
ALTER TABLE public.car_proposals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Guests create car proposals" ON public.car_proposals FOR INSERT TO anon, authenticated WITH CHECK (status = 'new');
CREATE POLICY "Admins manage car proposals" ON public.car_proposals FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE TABLE public.proposal_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  proposal_id uuid NOT NULL REFERENCES public.car_proposals(id) ON DELETE CASCADE,
  storage_path text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT INSERT ON public.proposal_images TO anon, authenticated;
GRANT SELECT, UPDATE, DELETE ON public.proposal_images TO authenticated;
GRANT ALL ON public.proposal_images TO service_role;
ALTER TABLE public.proposal_images ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Guests attach proposal images" ON public.proposal_images FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "Admins manage proposal images" ON public.proposal_images FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE TABLE public.gallery (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text NOT NULL DEFAULT '',
  event_date date,
  service_type text,
  media_type text NOT NULL CHECK (media_type IN ('image', 'video')),
  storage_path text NOT NULL,
  active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.gallery TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.gallery TO authenticated;
GRANT ALL ON public.gallery TO service_role;
ALTER TABLE public.gallery ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public reads active gallery" ON public.gallery FOR SELECT TO anon, authenticated USING (active OR public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins manage gallery" ON public.gallery FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE TABLE public.admin_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id uuid NOT NULL,
  booking_request_id uuid REFERENCES public.booking_requests(id) ON DELETE CASCADE,
  car_proposal_id uuid REFERENCES public.car_proposals(id) ON DELETE CASCADE,
  note text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((booking_request_id IS NOT NULL)::integer + (car_proposal_id IS NOT NULL)::integer = 1)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.admin_notes TO authenticated;
GRANT ALL ON public.admin_notes TO service_role;
ALTER TABLE public.admin_notes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins manage internal notes" ON public.admin_notes FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin') AND author_id = auth.uid());

CREATE INDEX cars_active_featured_idx ON public.cars(active, featured, sort_order);
CREATE INDEX car_images_car_idx ON public.car_images(car_id, sort_order);
CREATE INDEX car_videos_car_idx ON public.car_videos(car_id, sort_order);
CREATE INDEX booking_requests_status_created_idx ON public.booking_requests(status, created_at DESC);
CREATE INDEX car_proposals_status_created_idx ON public.car_proposals(status, created_at DESC);
CREATE INDEX gallery_active_sort_idx ON public.gallery(active, sort_order);
CREATE INDEX admin_notes_booking_idx ON public.admin_notes(booking_request_id, created_at DESC);
CREATE INDEX admin_notes_proposal_idx ON public.admin_notes(car_proposal_id, created_at DESC);

CREATE POLICY "Public reads catalog media" ON storage.objects FOR SELECT TO anon, authenticated USING (bucket_id IN ('car-images', 'car-videos', 'gallery-media'));
CREATE POLICY "Admins upload catalog media" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id IN ('car-images', 'car-videos', 'gallery-media') AND public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins update catalog media" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id IN ('car-images', 'car-videos', 'gallery-media') AND public.has_role(auth.uid(), 'admin')) WITH CHECK (bucket_id IN ('car-images', 'car-videos', 'gallery-media') AND public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins delete catalog media" ON storage.objects FOR DELETE TO authenticated USING (bucket_id IN ('car-images', 'car-videos', 'gallery-media') AND public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Guests upload proposal images" ON storage.objects FOR INSERT TO anon, authenticated WITH CHECK (bucket_id = 'proposal-images' AND (storage.foldername(name))[1] IS NOT NULL);
CREATE POLICY "Admins read proposal images" ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'proposal-images' AND public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admins delete proposal images" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'proposal-images' AND public.has_role(auth.uid(), 'admin'));

ALTER PUBLICATION supabase_realtime ADD TABLE public.cars;
ALTER PUBLICATION supabase_realtime ADD TABLE public.car_images;
ALTER PUBLICATION supabase_realtime ADD TABLE public.gallery;
ALTER PUBLICATION supabase_realtime ADD TABLE public.booking_requests;
ALTER PUBLICATION supabase_realtime ADD TABLE public.car_proposals;