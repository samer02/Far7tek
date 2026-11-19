import fs from 'fs';

const part1Cars = JSON.parse(fs.readFileSync('part1_cars.json'));
const part2Cars = JSON.parse(fs.readFileSync('part2_cars.json'));

const headerPart1 = `-- ==============================================================================
-- FAR7TEK - PARTIE 1/2 : 20 COMPTES PARTENAIRES + 50 VOITURES DE PRESTIGE
-- À copier-coller dans Supabase Studio -> SQL Editor -> New Query
-- Mot de passe de tous les partenaires : Partner2026!
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- 1. Nettoyage complet
DELETE FROM public.car_availability_rules;
DELETE FROM public.car_images;
DELETE FROM public.car_videos;
DELETE FROM public.trip_assignments;
DELETE FROM public.vehicle_change_requests;
DELETE FROM public.booking_requests;
DELETE FROM public.cars;

-- 2. Création et confirmation des 20 partenaires dans Supabase Auth
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

-- 3. Insertion des 50 premières voitures (Mariage & Cortège)
INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES
` + part1Cars.map(c => `(${c.carValues})`).join(',\n') + `;\n\n` +
`-- 4. Photos des 50 premières voitures
INSERT INTO public.car_images (id, car_id, storage_path, alt_text, is_cover, sort_order) VALUES
` + part1Cars.map((c, i) => `(gen_random_uuid(), (SELECT id FROM public.cars WHERE sort_order = ${i + 1} LIMIT 1), '${c.img}', (SELECT name FROM public.cars WHERE sort_order = ${i + 1} LIMIT 1), true, 1)`).join(',\n') + `;\n`;

const headerPart2 = `-- ==============================================================================
-- FAR7TEK - PARTIE 2/2 : 50 VANS & MINIBUS FAMILIAUX
-- À copier-coller dans Supabase Studio -> SQL Editor -> New Query (après la Partie 1)
-- ==============================================================================

-- 1. Insertion des 50 véhicules suivants (Vans, Minibus & Familiales)
INSERT INTO public.cars (
  id, name, brand, model, slug, year, color, category, short_description, description,
  price_from, availability, active, featured, sort_order, owner_id, validation_status,
  seats, city, services, transmission, fuel_type, equipment, is_new_arrival, availability_mode
) VALUES
` + part2Cars.map(c => `(${c.carValues})`).join(',\n') + `;\n\n` +
`-- 2. Photos des 50 véhicules suivants
INSERT INTO public.car_images (id, car_id, storage_path, alt_text, is_cover, sort_order) VALUES
` + part2Cars.map((c, i) => `(gen_random_uuid(), (SELECT id FROM public.cars WHERE sort_order = ${i + 51} LIMIT 1), '${c.img}', (SELECT name FROM public.cars WHERE sort_order = ${i + 51} LIMIT 1), true, 1)`).join(',\n') + `;\n`;

fs.writeFileSync('supabase/part1.sql', headerPart1);
fs.writeFileSync('supabase/part2.sql', headerPart2);

console.log('Part 1 size:', headerPart1.length);
console.log('Part 2 size:', headerPart2.length);
