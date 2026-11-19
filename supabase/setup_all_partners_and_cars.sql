-- ==============================================================================
-- FAR7TEK - CONFIGURATION COMPLÈTE : 20 PARTENAIRES ET LEURS 100 VOITURES
-- À exécuter dans Supabase Studio -> SQL Editor -> New Query
--
-- Mot de passe pour tous les comptes : Partner2026!
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

DO $$
DECLARE
  partner_data jsonb := '[
    {
      "email": "partner1@far7tek.tn", "first_name": "Mohamed", "last_name": "Ben Salem", "phone": "+216 98 214 550",
      "cars": ["Rolls-Royce Ghost", "Porsche Taycan 4S", "Maserati Levante GranLusso", "Volkswagen Multivan T6.1 Comfortline", "Renault Trafic Passenger SpaceClass"]
    },
    {
      "email": "partner2@far7tek.tn", "first_name": "Youssef", "last_name": "Trabelsi", "phone": "+216 22 341 890",
      "cars": ["Rolls-Royce Phantom VIII", "BMW Série 7 740i G70", "Bentley Continental GT", "Volkswagen Transporter Shuttle 9 Places", "Renault Trafic Grand Passenger 9 Places"]
    },
    {
      "email": "partner3@far7tek.tn", "first_name": "Khalil", "last_name": "Bouazizi", "phone": "+216 50 678 123",
      "cars": ["Rolls-Royce Dawn Cabriolet", "BMW Série 7 730d M Sport G11", "Bentley Flying Spur V8", "Volkswagen Tiguan Allspace R-Line", "Renault Espace V Initiale Paris 7 Places"]
    },
    {
      "email": "partner4@far7tek.tn", "first_name": "Karim", "last_name": "Dridi", "phone": "+216 97 452 310",
      "cars": ["Rolls-Royce Cullinan", "BMW Série 5 530i M Sport G30", "Chrysler 300C Limousine Stretch 9m", "Volkswagen Touran Family", "Renault Grand Scénic Bose Edition 7 Places"]
    },
    {
      "email": "partner5@far7tek.tn", "first_name": "Anis", "last_name": "Gharbi", "phone": "+216 29 118 765",
      "cars": ["Mercedes-Maybach S680 V12", "BMW Série 4 Gran Coupé 420i", "Chrysler 300C Luxury Sedan", "Hyundai Staria Premium 9 Places", "Ford Tourneo Custom Titanium X 8 Places"]
    },
    {
      "email": "partner6@far7tek.tn", "first_name": "Hassen", "last_name": "Mezhoud", "phone": "+216 52 901 443",
      "cars": ["Mercedes-Benz Classe S 580 Limousine", "BMW Série 3 320i Pack M", "Lincoln Town Car Stretch Limousine Blanche", "Hyundai Staria Lounge 7 Places", "Ford Tourneo Custom Shuttle 9 Places"]
    },
    {
      "email": "partner7@far7tek.tn", "first_name": "Tarek", "last_name": "Chahed", "phone": "+216 93 112 004",
      "cars": ["Mercedes-Benz Classe S 350d AMG Line", "BMW X6 xDrive40i M Sport", "Lincoln Continental Limousine Blanche", "Hyundai Santa Fe 7 Places", "Ford Transit Minibus 17 Places"]
    },
    {
      "email": "partner8@far7tek.tn", "first_name": "Zied", "last_name": "Khemir", "phone": "+216 24 556 781",
      "cars": ["Mercedes-Benz Classe E 220d Pack AMG", "BMW X5 xDrive30d Pack M", "Cadillac Escalade ESV Platinum", "Toyota HiAce VIP Minibus 14 Places", "Opel Zafira Life Business 9 Places"]
    },
    {
      "email": "partner9@far7tek.tn", "first_name": "Bilel", "last_name": "Mansour", "phone": "+216 58 223 990",
      "cars": ["Mercedes-Benz Classe E 200 Avantgarde", "Audi A8 L 55 TFSI quattro", "Cadillac Fleetwood Brougham Vintage 1985", "Toyota HiAce Grand Cabin 15 Places", "Opel Vivaro Combi 9 Places"]
    },
    {
      "email": "partner10@far7tek.tn", "first_name": "Slim", "last_name": "Jaziri", "phone": "+216 96 778 120",
      "cars": ["Mercedes-Benz Classe C 200 AMG Line", "Audi A6 40 TDI S line", "Jaguar XF Portfolio Edition", "Toyota Land Cruiser Prado 7 Places", "Citroën SpaceTourer Business Lounge 8 Places"]
    },
    {
      "email": "partner11@far7tek.tn", "first_name": "Walid", "last_name": "Hamdi", "phone": "+216 21 009 342",
      "cars": ["Mercedes-Benz CLA 200 Shooting Brake AMG", "Audi A4 35 TFSI S line", "Jaguar F-Pace R-Dynamic", "Toyota Fortuner 7 Places", "Citroën SpaceTourer Feel 9 Places"]
    },
    {
      "email": "partner12@far7tek.tn", "first_name": "Mehdi", "last_name": "Rekik", "phone": "+216 55 431 876",
      "cars": ["Mercedes-Benz CLE Coupé 200 AMG", "Audi Q8 50 TDI S line", "Volvo S90 Inscription D5", "Mercedes-Benz Classe V 250d Avantgarde", "Citroën Grand C4 Spacetourer 7 Places"]
    },
    {
      "email": "partner13@far7tek.tn", "first_name": "Sami", "last_name": "Ayari", "phone": "+216 94 332 109",
      "cars": ["Mercedes-Benz GLE Coupé 400d AMG Line", "Audi Q7 45 TDI quattro 7 Places", "Volvo XC90 T8 Recharge Inscription 7 Places", "Mercedes-Benz Classe V 300d Exclusive", "Fiat Scudo Panorama 9 Places"]
    },
    {
      "email": "partner14@far7tek.tn", "first_name": "Mourad", "last_name": "Ben Amor", "phone": "+216 26 771 223",
      "cars": ["Mercedes-Benz GLC 220d Coupé AMG Line", "Porsche Panamera 4S E-Hybrid", "Land Rover Range Rover Vogue Autobiography", "Mercedes-Benz Vito Tourer Select", "Fiat Talento Combi Family 9 Places"]
    },
    {
      "email": "partner15@far7tek.tn", "first_name": "Firas", "last_name": "Chebbi", "phone": "+216 51 890 345",
      "cars": ["Mercedes-AMG G63 V8 Biturbo", "Range Rover Sport HSE Dynamic", "Mercedes-Benz Vito Tourer PRO", "Peugeot Traveller Allure 9 Places", "Fiat Ducato Panorama 15 Places"]
    },
    {
      "email": "partner16@far7tek.tn", "first_name": "Nader", "last_name": "Zouari", "phone": "+216 92 654 321",
      "cars": ["Porsche Cayenne Coupé GTS", "Range Rover Velar R-Dynamic", "Lexus ES 300h Luxury", "Mercedes-Benz Sprinter Transfer 16 Places", "Peugeot Traveller VIP Business 8 Places"]
    },
    {
      "email": "partner17@far7tek.tn", "first_name": "Wassim", "last_name": "Mahjoub", "phone": "+216 23 445 678",
      "cars": ["Porsche Macan GTS", "Range Rover Evoque R-Dynamic", "Lexus RX 450h F-Sport", "Mercedes-Benz Sprinter City 19 Places", "Peugeot 5008 GT Pack 7 Places"]
    },
    {
      "email": "partner18@far7tek.tn", "first_name": "Wissem", "last_name": "Ben Fredj", "phone": "+216 54 789 203",
      "cars": ["Porsche 911 Carrera S Cabriolet (Cortège)", "Maserati Ghibli GranSport V6", "Alfa Romeo Giulia Veloce 280ch", "Volkswagen Crafter Minibus 17 Places", "Renault Trafic SpaceClass Signature 7 Places"]
    },
    {
      "email": "partner19@far7tek.tn", "first_name": "Hichem", "last_name": "Guesmi", "phone": "+216 27 605 114",
      "cars": ["Porsche 718 Boxster GTS Cabriolet", "Maserati Quattroporte SQ4", "Alfa Romeo Stelvio Veloce Q4", "Volkswagen Caravelle 6.1 9 Places", "Renault Master Combi 16 Places"]
    },
    {
      "email": "partner20@far7tek.tn", "first_name": "Riadh", "last_name": "Sassi", "phone": "+216 95 332 890",
      "cars": ["Ferrari Roma (Voiture d''honneur)", "Ford Mustang GT 5.0 V8 Cabriolet", "Jeep Wrangler Rubicon Unlimited Décapotable", "Iveco Daily Tourys Minibus 19 Places", "Mercedes-Benz Sprinter VIP Lounge 12 Places"]
    }
  ]';

  item jsonb;
  car_name text;
  _uid uuid;
  _email text;
  _fn text;
  _ln text;
  _ph text;
  _pwd_hash text;
