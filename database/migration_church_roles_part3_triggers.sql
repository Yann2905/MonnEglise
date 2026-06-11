-- ============================================================================
-- PART 3/4 — Triggers + vue
-- ============================================================================

-- Trigger : nouvelle église → crée le Comité
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

-- Trigger : changement de church_role → sync Comité
CREATE OR REPLACE FUNCTION public.trg_sync_church_role()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM public.sync_user_committee_membership(NEW.id);
    RETURN NEW;
  END IF;

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

-- Trigger : retiré du Comité → redevient fidèle
CREATE OR REPLACE FUNCTION public.trg_removed_from_committee()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE v_is_committee BOOLEAN;
BEGIN
  SELECT is_institutional INTO v_is_committee
  FROM public.families
  WHERE id = OLD.family_id;

  IF v_is_committee = TRUE THEN
    UPDATE public.users
      SET church_role = 'fidele', updated_at = NOW()
      WHERE id = OLD.user_id;
  END IF;

  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS removed_from_committee ON public.family_members;
CREATE TRIGGER removed_from_committee
  AFTER DELETE ON public.family_members
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_removed_from_committee();

-- Vue v_families_enriched (avec flag is_institutional)
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
