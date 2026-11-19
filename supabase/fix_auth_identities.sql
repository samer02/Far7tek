-- ==============================================================================
-- Fix 500 Internal Server Error on Supabase GoTrue Auth
-- Fixes NULL boolean/string columns (is_sso_user, is_anonymous, tokens) in auth.users
-- and sets up corresponding auth.identities records for email password sign-in.
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. Fix global boolean defaults in auth.users (prevents Go scan crash on NULL)
UPDATE auth.users
SET is_sso_user = false WHERE is_sso_user IS NULL;
UPDATE auth.users
SET is_anonymous = false WHERE is_anonymous IS NULL;
UPDATE auth.users
SET is_super_admin = false WHERE is_super_admin IS NULL;
UPDATE auth.users
SET confirmation_token = COALESCE(confirmation_token, ''),
    recovery_token = COALESCE(recovery_token, ''),
    email_change_token_new = COALESCE(email_change_token_new, ''),
    email_change = COALESCE(email_change, ''),
    phone_change = COALESCE(phone_change, ''),
    phone_change_token = COALESCE(phone_change_token, ''),
    email_change_token_current = COALESCE(email_change_token_current, ''),
    reauthentication_token = COALESCE(reauthentication_token, '');

-- 2. Upsert each partner user with complete GoTrue-compliant fields and identity

