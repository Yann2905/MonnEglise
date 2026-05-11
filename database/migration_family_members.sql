-- ============================================================================
-- MIGRATION : Création de la table de jointure family_members
-- ============================================================================
-- Remplace la double-écriture families.member_ids[] / users.family_ids[]
-- par une vraie table de jointure (single source of truth).
--
-- À exécuter dans le SQL Editor de Supabase APRÈS avoir un schéma déjà créé
-- avec schema.sql.
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Crée la table de jointure
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.family_members (
  family_id   UUID         NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
  user_id     UUID         NOT NULL REFERENCES public.users(id)    ON DELETE CASCADE,
  joined_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  PRIMARY KEY (family_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_family_members_family_id ON public.family_members(family_id);
CREATE INDEX IF NOT EXISTS idx_family_members_user_id   ON public.family_members(user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Migrer les données existantes (familles.member_ids[] → family_members)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO public.family_members (family_id, user_id)
SELECT f.id, member_id::UUID
FROM public.families f, UNNEST(f.member_ids) AS member_id
WHERE member_id IS NOT NULL
  AND member_id != ''
ON CONFLICT (family_id, user_id) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Vue pour faciliter les requêtes legacy (les écrans liront cette vue
--    avec family_ids ou member_ids dérivés)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.v_users_with_families AS
SELECT
  u.*,
  COALESCE(
    (SELECT array_agg(fm.family_id::TEXT)
     FROM public.family_members fm
     WHERE fm.user_id = u.id), '{}'::TEXT[]
  ) AS family_ids_resolved
FROM public.users u;

CREATE OR REPLACE VIEW public.v_families_with_members AS
SELECT
  f.*,
  COALESCE(
    (SELECT array_agg(fm.user_id::TEXT)
     FROM public.family_members fm
     WHERE fm.family_id = f.id), '{}'::TEXT[]
  ) AS member_ids_resolved,
  (SELECT COUNT(*) FROM public.family_members fm WHERE fm.family_id = f.id) AS member_count_resolved
FROM public.families f;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. RLS sur la table de jointure
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.family_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "family_members_read"  ON public.family_members;
DROP POLICY IF EXISTS "family_members_write" ON public.family_members;
CREATE POLICY "family_members_read"  ON public.family_members FOR SELECT TO authenticated USING (true);
CREATE POLICY "family_members_write" ON public.family_members FOR ALL    TO authenticated USING (true) WITH CHECK (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. (OPTIONNEL — à exécuter quand le code est complètement migré)
--    Suppression des anciennes colonnes redondantes
-- ─────────────────────────────────────────────────────────────────────────────
-- ALTER TABLE public.families DROP COLUMN IF EXISTS member_ids;
-- ALTER TABLE public.users    DROP COLUMN IF EXISTS family_ids;

-- Pour le moment on les laisse pour compat ; on bascule la lecture/écriture
-- côté Dart vers family_members et on supprimera les colonnes plus tard.
