-- ============================================================================
-- MIGRATION : Suppression définitive des colonnes legacy
-- ============================================================================
-- ⚠️ À EXÉCUTER UNIQUEMENT après avoir testé que tout marche avec le nouveau
--    code (qui n'écrit plus ces colonnes). Idéalement après quelques jours
--    de prod sans bug.
--
-- Ces colonnes ne sont plus la source de vérité :
--   • families.member_count    → calculé via v_families_enriched
--   • families.member_ids[]    → remplacé par table family_members
--   • users.family_ids[]       → remplacé par table family_members
--
-- ⚠️ ATTENTION : cette migration est IRRÉVERSIBLE. Pense à un backup avant.
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Drop les VUES qui dépendent encore de ces colonnes
--    (créées par migration_family_members.sql à l'époque pour la rétro-compat)
-- ─────────────────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS public.v_users_with_families;
DROP VIEW IF EXISTS public.v_families_with_members;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Drop les colonnes legacy
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.families DROP COLUMN IF EXISTS member_count;
ALTER TABLE public.families DROP COLUMN IF EXISTS member_ids;
ALTER TABLE public.users    DROP COLUMN IF EXISTS family_ids;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. (Optionnel) Recréer les vues legacy en mode "compat", lisant depuis
--    family_members. Utile si du vieux code Dart cherche encore ces vues.
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

-- ============================================================================
-- ✅ FIN
-- ============================================================================
