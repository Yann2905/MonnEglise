-- ============================================================================
-- MIGRATION : Features — services, sermons, anniversaire, photo profil
-- ============================================================================
-- À exécuter APRÈS schema.sql et migration_family_members.sql
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Champ date de naissance + suppression délégation
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS birth_date DATE;

-- Si tu avais ajouté delegated_to / delegation_date sur families, on les retire
ALTER TABLE public.families DROP COLUMN IF EXISTS delegated_to;
ALTER TABLE public.families DROP COLUMN IF EXISTS delegation_date;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Table services (cultes & événements)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.services (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  church_id   UUID         NOT NULL REFERENCES public.churches(id) ON DELETE CASCADE,
  type        TEXT         NOT NULL DEFAULT 'dimanche'
              CHECK (type IN ('dimanche', 'midweek', 'special')),
  title       TEXT,
  date        TIMESTAMPTZ  NOT NULL,
  created_by  UUID         REFERENCES public.users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_services_church_id ON public.services(church_id);
CREATE INDEX IF NOT EXISTS idx_services_date      ON public.services(date DESC);

ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "services_read"  ON public.services;
DROP POLICY IF EXISTS "services_write" ON public.services;
CREATE POLICY "services_read"  ON public.services FOR SELECT TO authenticated USING (true);
CREATE POLICY "services_write" ON public.services FOR ALL    TO authenticated USING (true) WITH CHECK (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Lier les absences à un service + tracker l'auteur de l'appel
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.absences
  ADD COLUMN IF NOT EXISTS service_id UUID REFERENCES public.services(id) ON DELETE SET NULL;

ALTER TABLE public.absences
  ADD COLUMN IF NOT EXISTS actor_name TEXT;  -- nom du user qui a fait l'appel

CREATE INDEX IF NOT EXISTS idx_absences_service_id ON public.absences(service_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Notifications : préciser qui a fait l'action
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS actor_name TEXT;  -- ex: "Jean Kouassi" (auteur de l'appel)

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Table sermons (prédications)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.sermons (
  id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  church_id     UUID         NOT NULL REFERENCES public.churches(id) ON DELETE CASCADE,
  theme         TEXT         NOT NULL,
  verses        TEXT,
  audio_url     TEXT,
  duration_sec  INTEGER,
  sermon_date   TIMESTAMPTZ  NOT NULL,
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sermons_church_id   ON public.sermons(church_id);
CREATE INDEX IF NOT EXISTS idx_sermons_sermon_date ON public.sermons(sermon_date DESC);

ALTER TABLE public.sermons ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "sermons_read"  ON public.sermons;
DROP POLICY IF EXISTS "sermons_write" ON public.sermons;
CREATE POLICY "sermons_read"  ON public.sermons FOR SELECT TO authenticated USING (true);
CREATE POLICY "sermons_write" ON public.sermons FOR ALL    TO authenticated USING (true) WITH CHECK (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Storage buckets
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('sermons', 'sermons', true),
  ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- ✅ FIN
-- ============================================================================