BEGIN
  -- Mot de passe chiffré standard bcrypt pour GoTrue Supabase
  _pwd_hash := extensions.crypt('Partner2026!', extensions.gen_salt('bf', 10));

  FOR item IN SELECT * FROM jsonb_array_elements(partner_data)
  LOOP
    _email := item->>'email';
    _fn := item->>'first_name';
    _ln := item->>'last_name';
    _ph := item->>'phone';

    -- 1. Récupération ou création de l'utilisateur dans auth.users
    SELECT id INTO _uid FROM auth.users WHERE email = _email;

    IF _uid IS NULL THEN
      _uid := gen_random_uuid();

      INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
        raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
        confirmation_token, recovery_token, email_change_token_new, email_change,
        phone_change, phone_change_token, email_change_token_current, reauthentication_token,
        is_sso_user, is_anonymous, is_super_admin
      ) VALUES (
        '00000000-0000-0000-0000-000000000000',
        _uid,
        'authenticated',
        'authenticated',
        _email,
        _pwd_hash,
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object('first_name', _fn, 'last_name', _ln, 'phone', _ph),
        now(),
        now(),
        '', '', '', '', '', '', '', '',
        false,
        false,
        false
      );
    ELSE
      -- Si le compte existe déjà, s'assurer que l'email est confirmé et le mot de passe valide
      UPDATE auth.users
      SET email_confirmed_at = COALESCE(email_confirmed_at, now()),
          encrypted_password = _pwd_hash,
          raw_app_meta_data = '{"provider":"email","providers":["email"]}'::jsonb,
          raw_user_meta_data = jsonb_build_object('first_name', _fn, 'last_name', _ln, 'phone', _ph),
          updated_at = now()
      WHERE id = _uid;
    END IF;

    -- 2. Création de l'identité GoTrue dans auth.identities (vital pour éviter les erreurs 500)
    IF NOT EXISTS (SELECT 1 FROM auth.identities WHERE user_id = _uid) THEN
      INSERT INTO auth.identities (
        id,
        user_id,
        identity_data,
        provider,
        provider_id,
        last_sign_in_at,
        created_at,
        updated_at
      ) VALUES (
        _uid::text,
        _uid,
        jsonb_build_object('sub', _uid::text, 'email', _email),
        'email',
        _uid::text,
        now(),
        now(),
        now()
      );
    END IF;

    -- 3. Profil public
    INSERT INTO public.profiles (id, first_name, last_name, phone)
    VALUES (_uid, _fn, _ln, _ph)
    ON CONFLICT (id) DO UPDATE
      SET first_name = EXCLUDED.first_name,
          last_name = EXCLUDED.last_name,
          phone = EXCLUDED.phone;

    -- 4. Rôle Partenaire
    INSERT INTO public.user_roles (user_id, role)
    VALUES (_uid, 'partner')
    ON CONFLICT (user_id, role) DO NOTHING;

    -- 5. Attribution des voitures spécifiques au partenaire
    FOR car_name IN SELECT jsonb_array_elements_text(item->'cars')
    LOOP
      UPDATE public.cars
      SET owner_id = _uid,
          active = true,
          validation_status = 'active',
          availability_mode = 'always'
      WHERE name = car_name;
    END LOOP;

  END LOOP;

  -- 6. Sécurité : Si des voitures n'avaient pas encore d'owner valide, les rattacher à un partenaire existant
  UPDATE public.cars c
  SET owner_id = (SELECT id FROM auth.users WHERE email = 'partner1@far7tek.tn')
  WHERE c.owner_id IS NULL OR c.owner_id NOT IN (SELECT id FROM auth.users);

END $$;
