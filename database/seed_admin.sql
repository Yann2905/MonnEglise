-- ============================================================================
-- Crée un admin avec le numéro +2250575343846
-- ============================================================================
-- À exécuter APRÈS schema.sql dans le SQL Editor de Supabase.
-- Insère un user dans auth.users (Auth Supabase) ET dans public.users (profil).
-- Le numéro est marqué comme confirmé (phone_confirmed_at = NOW()).
-- ============================================================================

DO $$
DECLARE
  v_auth_id     UUID := gen_random_uuid();
  v_user_id     UUID := gen_random_uuid();
  v_phone       TEXT := '+2250575343846';
  v_member_code TEXT := 'ADM001';   -- code que les futurs membres saisiront pour s'inscrire
BEGIN
  -- ── 1. Crée le user dans auth.users (table Supabase Auth) ─────────────
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    phone,
    phone_confirmed_at,
    confirmation_token,
    recovery_token,
    email_change,
    email_change_token_new,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    is_anonymous,
    is_sso_user
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    v_auth_id,
    'authenticated',
    'authenticated',
    NULL,
    '',
    NULL,
    v_phone,
    NOW(),
    '',
    '',
    '',
    '',
    '{"provider":"phone","providers":["phone"]}'::jsonb,
    '{}'::jsonb,
    NOW(),
    NOW(),
    false,
    false
  );

  -- ── 2. Crée le profil admin dans public.users ──────────────────────────
  INSERT INTO public.users (
    id,
    auth_id,
    role_global,
    phone,
    first_name,
    last_name,
    quartier,
    member_code,
    is_responsible,
    family_ids
  ) VALUES (
    v_user_id,
    v_auth_id,
    'admin',
    v_phone,
    'Yann',          -- ← change si tu veux
    'Admin',         -- ← change si tu veux
    'Cocody',        -- ← change si tu veux
    v_member_code,
    true,
    '{}'
  );

  RAISE NOTICE '────────────────────────────────────────────';
  RAISE NOTICE 'Admin créé avec succès !';
  RAISE NOTICE 'Téléphone   : %', v_phone;
  RAISE NOTICE 'auth_id     : %', v_auth_id;
  RAISE NOTICE 'user_id     : %', v_user_id;
  RAISE NOTICE 'Code membre : %  (à donner aux futurs membres)', v_member_code;
  RAISE NOTICE '────────────────────────────────────────────';
END $$;
