import fs from 'fs';

const reseed = fs.readFileSync('supabase/reseed_cars_for_partners.sql', 'utf8');

// Parse cars from reseed_cars_for_partners.sql
// In reseed:
// -- Voiture 1 (Partenaire 1: partner1@far7tek.tn)
// INSERT INTO public.cars (...) VALUES (
//   'id', 'name', 'brand', 'model', 'slug', year, 'color', 'category', 'short_desc', 'desc',
//   price, 'avail', active, featured, sort_order, (SELECT id ...), 'validation',
//   seats, 'city', ARRAY[...], 'transmission', 'fuel_type', ARRAY[...]::text[], is_new, 'availability_mode'
// ) ...
// INSERT INTO public.car_images (...) VALUES (
//   'img_id', 'car_id', 'storage_path', 'alt', is_cover, sort_order
// ) ...

const carBlocks = reseed.split('-- Voiture ');
console.log('Blocks count:', carBlocks.length);

const parsed = [];

for (let i = 1; i < carBlocks.length; i++) {
  const b = carBlocks[i];
  
  // partner email
  const pMatch = b.match(/Partenaire (\d+): (partner\d+@far7tek\.tn)/);
  const pEmail = pMatch ? pMatch[2] : 'partner1@far7tek.tn';
  
  // extract values
  const carMatch = b.match(/VALUES\s*\(\s*'([^']+)',\s*'([^']+)',\s*'([^']+)',\s*'([^']+)',\s*'([^']+)',\s*([0-9]+|null),\s*'([^']+)',\s*'([^']+)',\s*'([^']*)',\s*'([^']*)',\s*([0-9.]+),\s*'([^']+)',\s*(true|false),\s*(true|false),\s*([0-9]+),\s*\(SELECT id FROM auth\.users WHERE email = '[^']+'\),\s*'([^']*)',\s*([0-9]+|null),\s*'([^']+)',\s*(ARRAY\[[^\]]*\]),\s*'([^']+)',\s*'([^']+)',\s*(ARRAY\[[^\]]*\]::text\[\]),\s*(true|false),\s*'([^']+)'\s*\)/);
  
  if (!carMatch) {
    console.log('Failed block:', i);
    continue;
  }
  
  // img
  const imgMatch = b.match(/INSERT INTO public\.car_images [^)]+\) VALUES \(\s*'([^']+)',\s*'([^']+)',\s*'([^']+)'/);
  const imgUrl = imgMatch ? imgMatch[3] : 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=1200&q=80';
  
  parsed.push({
    name: carMatch[2],
    brand: carMatch[3],
    model: carMatch[4],
    slug: carMatch[5],
    year: carMatch[6],
    color: carMatch[7],
    category: carMatch[8],
    short_desc: carMatch[9].replace(/'/g, "''"),
    price: carMatch[11],
    sort: carMatch[15],
    email: pEmail,
    seats: carMatch[18],
    city: carMatch[19],
    services: carMatch[20],
    trans: carMatch[21],
    fuel: carMatch[22],
    img: imgUrl
  });
}

console.log('Total parsed cars:', parsed.length);

// Generate compact SQL script
let sql = `-- ==============================================================================
-- FAR7TEK - RESET VOITURES ET ATTRIBUTION AUX 20 PARTENAIRES (100% GARANTI)
-- À copier-coller dans Supabase Studio -> SQL Editor -> New Query
-- Mot de passe de tous les partenaires : Partner2026!
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- 1. Nettoyage complet des tables voitures
DELETE FROM public.car_availability_rules;
DELETE FROM public.car_images;
DELETE FROM public.car_videos;
DELETE FROM public.trip_assignments;
DELETE FROM public.vehicle_change_requests;
DELETE FROM public.booking_requests;
DELETE FROM public.cars;

-- 2. Création et configuration des 20 partenaires
DO $$
DECLARE
  _pwd text := extensions.crypt('Partner2026!', extensions.gen_salt('bf', 10));
  _partners text[][] := ARRAY[
    ['partner1@far7tek.tn', 'Mohamed', 'Ben Salem', '+216 98 214 550'],
    ['partner2@far7tek.tn', 'Youssef', 'Trabelsi', '+216 22 341 890'],
    ['partner3@far7tek.tn', 'Khalil', 'Bouazizi', '+216 50 678 123'],
    ['partner4@far7tek.tn', 'Karim', 'Dridi', '+216 97 452 310'],
    ['partner5@far7tek.tn', 'Anis', 'Gharbi', '+216 29 118 765'],
    ['partner6@far7tek.tn', 'Hassen', 'Mezhoud', '+216 52 901 443'],
    ['partner7@far7tek.tn', 'Tarek', 'Chahed', '+216 93 112 004'],
    ['partner8@far7tek.tn', 'Zied', 'Khemir', '+216 24 556 781'],
    ['partner9@far7tek.tn', 'Bilel', 'Mansour', '+216 58 223 990'],
    ['partner10@far7tek.tn', 'Slim', 'Jaziri', '+216 96 778 120'],
    ['partner11@far7tek.tn', 'Walid', 'Hamdi', '+216 21 009 342'],
    ['partner12@far7tek.tn', 'Mehdi', 'Rekik', '+216 55 431 876'],
    ['partner13@far7tek.tn', 'Sami', 'Ayari', '+216 94 332 109'],
    ['partner14@far7tek.tn', 'Mourad', 'Ben Amor', '+216 26 771 223'],
    ['partner15@far7tek.tn', 'Firas', 'Chebbi', '+216 51 890 345'],
    ['partner16@far7tek.tn', 'Nader', 'Zouari', '+216 92 654 321'],
    ['partner17@far7tek.tn', 'Wassim', 'Mahjoub', '+216 23 445 678'],
    ['partner18@far7tek.tn', 'Wissem', 'Ben Fredj', '+216 54 789 203'],
    ['partner19@far7tek.tn', 'Hichem', 'Guesmi', '+216 27 605 114'],
    ['partner20@far7tek.tn', 'Riadh', 'Sassi', '+216 95 332 890']
  ];
  _i int;
  _uid uuid;
  _em text; _fn text; _ln text; _ph text;
BEGIN
  FOR _i IN 1..array_length(_partners, 1) LOOP
    _em := _partners[_i][1]; _fn := _partners[_i][2]; _ln := _partners[_i][3]; _ph := _partners[_i][4];
    SELECT id INTO _uid FROM auth.users WHERE email = _em;
    IF _uid IS NULL THEN
      _uid := gen_random_uuid();
      INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
        raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
        confirmation_token, recovery_token, email_change_token_new, email_change,
        phone_change, phone_change_token, email_change_token_current, reauthentication_token,
        is_sso_user, is_anonymous, is_super_admin
      ) VALUES (
        '00000000-0000-0000-0000-000000000000', _uid, 'authenticated', 'authenticated',
        _em, _pwd, now(), '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object('first_name', _fn, 'last_name', _ln, 'phone', _ph),
        now(), now(), '', '', '', '', '', '', '', '', false, false, false
      );
    ELSE
      UPDATE auth.users
      SET email_confirmed_at = COALESCE(email_confirmed_at, now()),
          encrypted_password = _pwd,
          raw_app_meta_data = '{"provider":"email","providers":["email"]}'::jsonb,
          raw_user_meta_data = jsonb_build_object('first_name', _fn, 'last_name', _ln, 'phone', _ph),
          updated_at = now()
      WHERE id = _uid;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM auth.identities WHERE user_id = _uid) THEN
      INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
      VALUES (_uid::text, _uid, jsonb_build_object('sub', _uid::text, 'email', _em), 'email', _uid::text, now(), now(), now());
    END IF;

    INSERT INTO public.profiles (id, first_name, last_name, phone)
    VALUES (_uid, _fn, _ln, _ph)
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (_uid, 'partner')
    ON CONFLICT (user_id, role) DO NOTHING;
  END LOOP;
END $$;

-- 3. Insertion des 100 voitures et photos reliées directement aux 20 partenaires
DO $$
DECLARE
  _c RECORD;
  _cid uuid;
  _uid uuid;
  _cars jsonb := '` + JSON.stringify(parsed) + `'::jsonb;
BEGIN
  FOR _c IN SELECT * FROM jsonb_to_recordset(_cars) AS (
    name text, brand text, model text, slug text, year int, color text, category text,
    short_desc text, price numeric, sort int, email text, seats int, city text,
    services text[], trans text, fuel text, img text
  )
  LOOP
    SELECT id INTO _uid FROM auth.users WHERE email = _c.email;
    _cid := gen_random_uuid();

    INSERT INTO public.cars (
      id, name, brand, model, slug, year, color, category,
      short_description, description, price_from, availability,
      active, featured, sort_order, owner_id, validation_status,
      seats, city, services, transmission, fuel_type, is_new_arrival, availability_mode
    ) VALUES (
      _cid, _c.name, _c.brand, _c.model, _c.slug, _c.year, _c.color, _c.category,
      _c.short_desc, _c.short_desc, _c.price, 'Disponible 7j/7',
      true, (_c.sort <= 10), _c.sort, _uid, 'active',
      _c.seats, _c.city, _c.services, _c.trans, _c.fuel, false, 'always'
    );

    INSERT INTO public.car_images (
      id, car_id, storage_path, alt_text, is_cover, sort_order
    ) VALUES (
      gen_random_uuid(), _cid, _c.img, _c.name, true, 1
    );
  END LOOP;
END $$;
`;

fs.writeFileSync('supabase/reseed_compact.sql', sql);
console.log('reseed_compact.sql size:', sql.length);
