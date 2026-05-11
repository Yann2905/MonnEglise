-- ============================================================================
-- ⚠️  MIGRATION DEV — Rendre users.auth_id nullable
-- ============================================================================
-- Pourquoi : le bypass DEV de l'app crée des fake users avec un auth_id
-- arbitraire (UUID 00000000-...) qui n'existe pas dans auth.users.
-- Avec NOT NULL + FK strict, l'insert plante silencieusement.
--
-- Cette migration assouplit la contrainte pour permettre auth_id NULL.
-- Les vrais users (inscrits via Twilio + OTP) continuent d'avoir leur
-- auth_id rempli normalement.
--
-- ⛔ NE PAS appliquer en production stricte si tu veux garder l'intégrité
-- forte entre auth.users et public.users.
-- ============================================================================

-- 1. Drop l'unique constraint puis le NOT NULL
ALTER TABLE public.users
  ALTER COLUMN auth_id DROP NOT NULL;

-- 2. La FK auth_id → auth.users(id) doit accepter NULL → c'est déjà le cas
--    par défaut quand la colonne est nullable. Aucun changement nécessaire.

-- 3. L'index UNIQUE sur auth_id reste OK : les NULL ne violent pas l'unicité
--    en Postgres (plusieurs NULL autorisés).

-- ============================================================================
-- ✅ FIN
-- ============================================================================
