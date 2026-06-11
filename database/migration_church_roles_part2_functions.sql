-- ============================================================================
-- PART 2/4 — Fonctions PL/pgSQL (créées sans rien exécuter)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.ensure_institutional_family(p_church_id UUID)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
  v_family_id UUID;
  v_admin_id  UUID;
BEGIN
  SELECT id INTO v_family_id
  FROM public.families
  WHERE church_id = p_church_id AND is_institutional = TRUE
  LIMIT 1;

  IF v_family_id IS NOT NULL THEN
    RETURN v_family_id;
  END IF;

  SELECT admin_id INTO v_admin_id
  FROM public.churches
  WHERE id = p_church_id;

  INSERT INTO public.families (church_id, name, responsible_id, is_institutional)
  VALUES (p_church_id, 'Comité des responsables', v_admin_id, TRUE)
  RETURNING id INTO v_family_id;

  IF v_admin_id IS NOT NULL THEN
    INSERT INTO public.family_members (family_id, user_id)
    VALUES (v_family_id, v_admin_id)
    ON CONFLICT (family_id, user_id) DO NOTHING;
  END IF;

  RETURN v_family_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_user_committee_membership(p_user_id UUID)
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
    DELETE FROM public.family_members
      WHERE family_id = v_committee_id AND user_id = p_user_id;
    UPDATE public.families
      SET responsible_id = NULL, updated_at = NOW()
      WHERE responsible_id = p_user_id
        AND church_id = v_church_id
        AND is_institutional = FALSE;
  ELSE
    INSERT INTO public.family_members (family_id, user_id)
    VALUES (v_committee_id, p_user_id)
    ON CONFLICT (family_id, user_id) DO NOTHING;
  END IF;
END;
$$;
