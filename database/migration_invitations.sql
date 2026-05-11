-- ============================================================================
-- MIGRATION : Système d'invitation par code d'église + QR + WhatsApp
-- ============================================================================
-- Ajoute un code court par église (ex: 'EBAC25') pour faciliter l'inscription
-- des membres : ils tapent ce code → liste des familles → ils s'inscrivent.
-- Le member_code (par admin) reste actif pour la rétrocompatibilité.
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Ajout colonne invite_code à churches
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.churches
  ADD COLUMN IF NOT EXISTS invite_code TEXT UNIQUE;

CREATE INDEX IF NOT EXISTS idx_churches_invite_code
  ON public.churches(invite_code);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Fonction de génération de code court (6 caractères alphanumériques)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.generate_church_invite_code()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  chars CONSTANT TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- Sans 0/O/1/I (confusions)
  code  TEXT := '';
  i     INTEGER;
  exists_already BOOLEAN;
BEGIN
  LOOP
    code := '';
    FOR i IN 1..6 LOOP
      code := code || substr(chars, 1 + floor(random() * length(chars))::int, 1);
    END LOOP;

    SELECT EXISTS(SELECT 1 FROM public.churches WHERE invite_code = code)
      INTO exists_already;

    EXIT WHEN NOT exists_already;
  END LOOP;

  RETURN code;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Backfill : générer un code pour les églises existantes qui n'en ont pas
-- ─────────────────────────────────────────────────────────────────────────────
UPDATE public.churches
SET invite_code = public.generate_church_invite_code()
WHERE invite_code IS NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Trigger : auto-générer un code à la création d'une église
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_church_invite_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.invite_code IS NULL THEN
    NEW.invite_code := public.generate_church_invite_code();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_churches_invite_code ON public.churches;
CREATE TRIGGER trg_churches_invite_code
  BEFORE INSERT ON public.churches
  FOR EACH ROW
  EXECUTE FUNCTION public.set_church_invite_code();

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. RPC pour vérifier un invite_code et récupérer l'église + admin
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.lookup_church_by_invite_code(code TEXT)
RETURNS TABLE (
  church_id   UUID,
  church_name TEXT,
  admin_id    UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id,
    c.name,
    c.admin_id
  FROM public.churches c
  WHERE c.invite_code = UPPER(code)
  LIMIT 1;
END;
$$;

GRANT EXECUTE ON FUNCTION public.lookup_church_by_invite_code(TEXT)
  TO anon, authenticated;

-- ============================================================================
-- ✅ FIN
-- ============================================================================
