-- ============================================================================
-- MIGRATION : Notifications push (FCM)
-- ============================================================================
-- Crée la table `device_tokens` pour stocker les tokens FCM des appareils
-- de chaque utilisateur. Un utilisateur peut avoir plusieurs tokens
-- (téléphone + tablette + web).
--
-- À exécuter dans le SQL Editor de Supabase APRÈS schema.sql.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.device_tokens (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID         NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  token       TEXT         NOT NULL UNIQUE,
  platform    TEXT         NOT NULL CHECK (platform IN ('android', 'ios', 'web', 'other')),
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON public.device_tokens(user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- RLS
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "device_tokens_select"  ON public.device_tokens;
DROP POLICY IF EXISTS "device_tokens_insert"  ON public.device_tokens;
DROP POLICY IF EXISTS "device_tokens_update"  ON public.device_tokens;
DROP POLICY IF EXISTS "device_tokens_delete"  ON public.device_tokens;

-- En mode DEV : permissif (anon + authenticated peuvent tout faire)
-- ⚠️ À DURCIR avant prod (limiter aux tokens du user courant uniquement)
CREATE POLICY "device_tokens_select" ON public.device_tokens
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "device_tokens_insert" ON public.device_tokens
  FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "device_tokens_update" ON public.device_tokens
  FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "device_tokens_delete" ON public.device_tokens
  FOR DELETE TO anon, authenticated USING (true);

-- ============================================================================
-- ✅ FIN
-- ============================================================================
