-- ==============================================================================
-- Link All 20 Partner Users: Profiles, Roles & Cars
-- Auto-confirms email and assigns each partner their 5 cars
-- ==============================================================================

-- 1. Auto-confirm email for all 20 partners (no confirmation email needed)
UPDATE auth.users
SET email_confirmed_at = COALESCE(email_confirmed_at, now())
WHERE email LIKE 'partner%@far7tek.tn';

-- 2. Link profiles, partner roles and cars for each partner

DO $$
DECLARE
  _uid uuid;
BEGIN

  -- Partner 1: partner1@far7tek.tn
  SELECT id INTO _uid FROM auth.users WHERE email = 'partner1@far7tek.tn';
  IF _uid IS NOT NULL THEN
    INSERT INTO public.profiles (id, first_name, last_name, phone)
    VALUES (_uid, 'Mohamed', 'Ben Salem', '+216 98 214 550')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (_uid, 'partner')
    ON CONFLICT (user_id, role) DO NOTHING;

    UPDATE public.cars
    SET owner_id = _uid
    WHERE name IN ('Rolls-Royce Ghost', 'Porsche Taycan 4S', 'Maserati Levante GranLusso', 'Volkswagen Multivan T6.1 Comfortline', 'Renault Trafic Passenger SpaceClass');
  END IF;


  -- Partner 2: partner2@far7tek.tn
  SELECT id INTO _uid FROM auth.users WHERE email = 'partner2@far7tek.tn';
  IF _uid IS NOT NULL THEN
    INSERT INTO public.profiles (id, first_name, last_name, phone)
    VALUES (_uid, 'Youssef', 'Trabelsi', '+216 22 341 890')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (_uid, 'partner')
    ON CONFLICT (user_id, role) DO NOTHING;

    UPDATE public.cars
    SET owner_id = _uid
    WHERE name IN ('Rolls-Royce Phantom VIII', 'BMW Série 7 740i G70', 'Bentley Continental GT', 'Volkswagen Transporter Shuttle 9 Places', 'Renault Trafic Grand Passenger 9 Places');
  END IF;


  -- Partner 3: partner3@far7tek.tn
  SELECT id INTO _uid FROM auth.users WHERE email = 'partner3@far7tek.tn';
  IF _uid IS NOT NULL THEN
    INSERT INTO public.profiles (id, first_name, last_name, phone)
    VALUES (_uid, 'Khalil', 'Bouazizi', '+216 50 678 123')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (_uid, 'partner')
    ON CONFLICT (user_id, role) DO NOTHING;

    UPDATE public.cars
    SET owner_id = _uid
    WHERE name IN ('Rolls-Royce Dawn Cabriolet', 'BMW Série 7 730d M Sport G11', 'Bentley Flying Spur V8', 'Volkswagen Tiguan Allspace R-Line', 'Renault Espace V Initiale Paris 7 Places');
  END IF;


  -- Partner 4: partner4@far7tek.tn
  SELECT id INTO _uid FROM auth.users WHERE email = 'partner4@far7tek.tn';
  IF _uid IS NOT NULL THEN
    INSERT INTO public.profiles (id, first_name, last_name, phone)
    VALUES (_uid, 'Karim', 'Dridi', '+216 97 452 310')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (_uid, 'partner')
    ON CONFLICT (user_id, role) DO NOTHING;

    UPDATE public.cars
    SET owner_id = _uid
    WHERE name IN ('Rolls-Royce Cullinan', 'BMW Série 5 530i M Sport G30', 'Chrysler 300C Limousine Stretch 9m', 'Volkswagen Touran Family', 'Renault Grand Scénic Bose Edition 7 Places');
  END IF;


  -- Partner 5: partner5@far7tek.tn
  SELECT id INTO _uid FROM auth.users WHERE email = 'partner5@far7tek.tn';
  IF _uid IS NOT NULL THEN
    INSERT INTO public.profiles (id, first_name, last_name, phone)
    VALUES (_uid, 'Anis', 'Gharbi', '+216 29 118 765')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (_uid, 'partner')
    ON CONFLICT (user_id, role) DO NOTHING;

    UPDATE public.cars
    SET owner_id = _uid
    WHERE name IN ('Mercedes-Maybach S680 V12', 'BMW Série 4 Gran Coupé 420i', 'Chrysler 300C Luxury Sedan', 'Hyundai Staria Premium 9 Places', 'Ford Tourneo Custom Titanium X 8 Places');
  END IF;


  -- Partner 6: partner6@far7tek.tn
  SELECT id INTO _uid FROM auth.users WHERE email = 'partner6@far7tek.tn';
  IF _uid IS NOT NULL THEN
    INSERT INTO public.profiles (id, first_name, last_name, phone)
    VALUES (_uid, 'Sami', 'Mansour', '+216 55 902 431')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (_uid, 'partner')
    ON CONFLICT (user_id, role) DO NOTHING;

    UPDATE public.cars
    SET owner_id = _uid
    WHERE name IN ('Mercedes-Maybach S580', 'BMW Série 8 Gran Coupé M850i', 'Citroën Traction Avant 11B', 'Hyundai Staria Lounge 7 Places VIP', 'Ford Tourneo Custom 9 Places');
  END IF;


  -- Partner 7: partner7@far7tek.tn
  SELECT id INTO _uid FROM auth.users WHERE email = 'partner7@far7tek.tn';
  IF _uid IS NOT NULL THEN
    INSERT INTO public.profiles (id, first_name, last_name, phone)
    VALUES (_uid, 'Mehdi', 'Chaabane', '+216 26 734 119')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (_uid, 'partner')
    ON CONFLICT (user_id, role) DO NOTHING;

    UPDATE public.cars
    SET owner_id = _uid
    WHERE name IN ('Mercedes-Benz Classe S 500 W223', 'BMW X7 xDrive40i M Sport', 'Peugeot 404 Cabriolet Pininfarina', 'Hyundai H-1 Travel Royale 9 Places', 'Ford Transit Minibus 14 Places');
  END IF;


  -- Partner 8: partner8@far7tek.tn
  SELECT id INTO _uid FROM auth.users WHERE email = 'partner8@far7tek.tn';
  IF _uid IS NOT NULL THEN
    INSERT INTO public.profiles (id, first_name, last_name, phone)
    VALUES (_uid, 'Skander', 'Khemir', '+216 92 884 201')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (_uid, 'partner')
    ON CONFLICT (user_id, role) DO NOTHING;

    UPDATE public.cars
    SET owner_id = _uid
    WHERE name IN ('Mercedes-Benz Classe S 400d AMG', 'BMW X6 xDrive30d M Sport', 'Volkswagen Coccinelle 1303 Cabriolet', 'Hyundai H-1 GLX 9 Places', 'Kia Carnival Limousine 7 Places VIP');
  END IF;


  -- Partner 9: partner9@far7tek.tn
  SELECT id INTO _uid FROM auth.users WHERE email = 'partner9@far7tek.tn';
  IF _uid IS NOT NULL THEN
    INSERT INTO public.profiles (id, first_name, last_name, phone)
    VALUES (_uid, 'Zied', 'Jaziri', '+216 58 120 944')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (_uid, 'partner')
    ON CONFLICT (user_id, role) DO NOTHING;

    UPDATE public.cars
    SET owner_id = _uid
    WHERE name IN ('Mercedes-Benz Classe S 350d W222', 'Audi A8 L 55 TFSI Quattro', 'Mercedes-Benz 280 SE W108', 'Hyundai Santa Fe Calligraphy 7 Places', 'Kia Carnival SX 8 Places');
  END IF;


  -- Partner 10: partner10@far7tek.tn
  SELECT id INTO _uid FROM auth.users WHERE email = 'partner10@far7tek.tn';
  IF _uid IS NOT NULL THEN
    INSERT INTO public.profiles (id, first_name, last_name, phone)
    VALUES (_uid, 'Walid', 'Ayari', '+216 24 665 302')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (_uid, 'partner')
    ON CONFLICT (user_id, role) DO NOTHING;

    UPDATE public.cars
    SET owner_id = _uid
    WHERE name IN ('Mercedes-Benz Classe E 300 AMG Line W214', 'Audi A7 Sportback 45 TFSI S-Line', 'Ford Mustang Fastback V8 1967', 'Toyota HiAce Grand Cabin VIP 12 Places', 'Kia Sorento GT-Line 7 Places');
  END IF;


  -- Partner 11: partner11@far7tek.tn
  SELECT id INTO _uid FROM auth.users WHERE email = 'partner11@far7tek.tn';
  IF _uid IS NOT NULL THEN
    INSERT INTO public.profiles (id, first_name, last_name, phone)
    VALUES (_uid, 'Marwen', 'Ben Amor', '+216 99 378 190')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (_uid, 'partner')
    ON CONFLICT (user_id, role) DO NOTHING;

    UPDATE public.cars
    SET owner_id = _uid
    WHERE name IN ('Mercedes-Benz Classe E 220d Pack Nuit', 'Audi A6 S-Line 40 TDI', 'Jaguar Mark II 3.8', 'Toyota HiAce Commuter 14 Places', 'Dacia Jogger Extreme 7 Places');
  END IF;


  -- Partner 12: partner12@far7tek.tn
  SELECT id INTO _uid FROM auth.users WHERE email = 'partner12@far7tek.tn';
  IF _uid IS NOT NULL THEN
    INSERT INTO public.profiles (id, first_name, last_name, phone)
    VALUES (_uid, 'Omar', 'Riahi', '+216 53 410 822')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (_uid, 'partner')
    ON CONFLICT (user_id, role) DO NOTHING;

    UPDATE public.cars
    SET owner_id = _uid
    WHERE name IN ('Mercedes-Benz CLE Coupé 300 AMG', 'Audi Q8 S-Line 50 TDI', 'Aston Martin DB11 V8', 'Toyota Proace Verso VIP 9 Places', 'Dacia Lodgy Stepway 7 Places');
  END IF;


  -- Partner 13: partner13@far7tek.tn
  SELECT id INTO _uid FROM auth.users WHERE email = 'partner13@far7tek.tn';
  IF _uid IS NOT NULL THEN
    INSERT INTO public.profiles (id, first_name, last_name, phone)
    VALUES (_uid, 'Hamza', 'Belhadj', '+216 28 554 901')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (_uid, 'partner')
    ON CONFLICT (user_id, role) DO NOTHING;

    UPDATE public.cars
    SET owner_id = _uid
    WHERE name IN ('Mercedes-Benz CLS 400d AMG', 'Audi A5 Sportback S-Line', 'Mercedes-Benz Classe V 250d Exclusive', 'Toyota Land Cruiser Prado VX 7 Places', 'Nissan NV300 Combi 9 Places');
  END IF;


  -- Partner 14: partner14@far7tek.tn
  SELECT id INTO _uid FROM auth.users WHERE email = 'partner14@far7tek.tn';
  IF _uid IS NOT NULL THEN
    INSERT INTO public.profiles (id, first_name, last_name, phone)
    VALUES (_uid, 'Tarak', 'Zaier', '+216 94 231 778')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (_uid, 'partner')
    ON CONFLICT (user_id, role) DO NOTHING;

    UPDATE public.cars
    SET owner_id = _uid
    WHERE name IN ('Mercedes-Benz CLA 200 AMG Line', 'Range Rover Vogue Autobiography', 'Mercedes-Benz Classe V 300d AMG Line', 'Peugeot Traveller VIP Business 8 Places', 'Opel Zafira Life Innovation 9 Places');
  END IF;


  -- Partner 15: partner15@far7tek.tn
  SELECT id INTO _uid FROM auth.users WHERE email = 'partner15@far7tek.tn';
  IF _uid IS NOT NULL THEN
    INSERT INTO public.profiles (id, first_name, last_name, phone)
    VALUES (_uid, 'Firas', 'Chebbi', '+216 51 890 345')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (_uid, 'partner')
    ON CONFLICT (user_id, role) DO NOTHING;

    UPDATE public.cars
    SET owner_id = _uid
    WHERE name IN ('Mercedes-AMG G63 V8 Biturbo', 'Range Rover Sport HSE Dynamic', 'Mercedes-Benz Vito Tourer PRO', 'Peugeot Traveller Allure 9 Places', 'Fiat Ducato Panorama 15 Places');
  END IF;


  -- Partner 16: partner16@far7tek.tn
  SELECT id INTO _uid FROM auth.users WHERE email = 'partner16@far7tek.tn';
  IF _uid IS NOT NULL THEN
    INSERT INTO public.profiles (id, first_name, last_name, phone)
    VALUES (_uid, 'Nizar', 'Louati', '+216 20 443 612')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (_uid, 'partner')
    ON CONFLICT (user_id, role) DO NOTHING;

    UPDATE public.cars
    SET owner_id = _uid
    WHERE name IN ('Mercedes-Benz GLE 350de Coupé AMG', 'Range Rover Velar R-Dynamic', 'Mercedes-Benz Vito Select Long', 'Peugeot Expert Combi 9 Places', 'Iveco Daily Minibus VIP 16 Places');
  END IF;


  -- Partner 17: partner17@far7tek.tn
  SELECT id INTO _uid FROM auth.users WHERE email = 'partner17@far7tek.tn';
  IF _uid IS NOT NULL THEN
    INSERT INTO public.profiles (id, first_name, last_name, phone)
    VALUES (_uid, 'Bilel', 'Messaoudi', '+216 96 112 559')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (_uid, 'partner')
    ON CONFLICT (user_id, role) DO NOTHING;

    UPDATE public.cars
    SET owner_id = _uid
    WHERE name IN ('Porsche Panamera 4S', 'Range Rover Evoque HSE', 'Mercedes-Benz Sprinter 519 VIP Lounge', 'Peugeot 5008 GT Line 7 Places', 'Mercedes-Benz Sprinter 519 VIP 19 Places');
  END IF;


  -- Partner 18: partner18@far7tek.tn
  SELECT id INTO _uid FROM auth.users WHERE email = 'partner18@far7tek.tn';
  IF _uid IS NOT NULL THEN
    INSERT INTO public.profiles (id, first_name, last_name, phone)
    VALUES (_uid, 'Wissem', 'Ben Fredj', '+216 54 789 203')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (_uid, 'partner')
    ON CONFLICT (user_id, role) DO NOTHING;

    UPDATE public.cars
    SET owner_id = _uid
    WHERE name IN ('Porsche Panamera GTS', 'Jaguar XF Portfolio', 'Mercedes-Benz Sprinter Transfer', 'Citroën SpaceTourer Business Lounge', 'Peugeot Rifter Long 7 Places');
  END IF;


  -- Partner 19: partner19@far7tek.tn
  SELECT id INTO _uid FROM auth.users WHERE email = 'partner19@far7tek.tn';
  IF _uid IS NOT NULL THEN
    INSERT INTO public.profiles (id, first_name, last_name, phone)
    VALUES (_uid, 'Hichem', 'Guesmi', '+216 27 605 114')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (_uid, 'partner')
    ON CONFLICT (user_id, role) DO NOTHING;

    UPDATE public.cars
    SET owner_id = _uid
    WHERE name IN ('Porsche Macan GTS', 'Jaguar XJ L Sovereign', 'Volkswagen Caravelle T6.1 Highline', 'Citroën SpaceTourer Feel 9 Places', 'Ford Galaxy Titanium 7 Places');
  END IF;


  -- Partner 20: partner20@far7tek.tn
  SELECT id INTO _uid FROM auth.users WHERE email = 'partner20@far7tek.tn';
  IF _uid IS NOT NULL THEN
    INSERT INTO public.profiles (id, first_name, last_name, phone)
    VALUES (_uid, 'Riadh', 'Sassi', '+216 95 332 890')
    ON CONFLICT (id) DO UPDATE SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

    INSERT INTO public.user_roles (user_id, role)
    VALUES (_uid, 'partner')
    ON CONFLICT (user_id, role) DO NOTHING;

    UPDATE public.cars
    SET owner_id = _uid
    WHERE name IN ('Porsche Cayenne Coupé Platinum', 'Maserati Ghibli Modena', 'Volkswagen Caravelle T6 Trendline', 'Citroën Grand C4 SpaceTourer 7 Places', 'Toyota Coaster VIP 22 Places');
  END IF;

END $$;
