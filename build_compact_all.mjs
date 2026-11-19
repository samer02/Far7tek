import fs from 'fs';

const part1Cars = JSON.parse(fs.readFileSync('part1_cars.json'));
const part2Cars = JSON.parse(fs.readFileSync('part2_cars.json'));
const all = [...part1Cars, ...part2Cars];

console.log('All cars count:', all.length);

// Extract the compact tuple for each car
const tuples = [];

for (let i = 0; i < all.length; i++) {
  const c = all[i];
  // extract values from carValues
  // Format in carValues:
  // 'id', 'name', 'brand', 'model', 'slug', year, 'color', 'category', 'short_desc', 'desc', price, 'avail', active, feat, sort, (SELECT...), 'val', seats, 'city', ARRAY[...], 'trans', 'fuel', ARRAY[...]::text[], is_new, 'avail_mode'
  
  // Let's parse with comma-split while respecting quotes
  const parts = [];
  let cur = '';
  let inQ = false;
  let inArr = false;
  for (let ch of c.carValues) {
    if (ch === "'" && !inArr) inQ = !inQ;
    if (ch === '[' && !inQ) inArr = true;
    if (ch === ']' && !inQ) inArr = false;
    if (ch === ',' && !inQ && !inArr) {
      parts.push(cur.trim());
      cur = '';
    } else {
      cur += ch;
    }
  }
  if (cur.trim()) parts.push(cur.trim());
  
  const name = parts[1].replace(/^'|'$/g, '').replace(/'/g, "''");
  const brand = parts[2].replace(/^'|'$/g, '').replace(/'/g, "''");
  const model = parts[3].replace(/^'|'$/g, '').replace(/'/g, "''");
  const year = parts[5];
  const color = parts[6].replace(/^'|'$/g, '').replace(/'/g, "''");
  const cat = parts[7].replace(/^'|'$/g, '').replace(/'/g, "''");
  const price = parts[10];
  const seats = parts[17] || '4';
  const city = parts[18].replace(/^'|'$/g, '').replace(/'/g, "''");
  const services = parts[19].includes('family') ? 'family' : 'wedding';
  const img = c.img;
  
  tuples.push(`    ARRAY['${name}', '${brand}', '${model}', '${year}', '${color}', '${cat}', '${price}', '${seats}', '${city}', '${services}', '${img}']`);
}

console.log('Tuples generated:', tuples.length);

const finalSql = `-- ==============================================================================
-- FAR7TEK : CONFIGURATION 100% INTÉGRALE (20 PARTENAIRES & 100 VOITURES)
-- À copier-coller en UNE SEULE FOIS dans Supabase Studio -> SQL Editor -> New Query
-- Mot de passe de tous les comptes partenaires : Partner2026!
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- 1. Nettoyage complet des tables
DELETE FROM public.car_availability_rules;
DELETE FROM public.car_images;
DELETE FROM public.car_videos;
DELETE FROM public.trip_assignments;
DELETE FROM public.vehicle_change_requests;
DELETE FROM public.booking_requests;
DELETE FROM public.cars;

-- 2. Création et confirmation des 20 comptes partenaires dans auth.users
DO $$
DECLARE
  _pwd text := extensions.crypt('Partner2026!', extensions.gen_salt('bf', 10));
  _partners text[][] := ARRAY[
    ARRAY['partner1@far7tek.tn', 'Mohamed', 'Ben Salem', '+216 98 214 550'],
    ARRAY['partner2@far7tek.tn', 'Youssef', 'Trabelsi', '+216 22 341 890'],
    ARRAY['partner3@far7tek.tn', 'Khalil', 'Bouazizi', '+216 50 678 123'],
    ARRAY['partner4@far7tek.tn', 'Karim', 'Dridi', '+216 97 452 310'],
    ARRAY['partner5@far7tek.tn', 'Anis', 'Gharbi', '+216 29 118 765'],
    ARRAY['partner6@far7tek.tn', 'Hassen', 'Mezhoud', '+216 52 901 443'],
    ARRAY['partner7@far7tek.tn', 'Tarek', 'Chahed', '+216 93 112 004'],
    ARRAY['partner8@far7tek.tn', 'Zied', 'Khemir', '+216 24 556 781'],
    ARRAY['partner9@far7tek.tn', 'Bilel', 'Mansour', '+216 58 223 990'],
    ARRAY['partner10@far7tek.tn', 'Slim', 'Jaziri', '+216 96 778 120'],
    ARRAY['partner11@far7tek.tn', 'Walid', 'Hamdi', '+216 21 009 342'],
    ARRAY['partner12@far7tek.tn', 'Mehdi', 'Rekik', '+216 55 431 876'],
    ARRAY['partner13@far7tek.tn', 'Sami', 'Ayari', '+216 94 332 109'],
    ARRAY['partner14@far7tek.tn', 'Mourad', 'Ben Amor', '+216 26 771 223'],
    ARRAY['partner15@far7tek.tn', 'Firas', 'Chebbi', '+216 51 890 345'],
    ARRAY['partner16@far7tek.tn', 'Nader', 'Zouari', '+216 92 654 321'],
    ARRAY['partner17@far7tek.tn', 'Wassim', 'Mahjoub', '+216 23 445 678'],
    ARRAY['partner18@far7tek.tn', 'Wissem', 'Ben Fredj', '+216 54 789 203'],
    ARRAY['partner19@far7tek.tn', 'Hichem', 'Guesmi', '+216 27 605 114'],
    ARRAY['partner20@far7tek.tn', 'Riadh', 'Sassi', '+216 95 332 890']
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

-- 3. Insertion des 100 voitures et photos (5 voitures par partenaire)
DO $$
DECLARE
  _cars text[][] := ARRAY[
` + tuples.join(',\n') + `
  ];
  _i int;
  _pnum int;
  _pemail text;
  _owner_id uuid;
  _car_id uuid;
  _name text; _brand text; _model text; _year int; _color text; _cat text;
  _price numeric; _seats int; _city text; _srv text; _img text;
  _services text[];
  _slug text;
BEGIN
  FOR _i IN 1..array_length(_cars, 1) LOOP
    _name := _cars[_i][1];
    _brand := _cars[_i][2];
    _model := _cars[_i][3];
    _year := _cars[_i][4]::int;
    _color := _cars[_i][5];
    _cat := _cars[_i][6];
    _price := _cars[_i][7]::numeric;
    _seats := _cars[_i][8]::int;
    _city := _cars[_i][9];
    _srv := _cars[_i][10];
    _img := _cars[_i][11];

    -- Attribuer 5 voitures à chaque partenaire (1..20)
    _pnum := ((_i - 1) / 5) + 1;
    IF _pnum > 20 THEN _pnum := 20; END IF;
    _pemail := 'partner' || _pnum || '@far7tek.tn';

    SELECT id INTO _owner_id FROM auth.users WHERE email = _pemail;

    IF _srv = 'family' THEN
      _services := ARRAY['family', 'private']::text[];
    ELSE
      _services := ARRAY['wedding', 'event']::text[];
    END IF;

    _slug := lower(regexp_replace(_brand || '-' || _model || '-' || _i, '[^a-zA-Z0-9]+', '-', 'g'));
    _car_id := gen_random_uuid();

    INSERT INTO public.cars (
      id, name, brand, model, slug, year, color, category,
      short_description, description, price_from, availability,
      active, featured, sort_order, owner_id, validation_status,
      seats, city, services, transmission, fuel_type,
      equipment, is_new_arrival, availability_mode
    ) VALUES (
      _car_id, _name, _brand, _model, _slug, _year, _color, _cat,
      _name || ' disponible avec chauffeur professionnel pour vos cérémonies et transferts.',
      _name || ' disponible avec chauffeur professionnel pour vos cérémonies et transferts en Tunisie.',
      _price, 'Disponible 7j/7', true, (_i <= 8), _i, _owner_id, 'active',
      _seats, _city, _services, 'automatic', 'petrol',
      ARRAY['air_conditioning', 'leather_seats', 'uniformed_driver']::text[], (_i > 90), 'always'
    );

    INSERT INTO public.car_images (
      id, car_id, storage_path, alt_text, is_cover, sort_order
    ) VALUES (
      gen_random_uuid(), _car_id, _img, _name, true, 1
    );
  END LOOP;
END $$;
`;

fs.writeFileSync('supabase/all_in_one_cars.sql', finalSql);
console.log('Final all_in_one_cars.sql size:', finalSql.length);
