-- ==============================================================================
-- FAR7TEK - CRÉATION COMPTE ADMINISTRATEUR
-- À exécuter dans Supabase Studio -> SQL Editor -> New Query
--
-- Identifiants :
-- Email    : admin@far7tek.tn
-- Password : Admin2026!
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

DO $$
DECLARE
  _uid uuid;
  _email text := 'admin@far7tek.tn';
  _password text := 'Admin2026!';
  _pwd_hash text;
BEGIN
  -- Hash standard bcrypt pour Supabase GoTrue
  _pwd_hash := extensions.crypt(_password, extensions.gen_salt('bf', 10));

  -- 1. Récupération ou création dans auth.users
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
      jsonb_build_object('first_name', 'Admin', 'last_name', 'Far7tek', 'phone', '+216 71 000 000'),
      now(),
      now(),
      '', '', '', '', '', '', '', '',
      false,
      false,
      true
    );
  ELSE
    UPDATE auth.users
    SET email_confirmed_at = COALESCE(email_confirmed_at, now()),
        encrypted_password = _pwd_hash,
        raw_app_meta_data = '{"provider":"email","providers":["email"]}'::jsonb,
        raw_user_meta_data = jsonb_build_object('first_name', 'Admin', 'last_name', 'Far7tek', 'phone', '+216 71 000 000'),
        updated_at = now()
    WHERE id = _uid;
  END IF;

  -- 2. Création de l'identité GoTrue dans auth.identities
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
  VALUES (_uid, 'Admin', 'Far7tek', '+216 71 000 000')
  ON CONFLICT (id) DO UPDATE
    SET first_name = EXCLUDED.first_name,
        last_name = EXCLUDED.last_name,
        phone = EXCLUDED.phone;

  -- 4. Rôle Administrateur
  INSERT INTO public.user_roles (user_id, role)
  VALUES (_uid, 'admin')
  ON CONFLICT (user_id, role) DO NOTHING;

END $$;
