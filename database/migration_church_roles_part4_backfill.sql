-- ============================================================================
-- PART 4/4 — Backfill (peut être lent si beaucoup d'églises/users)
-- ============================================================================

-- 4.a. Crée le Comité pour chaque église existante
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT id FROM public.churches LOOP
    PERFORM public.ensure_institutional_family(r.id);
  END LOOP;
END $$;

-- 4.b. Sync initiale pour tous les users existants
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT id FROM public.users LOOP
    PERFORM public.sync_user_committee_membership(r.id);
  END LOOP;
END $$;
