-- ============================================================================
-- MIGRATION : Système de rôles d'église + famille institutionnelle
-- ============================================================================
-- Ajoute :
--   • users.gender                 ('homme' | 'femme')
--   • users.church_role            (5 rôles internes à l'église)
--   • families.is_institutional    flag pour la famille "Comité des responsables"
--   • Famille "Comité des responsables" auto-créée par église (1 par église)
--   • Triggers de synchronisation :
--       - Auto-crée le comité quand une nouvelle église est créée
--       - Ajoute/retire un user du comité quand son church_role change
--       - Retire un responsable de sa famille quand son rôle redevient 'fidele'
--
-- À exécuter dans le SQL Editor de Supabase.
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. NOUVELLES COLONNES
-- ─────────────────────────────────────────────────────────────────────────────

-- 1.a. Gender
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS gender TEXT
    CHECK (gender IN ('homme', 'femme'));

-- 1.b. Church role (rôle interne à l'église)
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS church_role TEXT
    NOT NULL DEFAULT 'fidele'
    CHECK (church_role IN (
      'pasteur_principal',
      'pasteur_secondaire',
      'responsable_famille',
      'diacre',
      'diaconesse',
      'fidele'
    ));

-- 1.c. Famille institutionnelle (le Comité)
ALTER TABLE public.families
  ADD COLUMN IF NOT EXISTS is_institutional BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_families_institutional
  ON public.families(church_id, is_institutional);

-- 1.d. Permettre families.responsible_id = NULL (rétrogradation possible)
ALTER TABLE public.families
  ALTER COLUMN responsible_id DROP NOT NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. MIGRATION DES DONNÉES EXISTANTES
-- ─────────────────────────────────────────────────────────────────────────────

-- 2.a. Anciens admins → pasteur_principal ; reste → fidele (déjà default)
UPDATE public.users
  SET church_role = 'pasteur_principal'
  WHERE role_global = 'admin' AND church_role = 'fidele';

-- 2.b. Diacres/diaconesses déduits du genre si déjà saisi ailleurs → skip
--      (rien à faire — restent fidele par défaut)

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. FAMILLE INSTITUTIONNELLE "Comité des responsables"
-- ─────────────────────────────────────────────────────────────────────────────

-- 3.a. Fonction qui crée le comité pour UNE église donnée
CREATE OR REPLACE FUNCTION public.ensure_institutional_family(p_church_id UUID)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
  v_family_id UUID;
  v_admin_id  UUID;
BEGIN
  -- Existe déjà ?
  SELECT id INTO v_family_id
  FROM public.families
  WHERE church_id = p_church_id AND is_institutional = TRUE
  LIMIT 1;

  IF v_family_id IS NOT NULL THEN
    RETURN v_family_id;
  END IF;

  -- Trouve l'admin de l'église
  SELECT admin_id INTO v_admin_id
  FROM public.churches
  WHERE id = p_church_id;

  -- Crée la famille (responsible_id = pasteur principal)
  INSERT INTO public.families (church_id, name, responsible_id, is_institutional)
  VALUES (p_church_id, 'Comité des responsables', v_admin_id, TRUE)
  RETURNING id INTO v_family_id;

  -- Ajoute l'admin (pasteur principal) au comité
  IF v_admin_id IS NOT NULL THEN
    INSERT INTO public.family_members (family_id, user_id)
    VALUES (v_family_id, v_admin_id)
    ON CONFLICT (family_id, user_id) DO NOTHING;
  END IF;

  RETURN v_family_id;
END;
$$;

-- 3.b. Backfill : crée le comité pour chaque église existante
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT id FROM public.churches LOOP
    PERFORM public.ensure_institutional_family(r.id);
  END LOOP;
END $$;

-- 3.c. Trigger : auto-crée le comité quand une nouvelle église est insérée
CREATE OR REPLACE FUNCTION public.trg_new_church_creates_committee()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM public.ensure_institutional_family(NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS new_church_creates_committee ON public.churches;
CREATE TRIGGER new_church_creates_committee
  AFTER INSERT ON public.churches
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_new_church_creates_committee();

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. SYNCHRONISATION church_role ⇄ comité
-- ─────────────────────────────────────────────────────────────────────────────

-- 4.a. Fonction : ajoute/retire un user du comité selon son rôle
CREATE OR REPLACE FUNCTION public.sync_user_committee_membership(
  p_user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_church_id    UUID;
  v_church_role  TEXT;
  v_committee_id UUID;
BEGIN
  SELECT church_id, church_role
  INTO v_church_id, v_church_role
  FROM public.users
  WHERE id = p_user_id;

  IF v_church_id IS NULL THEN
    RETURN;
  END IF;

  v_committee_id := public.ensure_institutional_family(v_church_id);

  IF v_church_role = 'fidele' THEN
    -- Fidèle → hors comité, et plus responsable d'aucune famille
    DELETE FROM public.family_members
      WHERE family_id = v_committee_id AND user_id = p_user_id;
    UPDATE public.families
      SET responsible_id = NULL, updated_at = NOW()
      WHERE responsible_id = p_user_id
        AND church_id = v_church_id
        AND is_institutional = FALSE;
  ELSE
    -- Autre rôle (pasteur, resp famille, diacre, diaconesse) → dans le comité
    INSERT INTO public.family_members (family_id, user_id)
    VALUES (v_committee_id, p_user_id)
    ON CONFLICT (family_id, user_id) DO NOTHING;
  END IF;
END;
$$;

-- 4.b. Trigger : appelé quand church_role change
CREATE OR REPLACE FUNCTION public.trg_sync_church_role()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Cas INSERT : on synchronise toujours
  IF TG_OP = 'INSERT' THEN
    PERFORM public.sync_user_committee_membership(NEW.id);
    RETURN NEW;
  END IF;

  -- Cas UPDATE : on synchronise si church_role OU church_id change
  IF NEW.church_role IS DISTINCT FROM OLD.church_role
     OR NEW.church_id IS DISTINCT FROM OLD.church_id THEN
    PERFORM public.sync_user_committee_membership(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_church_role ON public.users;
CREATE TRIGGER sync_church_role
  AFTER INSERT OR UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_sync_church_role();

-- 4.c. Trigger inverse : si on RETIRE un user du comité manuellement
--     → il redevient 'fidele' (et perd ses responsabilités)
CREATE OR REPLACE FUNCTION public.trg_removed_from_committee()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_is_committee BOOLEAN;
BEGIN
  SELECT is_institutional INTO v_is_committee
  FROM public.families
  WHERE id = OLD.family_id;

  IF v_is_committee = TRUE THEN
    -- L'user a été retiré du comité → on le redescend en fidèle
    UPDATE public.users
      SET church_role = 'fidele', updated_at = NOW()
      WHERE id = OLD.user_id;
    -- (le trigger sync_church_role va alors aussi nettoyer responsible_id)
  END IF;

  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS removed_from_committee ON public.family_members;
CREATE TRIGGER removed_from_committee
  AFTER DELETE ON public.family_members
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_removed_from_committee();

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Sync initiale pour tous les users existants
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT id FROM public.users LOOP
    PERFORM public.sync_user_committee_membership(r.id);
  END LOOP;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Mettre à jour la vue v_families_enriched pour filtrer le comité
--    quand on veut juste les familles "normales"
--    → on garde la vue mais on lui ajoute le flag is_institutional
-- ─────────────────────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS public.v_families_enriched;
CREATE VIEW public.v_families_enriched AS
SELECT
  f.id,
  f.church_id,
  f.name,
  f.responsible_id,
  f.is_institutional,
  f.created_at,
  f.updated_at,
  COALESCE(
    (SELECT COUNT(*)::INT FROM public.family_members fm WHERE fm.family_id = f.id),
    0
  ) AS member_count
FROM public.families f;

-- ============================================================================
-- ✅ FIN — Phase 1 (DB)
--   Côté code Dart, il faut maintenant :
--     • Ajouter UserModel.gender + UserModel.churchRole
--     • Ajouter FamilyModel.isInstitutional
--     • Filtrer is_institutional=false dans les listes de familles normales
--     • Mettre à jour le formulaire d'inscription membre
-- ============================================================================
