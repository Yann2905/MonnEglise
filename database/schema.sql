-- ============================================================================
-- MonÉglise — Schéma complet de la base de données Supabase
-- ============================================================================
-- À coller en une fois dans le SQL Editor de Supabase (Dashboard → SQL Editor)
-- Reconstruit à partir des modèles Dart : user_model, family_model,
-- church_model, absence_model, notification_model + database_service +
-- auth_service + auth_provider.
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. EXTENSIONS
-- ─────────────────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. FONCTION UTILITAIRE — mise à jour automatique de updated_at
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. TABLE : churches
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.churches (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT         NOT NULL,
  logo_url    TEXT,
  admin_id    UUID         NOT NULL,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_churches_admin_id ON public.churches(admin_id);

DROP TRIGGER IF EXISTS trg_churches_updated_at ON public.churches;
CREATE TRIGGER trg_churches_updated_at
  BEFORE UPDATE ON public.churches
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. TABLE : users
-- ─────────────────────────────────────────────────────────────────────────────
-- Lien avec auth.users : un user de l'app correspond à un user Supabase Auth
-- via la colonne auth_id (référence vers auth.users.id).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.users (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_id         UUID         NOT NULL UNIQUE
                  REFERENCES auth.users(id) ON DELETE CASCADE,
  church_id       UUID         REFERENCES public.churches(id) ON DELETE SET NULL,
  role_global     TEXT         NOT NULL DEFAULT 'membre'
                  CHECK (role_global IN ('admin', 'membre')),
  phone           TEXT         NOT NULL UNIQUE,
  first_name      TEXT         NOT NULL,
  last_name       TEXT         NOT NULL,
  quartier        TEXT         NOT NULL DEFAULT '',
  avatar_url      TEXT,
  is_responsible  BOOLEAN      NOT NULL DEFAULT FALSE,
  member_code     TEXT         UNIQUE,
  admin_code      TEXT,
  role            TEXT,
  family_ids      TEXT[]       NOT NULL DEFAULT '{}',
  last_login      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_auth_id     ON public.users(auth_id);
CREATE INDEX IF NOT EXISTS idx_users_church_id   ON public.users(church_id);
CREATE INDEX IF NOT EXISTS idx_users_phone       ON public.users(phone);
CREATE INDEX IF NOT EXISTS idx_users_member_code ON public.users(member_code);
CREATE INDEX IF NOT EXISTS idx_users_admin_code  ON public.users(admin_code);
CREATE INDEX IF NOT EXISTS idx_users_role_global ON public.users(role_global);

DROP TRIGGER IF EXISTS trg_users_updated_at ON public.users;
CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- FK différée pour churches.admin_id → users.id
-- (faite après la création de users car circularité possible)
ALTER TABLE public.churches
  DROP CONSTRAINT IF EXISTS fk_churches_admin_id;
ALTER TABLE public.churches
  ADD CONSTRAINT fk_churches_admin_id
  FOREIGN KEY (admin_id) REFERENCES public.users(id) ON DELETE CASCADE
  DEFERRABLE INITIALLY DEFERRED;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. TABLE : families
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.families (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  church_id       UUID         NOT NULL
                  REFERENCES public.churches(id) ON DELETE CASCADE,
  name            TEXT         NOT NULL,
  responsible_id  UUID         NOT NULL
                  REFERENCES public.users(id) ON DELETE CASCADE,
  member_count    INTEGER      NOT NULL DEFAULT 0,
  member_ids      TEXT[]       NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_families_church_id      ON public.families(church_id);
CREATE INDEX IF NOT EXISTS idx_families_responsible_id ON public.families(responsible_id);

DROP TRIGGER IF EXISTS trg_families_updated_at ON public.families;
CREATE TRIGGER trg_families_updated_at
  BEFORE UPDATE ON public.families
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. TABLE : absences
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.absences (
  id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id        UUID         NOT NULL
                   REFERENCES public.families(id) ON DELETE CASCADE,
  family_name      TEXT         NOT NULL,
  date             TIMESTAMPTZ  NOT NULL,
  created_by       UUID         NOT NULL
                   REFERENCES public.users(id) ON DELETE CASCADE,
  absent_count     INTEGER      NOT NULL DEFAULT 0,
  absent_members   JSONB        NOT NULL DEFAULT '[]'::jsonb,
  created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_absences_family_id  ON public.absences(family_id);
CREATE INDEX IF NOT EXISTS idx_absences_created_by ON public.absences(created_by);
CREATE INDEX IF NOT EXISTS idx_absences_date       ON public.absences(date);

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. TABLE : notifications
-- ─────────────────────────────────────────────────────────────────────────────
-- sender_id est TEXT pour permettre la valeur 'system' (utilisée par
-- AuthService.sendSystemNotification) en plus des UUID utilisateurs.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notifications (
  id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  title        TEXT         NOT NULL,
  message      TEXT         NOT NULL,
  type         TEXT         NOT NULL DEFAULT 'system'
               CHECK (type IN ('system', 'absence', 'reminder', 'alert', 'custom')),
  sender_id    TEXT         NOT NULL,
  receiver_id  UUID         REFERENCES public.users(id) ON DELETE CASCADE,
  is_read      BOOLEAN      NOT NULL DEFAULT FALSE,
  metadata     JSONB,
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_receiver_id ON public.notifications(receiver_id);
CREATE INDEX IF NOT EXISTS idx_notifications_sender_id   ON public.notifications(sender_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read     ON public.notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at  ON public.notifications(created_at DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. RPC FUNCTIONS — appelées par auth_provider.dart
-- ─────────────────────────────────────────────────────────────────────────────

-- check_phone_exists : utilisé pour vérifier qu'un numéro n'est pas déjà pris
CREATE OR REPLACE FUNCTION public.check_phone_exists(phone_number TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users WHERE phone = phone_number
  );
END;
$$;

-- check_member_code_exists : utilisé pour valider le code admin saisi par un membre
CREATE OR REPLACE FUNCTION public.check_member_code_exists(code TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users
    WHERE member_code = UPPER(code) AND role_global = 'admin'
  );
END;
$$;

-- Permissions d'exécution pour les RPC (anon = inscription, authenticated = app)
GRANT EXECUTE ON FUNCTION public.check_phone_exists(TEXT)        TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_member_code_exists(TEXT)  TO anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. ROW LEVEL SECURITY
-- ─────────────────────────────────────────────────────────────────────────────
-- Politiques DEV (permissives) — tous les utilisateurs authentifiés peuvent
-- lire et écrire. Tu pourras les durcir plus tard pour la prod.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.churches      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.families      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.absences      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- ── churches ──
DROP POLICY IF EXISTS "churches_read"   ON public.churches;
DROP POLICY IF EXISTS "churches_write"  ON public.churches;
CREATE POLICY "churches_read"  ON public.churches FOR SELECT TO authenticated USING (true);
CREATE POLICY "churches_write" ON public.churches FOR ALL    TO authenticated USING (true) WITH CHECK (true);

-- ── users ──
DROP POLICY IF EXISTS "users_read"       ON public.users;
DROP POLICY IF EXISTS "users_insert"     ON public.users;
DROP POLICY IF EXISTS "users_update_own" ON public.users;
DROP POLICY IF EXISTS "users_delete_own" ON public.users;

-- Lecture : autorisée à tout authentifié (nécessaire pour login : on cherche
-- le profil par phone avant d'envoyer l'OTP) + à anon pour la même raison.
CREATE POLICY "users_read"       ON public.users FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "users_insert"     ON public.users FOR INSERT TO authenticated WITH CHECK (auth.uid() = auth_id);
CREATE POLICY "users_update_own" ON public.users FOR UPDATE TO authenticated USING (auth.uid() = auth_id);
CREATE POLICY "users_delete_own" ON public.users FOR DELETE TO authenticated USING (auth.uid() = auth_id);

-- ── families ──
DROP POLICY IF EXISTS "families_read"  ON public.families;
DROP POLICY IF EXISTS "families_write" ON public.families;
CREATE POLICY "families_read"  ON public.families FOR SELECT TO authenticated USING (true);
CREATE POLICY "families_write" ON public.families FOR ALL    TO authenticated USING (true) WITH CHECK (true);

-- ── absences ──
DROP POLICY IF EXISTS "absences_read"  ON public.absences;
DROP POLICY IF EXISTS "absences_write" ON public.absences;
CREATE POLICY "absences_read"  ON public.absences FOR SELECT TO authenticated USING (true);
CREATE POLICY "absences_write" ON public.absences FOR ALL    TO authenticated USING (true) WITH CHECK (true);

-- ── notifications ──
DROP POLICY IF EXISTS "notifications_read"   ON public.notifications;
DROP POLICY IF EXISTS "notifications_insert" ON public.notifications;
DROP POLICY IF EXISTS "notifications_update" ON public.notifications;
DROP POLICY IF EXISTS "notifications_delete" ON public.notifications;
CREATE POLICY "notifications_read"
  ON public.notifications FOR SELECT TO authenticated
  USING (
    receiver_id IS NULL                                              -- broadcast
    OR receiver_id IN (SELECT id FROM public.users WHERE auth_id = auth.uid())
  );
CREATE POLICY "notifications_insert" ON public.notifications FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "notifications_update"
  ON public.notifications FOR UPDATE TO authenticated
  USING (
    receiver_id IN (SELECT id FROM public.users WHERE auth_id = auth.uid())
  );
CREATE POLICY "notifications_delete"
  ON public.notifications FOR DELETE TO authenticated
  USING (
    receiver_id IN (SELECT id FROM public.users WHERE auth_id = auth.uid())
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- 10. STORAGE BUCKETS — logos d'églises + photos de profil
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('churches', 'churches', true),
  ('users',    'users',    true)
ON CONFLICT (id) DO NOTHING;

-- Policies storage permissives (lecture publique, écriture authentifiée)
DROP POLICY IF EXISTS "storage_read_public"        ON storage.objects;
DROP POLICY IF EXISTS "storage_write_authenticated" ON storage.objects;
DROP POLICY IF EXISTS "storage_update_authenticated" ON storage.objects;
DROP POLICY IF EXISTS "storage_delete_authenticated" ON storage.objects;

CREATE POLICY "storage_read_public"
  ON storage.objects FOR SELECT TO anon, authenticated
  USING (bucket_id IN ('churches', 'users'));

CREATE POLICY "storage_write_authenticated"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id IN ('churches', 'users'));

CREATE POLICY "storage_update_authenticated"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id IN ('churches', 'users'));

CREATE POLICY "storage_delete_authenticated"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id IN ('churches', 'users'));

-- ============================================================================
-- ✅ FIN DU SCHÉMA
-- ============================================================================
-- Après exécution :
-- 1. Va dans Authentication → Providers → active "Phone" et configure ton
--    provider SMS (Twilio, MessageBird, Vonage, ou Test mode).
-- 2. Récupère ton URL et ta clé anon dans Project Settings → API,
--    et mets-les dans lib/supabase_config.dart.
-- 3. Lance l'app : flutter run -d chrome
-- ============================================================================
