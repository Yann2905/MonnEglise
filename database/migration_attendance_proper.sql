-- ============================================================================
-- MIGRATION : Vraie table `attendance` (présence par membre par service)
--             + suppression dénormalisations sur families
-- ============================================================================
--
-- AVANT : on enregistrait UNIQUEMENT les absences dans `absences.absent_members`
--         (JSONB), impossible de répondre "qui est présent dimanche ?" ou
--         "combien d'absences pour Madame X ce trimestre ?".
--
-- APRÈS : une row par (user, service) avec un status explicite. Stats simples
--         via COUNT/GROUP BY. La table `absences` reste pour compatibilité
--         legacy mais le NOUVEAU code écrit dans `attendance`.
--
-- À exécuter dans le SQL Editor de Supabase.
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Table attendance — 1 row par (user, service)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.attendance (
  id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id   UUID         NOT NULL REFERENCES public.services(id) ON DELETE CASCADE,
  user_id      UUID         NOT NULL REFERENCES public.users(id)    ON DELETE CASCADE,
  family_id    UUID         REFERENCES public.families(id) ON DELETE SET NULL,
  status       TEXT         NOT NULL
                            CHECK (status IN ('present', 'absent', 'excuse')),
  note         TEXT,
  recorded_by  UUID         NOT NULL REFERENCES public.users(id) ON DELETE SET NULL,
  recorded_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  UNIQUE (service_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_attendance_service_id ON public.attendance(service_id);
CREATE INDEX IF NOT EXISTS idx_attendance_user_id    ON public.attendance(user_id);
CREATE INDEX IF NOT EXISTS idx_attendance_status     ON public.attendance(status);
CREATE INDEX IF NOT EXISTS idx_attendance_family_id  ON public.attendance(family_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. RLS — DEV permissif
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "attendance_select" ON public.attendance;
DROP POLICY IF EXISTS "attendance_insert" ON public.attendance;
DROP POLICY IF EXISTS "attendance_update" ON public.attendance;
DROP POLICY IF EXISTS "attendance_delete" ON public.attendance;
CREATE POLICY "attendance_select" ON public.attendance
  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "attendance_insert" ON public.attendance
  FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "attendance_update" ON public.attendance
  FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "attendance_delete" ON public.attendance
  FOR DELETE TO anon, authenticated USING (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Realtime sur attendance
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'attendance'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.attendance';
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Vue pour exposer le member_count CALCULÉ (plus de dénormalisation foireuse)
--    Le code Dart lira cette vue au lieu de `families` directement
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.v_families_enriched AS
SELECT
  f.id,
  f.church_id,
  f.name,
  f.responsible_id,
  f.created_at,
  f.updated_at,
  COALESCE(
    (SELECT COUNT(*)::INT FROM public.family_members fm WHERE fm.family_id = f.id),
    0
  ) AS member_count
FROM public.families f;

-- RLS hérite de la table sous-jacente — pas besoin de policy sur la vue

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Quelques requêtes utiles pour les stats (à utiliser plus tard)
-- ─────────────────────────────────────────────────────────────────────────────
--
-- Taux de présence par membre sur les 3 derniers mois :
--   SELECT user_id, COUNT(*) FILTER (WHERE status = 'present') AS presences,
--          COUNT(*) FILTER (WHERE status = 'absent')  AS absences
--   FROM public.attendance
--   WHERE recorded_at >= NOW() - INTERVAL '3 months'
--   GROUP BY user_id;
--
-- Liste des absents pour un service :
--   SELECT u.first_name, u.last_name
--   FROM public.attendance a
--   JOIN public.users u ON u.id = a.user_id
--   WHERE a.service_id = '<id>' AND a.status = 'absent';

-- ============================================================================
-- ✅ FIN
-- ============================================================================
