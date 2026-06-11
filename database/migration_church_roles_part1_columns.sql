-- ============================================================================
-- PART 1/4 — Nouvelles colonnes + migration des données
-- ============================================================================

-- 1.a. Gender
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS gender TEXT
    CHECK (gender IN ('homme', 'femme'));

-- 1.b. Church role
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

-- 1.c. Famille institutionnelle
ALTER TABLE public.families
  ADD COLUMN IF NOT EXISTS is_institutional BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_families_institutional
  ON public.families(church_id, is_institutional);

-- 1.d. responsible_id nullable
ALTER TABLE public.families
  ALTER COLUMN responsible_id DROP NOT NULL;

-- 2. Migration : admins → pasteur_principal
UPDATE public.users
  SET church_role = 'pasteur_principal'
  WHERE role_global = 'admin' AND church_role = 'fidele';
