-- ============================================================================
-- ⚠️  MIGRATION DEV — Policies ouvertes (anon + authenticated)
-- ============================================================================
-- À exécuter UNIQUEMENT en développement, pour que le bypass DEV de l'app
-- (qui crée un currentUser local sans session Supabase Auth) puisse quand
-- même lire/écrire dans la base.
--
-- ⛔ NE PAS appliquer en production — sécurité TRÈS permissive.
-- Pour repasser en mode strict, ré-exécute schema.sql.
-- ============================================================================

-- ── churches ──
DROP POLICY IF EXISTS "churches_read"  ON public.churches;
DROP POLICY IF EXISTS "churches_write" ON public.churches;
CREATE POLICY "churches_read"  ON public.churches FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "churches_write" ON public.churches FOR ALL    TO anon, authenticated USING (true) WITH CHECK (true);

-- ── users ──
DROP POLICY IF EXISTS "users_read"       ON public.users;
DROP POLICY IF EXISTS "users_insert"     ON public.users;
DROP POLICY IF EXISTS "users_update_own" ON public.users;
DROP POLICY IF EXISTS "users_delete_own" ON public.users;
CREATE POLICY "users_read"   ON public.users FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "users_insert" ON public.users FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "users_update" ON public.users FOR UPDATE TO anon, authenticated USING (true);
CREATE POLICY "users_delete" ON public.users FOR DELETE TO anon, authenticated USING (true);

-- ── families ──
DROP POLICY IF EXISTS "families_read"  ON public.families;
DROP POLICY IF EXISTS "families_write" ON public.families;
CREATE POLICY "families_read"  ON public.families FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "families_write" ON public.families FOR ALL    TO anon, authenticated USING (true) WITH CHECK (true);

-- ── family_members ──
DROP POLICY IF EXISTS "family_members_read"  ON public.family_members;
DROP POLICY IF EXISTS "family_members_write" ON public.family_members;
CREATE POLICY "family_members_read"  ON public.family_members FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "family_members_write" ON public.family_members FOR ALL    TO anon, authenticated USING (true) WITH CHECK (true);

-- ── absences ──
DROP POLICY IF EXISTS "absences_read"  ON public.absences;
DROP POLICY IF EXISTS "absences_write" ON public.absences;
CREATE POLICY "absences_read"  ON public.absences FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "absences_write" ON public.absences FOR ALL    TO anon, authenticated USING (true) WITH CHECK (true);

-- ── notifications ──
DROP POLICY IF EXISTS "notifications_read"   ON public.notifications;
DROP POLICY IF EXISTS "notifications_insert" ON public.notifications;
DROP POLICY IF EXISTS "notifications_update" ON public.notifications;
DROP POLICY IF EXISTS "notifications_delete" ON public.notifications;
CREATE POLICY "notifications_read"   ON public.notifications FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "notifications_insert" ON public.notifications FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "notifications_update" ON public.notifications FOR UPDATE TO anon, authenticated USING (true);
CREATE POLICY "notifications_delete" ON public.notifications FOR DELETE TO anon, authenticated USING (true);

-- ── services ──
DROP POLICY IF EXISTS "services_read"  ON public.services;
DROP POLICY IF EXISTS "services_write" ON public.services;
CREATE POLICY "services_read"  ON public.services FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "services_write" ON public.services FOR ALL    TO anon, authenticated USING (true) WITH CHECK (true);

-- ── sermons ──
DROP POLICY IF EXISTS "sermons_read"  ON public.sermons;
DROP POLICY IF EXISTS "sermons_write" ON public.sermons;
CREATE POLICY "sermons_read"  ON public.sermons FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "sermons_write" ON public.sermons FOR ALL    TO anon, authenticated USING (true) WITH CHECK (true);

-- ── storage ──
DROP POLICY IF EXISTS "storage_read_public"          ON storage.objects;
DROP POLICY IF EXISTS "storage_write_authenticated"  ON storage.objects;
DROP POLICY IF EXISTS "storage_update_authenticated" ON storage.objects;
DROP POLICY IF EXISTS "storage_delete_authenticated" ON storage.objects;
CREATE POLICY "storage_read"   ON storage.objects FOR SELECT TO anon, authenticated
  USING (bucket_id IN ('churches', 'users', 'avatars', 'sermons'));
CREATE POLICY "storage_insert" ON storage.objects FOR INSERT TO anon, authenticated
  WITH CHECK (bucket_id IN ('churches', 'users', 'avatars', 'sermons'));
CREATE POLICY "storage_update" ON storage.objects FOR UPDATE TO anon, authenticated
  USING (bucket_id IN ('churches', 'users', 'avatars', 'sermons'));
CREATE POLICY "storage_delete" ON storage.objects FOR DELETE TO anon, authenticated
  USING (bucket_id IN ('churches', 'users', 'avatars', 'sermons'));

-- ============================================================================
-- ✅ FIN
-- ============================================================================
-- Pour repasser en mode prod-strict : exécute à nouveau schema.sql qui
-- recrée les policies originales avec contrôles auth.uid().
-- ============================================================================