-- Partner: partner1@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  'ee1141f3-af04-5ad1-a0f3-658a97737453', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner1@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Mohamed', 'last_name', 'Ben Salem', 'phone', '+216 98 214 550'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Mohamed', 'last_name', 'Ben Salem', 'phone', '+216 98 214 550'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = 'ee1141f3-af04-5ad1-a0f3-658a97737453';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  'ee1141f3-af04-5ad1-a0f3-658a97737453',
  'ee1141f3-af04-5ad1-a0f3-658a97737453',
  json_build_object('sub', 'ee1141f3-af04-5ad1-a0f3-658a97737453', 'email', 'partner1@far7tek.tn')::jsonb,
  'email',
  'ee1141f3-af04-5ad1-a0f3-658a97737453',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('ee1141f3-af04-5ad1-a0f3-658a97737453', 'Mohamed', 'Ben Salem', '+216 98 214 550')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('ee1141f3-af04-5ad1-a0f3-658a97737453', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner2@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '1f33d55e-271e-57ce-b2b7-250e2a2823bd', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner2@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Youssef', 'last_name', 'Trabelsi', 'phone', '+216 22 341 890'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Youssef', 'last_name', 'Trabelsi', 'phone', '+216 22 341 890'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '1f33d55e-271e-57ce-b2b7-250e2a2823bd';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '1f33d55e-271e-57ce-b2b7-250e2a2823bd',
  '1f33d55e-271e-57ce-b2b7-250e2a2823bd',
  json_build_object('sub', '1f33d55e-271e-57ce-b2b7-250e2a2823bd', 'email', 'partner2@far7tek.tn')::jsonb,
  'email',
  '1f33d55e-271e-57ce-b2b7-250e2a2823bd',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('1f33d55e-271e-57ce-b2b7-250e2a2823bd', 'Youssef', 'Trabelsi', '+216 22 341 890')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('1f33d55e-271e-57ce-b2b7-250e2a2823bd', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner3@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '058ae746-39ca-5bf6-bdd7-6dd945132d37', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner3@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Khalil', 'last_name', 'Bouazizi', 'phone', '+216 50 678 123'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Khalil', 'last_name', 'Bouazizi', 'phone', '+216 50 678 123'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '058ae746-39ca-5bf6-bdd7-6dd945132d37';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '058ae746-39ca-5bf6-bdd7-6dd945132d37',
  '058ae746-39ca-5bf6-bdd7-6dd945132d37',
  json_build_object('sub', '058ae746-39ca-5bf6-bdd7-6dd945132d37', 'email', 'partner3@far7tek.tn')::jsonb,
  'email',
  '058ae746-39ca-5bf6-bdd7-6dd945132d37',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('058ae746-39ca-5bf6-bdd7-6dd945132d37', 'Khalil', 'Bouazizi', '+216 50 678 123')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('058ae746-39ca-5bf6-bdd7-6dd945132d37', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner4@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '31f603c0-2685-5239-b304-2e25c2f09c50', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner4@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Karim', 'last_name', 'Dridi', 'phone', '+216 97 452 310'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Karim', 'last_name', 'Dridi', 'phone', '+216 97 452 310'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '31f603c0-2685-5239-b304-2e25c2f09c50';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '31f603c0-2685-5239-b304-2e25c2f09c50',
  '31f603c0-2685-5239-b304-2e25c2f09c50',
  json_build_object('sub', '31f603c0-2685-5239-b304-2e25c2f09c50', 'email', 'partner4@far7tek.tn')::jsonb,
  'email',
  '31f603c0-2685-5239-b304-2e25c2f09c50',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('31f603c0-2685-5239-b304-2e25c2f09c50', 'Karim', 'Dridi', '+216 97 452 310')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('31f603c0-2685-5239-b304-2e25c2f09c50', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner5@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  'd6f066a7-ce2d-57e1-b422-16ce0a1311fc', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner5@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Anis', 'last_name', 'Gharbi', 'phone', '+216 29 118 765'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Anis', 'last_name', 'Gharbi', 'phone', '+216 29 118 765'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = 'd6f066a7-ce2d-57e1-b422-16ce0a1311fc';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  'd6f066a7-ce2d-57e1-b422-16ce0a1311fc',
  'd6f066a7-ce2d-57e1-b422-16ce0a1311fc',
  json_build_object('sub', 'd6f066a7-ce2d-57e1-b422-16ce0a1311fc', 'email', 'partner5@far7tek.tn')::jsonb,
  'email',
  'd6f066a7-ce2d-57e1-b422-16ce0a1311fc',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('d6f066a7-ce2d-57e1-b422-16ce0a1311fc', 'Anis', 'Gharbi', '+216 29 118 765')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('d6f066a7-ce2d-57e1-b422-16ce0a1311fc', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner6@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '2ac6af30-1c87-52fe-a2c1-d460fd518503', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner6@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Sami', 'last_name', 'Mansour', 'phone', '+216 55 902 431'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Sami', 'last_name', 'Mansour', 'phone', '+216 55 902 431'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '2ac6af30-1c87-52fe-a2c1-d460fd518503';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '2ac6af30-1c87-52fe-a2c1-d460fd518503',
  '2ac6af30-1c87-52fe-a2c1-d460fd518503',
  json_build_object('sub', '2ac6af30-1c87-52fe-a2c1-d460fd518503', 'email', 'partner6@far7tek.tn')::jsonb,
  'email',
  '2ac6af30-1c87-52fe-a2c1-d460fd518503',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('2ac6af30-1c87-52fe-a2c1-d460fd518503', 'Sami', 'Mansour', '+216 55 902 431')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('2ac6af30-1c87-52fe-a2c1-d460fd518503', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner7@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '25c6d25e-8789-551c-8451-4414d67f9ca1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner7@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Mehdi', 'last_name', 'Chaabane', 'phone', '+216 26 734 119'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Mehdi', 'last_name', 'Chaabane', 'phone', '+216 26 734 119'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '25c6d25e-8789-551c-8451-4414d67f9ca1';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '25c6d25e-8789-551c-8451-4414d67f9ca1',
  '25c6d25e-8789-551c-8451-4414d67f9ca1',
  json_build_object('sub', '25c6d25e-8789-551c-8451-4414d67f9ca1', 'email', 'partner7@far7tek.tn')::jsonb,
  'email',
  '25c6d25e-8789-551c-8451-4414d67f9ca1',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('25c6d25e-8789-551c-8451-4414d67f9ca1', 'Mehdi', 'Chaabane', '+216 26 734 119')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('25c6d25e-8789-551c-8451-4414d67f9ca1', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner8@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '6476e667-9318-55ea-a06f-1eafc54461a7', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner8@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Skander', 'last_name', 'Khemir', 'phone', '+216 92 884 201'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Skander', 'last_name', 'Khemir', 'phone', '+216 92 884 201'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '6476e667-9318-55ea-a06f-1eafc54461a7';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '6476e667-9318-55ea-a06f-1eafc54461a7',
  '6476e667-9318-55ea-a06f-1eafc54461a7',
  json_build_object('sub', '6476e667-9318-55ea-a06f-1eafc54461a7', 'email', 'partner8@far7tek.tn')::jsonb,
  'email',
  '6476e667-9318-55ea-a06f-1eafc54461a7',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('6476e667-9318-55ea-a06f-1eafc54461a7', 'Skander', 'Khemir', '+216 92 884 201')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('6476e667-9318-55ea-a06f-1eafc54461a7', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner9@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '23338aeb-00c2-526f-bf21-a6fb3c662d7f', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner9@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Zied', 'last_name', 'Jaziri', 'phone', '+216 58 120 944'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Zied', 'last_name', 'Jaziri', 'phone', '+216 58 120 944'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '23338aeb-00c2-526f-bf21-a6fb3c662d7f';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '23338aeb-00c2-526f-bf21-a6fb3c662d7f',
  '23338aeb-00c2-526f-bf21-a6fb3c662d7f',
  json_build_object('sub', '23338aeb-00c2-526f-bf21-a6fb3c662d7f', 'email', 'partner9@far7tek.tn')::jsonb,
  'email',
  '23338aeb-00c2-526f-bf21-a6fb3c662d7f',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('23338aeb-00c2-526f-bf21-a6fb3c662d7f', 'Zied', 'Jaziri', '+216 58 120 944')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('23338aeb-00c2-526f-bf21-a6fb3c662d7f', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner10@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  'cb53d47b-d24f-52d2-bcf8-362ba68cf90b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner10@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Walid', 'last_name', 'Ayari', 'phone', '+216 24 665 302'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Walid', 'last_name', 'Ayari', 'phone', '+216 24 665 302'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = 'cb53d47b-d24f-52d2-bcf8-362ba68cf90b';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  'cb53d47b-d24f-52d2-bcf8-362ba68cf90b',
  'cb53d47b-d24f-52d2-bcf8-362ba68cf90b',
  json_build_object('sub', 'cb53d47b-d24f-52d2-bcf8-362ba68cf90b', 'email', 'partner10@far7tek.tn')::jsonb,
  'email',
  'cb53d47b-d24f-52d2-bcf8-362ba68cf90b',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('cb53d47b-d24f-52d2-bcf8-362ba68cf90b', 'Walid', 'Ayari', '+216 24 665 302')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('cb53d47b-d24f-52d2-bcf8-362ba68cf90b', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner11@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '6eccbdad-f7ee-54c2-96b4-ef7a8ac008c6', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner11@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Marwen', 'last_name', 'Ben Amor', 'phone', '+216 99 378 190'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Marwen', 'last_name', 'Ben Amor', 'phone', '+216 99 378 190'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '6eccbdad-f7ee-54c2-96b4-ef7a8ac008c6';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '6eccbdad-f7ee-54c2-96b4-ef7a8ac008c6',
  '6eccbdad-f7ee-54c2-96b4-ef7a8ac008c6',
  json_build_object('sub', '6eccbdad-f7ee-54c2-96b4-ef7a8ac008c6', 'email', 'partner11@far7tek.tn')::jsonb,
  'email',
  '6eccbdad-f7ee-54c2-96b4-ef7a8ac008c6',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('6eccbdad-f7ee-54c2-96b4-ef7a8ac008c6', 'Marwen', 'Ben Amor', '+216 99 378 190')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('6eccbdad-f7ee-54c2-96b4-ef7a8ac008c6', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner12@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '35fa36c8-c32f-511a-9db3-2f140515ff84', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner12@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Omar', 'last_name', 'Riahi', 'phone', '+216 53 410 822'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Omar', 'last_name', 'Riahi', 'phone', '+216 53 410 822'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '35fa36c8-c32f-511a-9db3-2f140515ff84';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '35fa36c8-c32f-511a-9db3-2f140515ff84',
  '35fa36c8-c32f-511a-9db3-2f140515ff84',
  json_build_object('sub', '35fa36c8-c32f-511a-9db3-2f140515ff84', 'email', 'partner12@far7tek.tn')::jsonb,
  'email',
  '35fa36c8-c32f-511a-9db3-2f140515ff84',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('35fa36c8-c32f-511a-9db3-2f140515ff84', 'Omar', 'Riahi', '+216 53 410 822')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('35fa36c8-c32f-511a-9db3-2f140515ff84', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner13@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '69eff6ee-12e1-501f-9f55-9f30fc2205ea', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner13@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Hamza', 'last_name', 'Belhadj', 'phone', '+216 28 554 901'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Hamza', 'last_name', 'Belhadj', 'phone', '+216 28 554 901'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '69eff6ee-12e1-501f-9f55-9f30fc2205ea';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '69eff6ee-12e1-501f-9f55-9f30fc2205ea',
  '69eff6ee-12e1-501f-9f55-9f30fc2205ea',
  json_build_object('sub', '69eff6ee-12e1-501f-9f55-9f30fc2205ea', 'email', 'partner13@far7tek.tn')::jsonb,
  'email',
  '69eff6ee-12e1-501f-9f55-9f30fc2205ea',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('69eff6ee-12e1-501f-9f55-9f30fc2205ea', 'Hamza', 'Belhadj', '+216 28 554 901')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('69eff6ee-12e1-501f-9f55-9f30fc2205ea', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner14@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '61a078eb-0f69-5d97-9fff-4b4bd5ccfcfc', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner14@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Tarak', 'last_name', 'Zaier', 'phone', '+216 94 231 778'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Tarak', 'last_name', 'Zaier', 'phone', '+216 94 231 778'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '61a078eb-0f69-5d97-9fff-4b4bd5ccfcfc';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '61a078eb-0f69-5d97-9fff-4b4bd5ccfcfc',
  '61a078eb-0f69-5d97-9fff-4b4bd5ccfcfc',
  json_build_object('sub', '61a078eb-0f69-5d97-9fff-4b4bd5ccfcfc', 'email', 'partner14@far7tek.tn')::jsonb,
  'email',
  '61a078eb-0f69-5d97-9fff-4b4bd5ccfcfc',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('61a078eb-0f69-5d97-9fff-4b4bd5ccfcfc', 'Tarak', 'Zaier', '+216 94 231 778')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('61a078eb-0f69-5d97-9fff-4b4bd5ccfcfc', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner15@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  'e4ae4dd2-e903-5513-97ae-407c83c67742', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner15@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Firas', 'last_name', 'Chebbi', 'phone', '+216 51 890 345'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Firas', 'last_name', 'Chebbi', 'phone', '+216 51 890 345'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = 'e4ae4dd2-e903-5513-97ae-407c83c67742';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  'e4ae4dd2-e903-5513-97ae-407c83c67742',
  'e4ae4dd2-e903-5513-97ae-407c83c67742',
  json_build_object('sub', 'e4ae4dd2-e903-5513-97ae-407c83c67742', 'email', 'partner15@far7tek.tn')::jsonb,
  'email',
  'e4ae4dd2-e903-5513-97ae-407c83c67742',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('e4ae4dd2-e903-5513-97ae-407c83c67742', 'Firas', 'Chebbi', '+216 51 890 345')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('e4ae4dd2-e903-5513-97ae-407c83c67742', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner16@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '751c7cb9-930f-5032-a391-66b5c29f355d', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner16@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Nizar', 'last_name', 'Louati', 'phone', '+216 20 443 612'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Nizar', 'last_name', 'Louati', 'phone', '+216 20 443 612'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '751c7cb9-930f-5032-a391-66b5c29f355d';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '751c7cb9-930f-5032-a391-66b5c29f355d',
  '751c7cb9-930f-5032-a391-66b5c29f355d',
  json_build_object('sub', '751c7cb9-930f-5032-a391-66b5c29f355d', 'email', 'partner16@far7tek.tn')::jsonb,
  'email',
  '751c7cb9-930f-5032-a391-66b5c29f355d',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('751c7cb9-930f-5032-a391-66b5c29f355d', 'Nizar', 'Louati', '+216 20 443 612')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('751c7cb9-930f-5032-a391-66b5c29f355d', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner17@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  'fd9cf00c-7bab-59b6-a072-0a287fbefc6f', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner17@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Bilel', 'last_name', 'Messaoudi', 'phone', '+216 96 112 559'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Bilel', 'last_name', 'Messaoudi', 'phone', '+216 96 112 559'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = 'fd9cf00c-7bab-59b6-a072-0a287fbefc6f';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  'fd9cf00c-7bab-59b6-a072-0a287fbefc6f',
  'fd9cf00c-7bab-59b6-a072-0a287fbefc6f',
  json_build_object('sub', 'fd9cf00c-7bab-59b6-a072-0a287fbefc6f', 'email', 'partner17@far7tek.tn')::jsonb,
  'email',
  'fd9cf00c-7bab-59b6-a072-0a287fbefc6f',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('fd9cf00c-7bab-59b6-a072-0a287fbefc6f', 'Bilel', 'Messaoudi', '+216 96 112 559')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('fd9cf00c-7bab-59b6-a072-0a287fbefc6f', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner18@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '77d05462-ef43-5442-9b25-76e8c97851a9', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner18@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Wissem', 'last_name', 'Ben Fredj', 'phone', '+216 54 789 203'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Wissem', 'last_name', 'Ben Fredj', 'phone', '+216 54 789 203'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '77d05462-ef43-5442-9b25-76e8c97851a9';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '77d05462-ef43-5442-9b25-76e8c97851a9',
  '77d05462-ef43-5442-9b25-76e8c97851a9',
  json_build_object('sub', '77d05462-ef43-5442-9b25-76e8c97851a9', 'email', 'partner18@far7tek.tn')::jsonb,
  'email',
  '77d05462-ef43-5442-9b25-76e8c97851a9',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('77d05462-ef43-5442-9b25-76e8c97851a9', 'Wissem', 'Ben Fredj', '+216 54 789 203')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('77d05462-ef43-5442-9b25-76e8c97851a9', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner19@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  'aa941779-ac29-5f31-8d63-0ba467008ed2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner19@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Hichem', 'last_name', 'Guesmi', 'phone', '+216 27 605 114'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Hichem', 'last_name', 'Guesmi', 'phone', '+216 27 605 114'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = 'aa941779-ac29-5f31-8d63-0ba467008ed2';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  'aa941779-ac29-5f31-8d63-0ba467008ed2',
  'aa941779-ac29-5f31-8d63-0ba467008ed2',
  json_build_object('sub', 'aa941779-ac29-5f31-8d63-0ba467008ed2', 'email', 'partner19@far7tek.tn')::jsonb,
  'email',
  'aa941779-ac29-5f31-8d63-0ba467008ed2',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('aa941779-ac29-5f31-8d63-0ba467008ed2', 'Hichem', 'Guesmi', '+216 27 605 114')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('aa941779-ac29-5f31-8d63-0ba467008ed2', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;

-- Partner: partner20@far7tek.tn
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  phone_change, phone_change_token, email_change_token_current, reauthentication_token,
  is_sso_user, is_anonymous, is_super_admin
) VALUES (
  '542bdad5-7c8c-5023-9594-98af51cc730c', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'partner20@far7tek.tn', crypt('Partner2026!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  jsonb_build_object('first_name', 'Riadh', 'last_name', 'Sassi', 'phone', '+216 95 332 890'),
  now(), now(),
  '', '', '', '', '', '', '', '',
  false, false, false
) ON CONFLICT (id) DO UPDATE SET
  encrypted_password = crypt('Partner2026!', gen_salt('bf')),
  email_confirmed_at = coalesce(auth.users.email_confirmed_at, now()),
  raw_app_meta_data = '{"provider":"email","providers":["email"]}',
  raw_user_meta_data = jsonb_build_object('first_name', 'Riadh', 'last_name', 'Sassi', 'phone', '+216 95 332 890'),
  is_sso_user = false,
  is_anonymous = false,
  is_super_admin = false,
  updated_at = now();

-- Delete any stale identity for this user to avoid duplicate key or mismatch
DELETE FROM auth.identities WHERE user_id = '542bdad5-7c8c-5023-9594-98af51cc730c';

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
) VALUES (
  '542bdad5-7c8c-5023-9594-98af51cc730c',
  '542bdad5-7c8c-5023-9594-98af51cc730c',
  json_build_object('sub', '542bdad5-7c8c-5023-9594-98af51cc730c', 'email', 'partner20@far7tek.tn')::jsonb,
  'email',
  '542bdad5-7c8c-5023-9594-98af51cc730c',
  now(), now(), now()
);

INSERT INTO public.profiles (id, first_name, last_name, phone)
VALUES ('542bdad5-7c8c-5023-9594-98af51cc730c', 'Riadh', 'Sassi', '+216 95 332 890')
ON CONFLICT (id) DO UPDATE SET
  first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name, phone = EXCLUDED.phone;

INSERT INTO public.user_roles (user_id, role)
VALUES ('542bdad5-7c8c-5023-9594-98af51cc730c', 'partner')
ON CONFLICT (user_id, role) DO NOTHING;
