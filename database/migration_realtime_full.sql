-- ============================================================================
-- MIGRATION : Activer Realtime sur TOUTES les tables nécessaires
-- ============================================================================
-- Sans ça, les `supabase.channel().onPostgresChanges()` côté Flutter
-- ne reçoivent JAMAIS d'événement. Realtime doit être activé table par
-- table dans Supabase.
--
-- Idempotent : on saute les tables déjà ajoutées à la publication.
-- ============================================================================

DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'notifications',
    'sermons',
    'services',
    'absences',
    'attendance',
    'users',
    'families',
    'family_members',
    'churches'
  ] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;

-- Vérification : doit lister 9 tables (au moins)
SELECT tablename FROM pg_publication_tables
WHERE pubname = 'supabase_realtime' AND schemaname = 'public'
ORDER BY tablename;

-- ============================================================================
-- ✅ FIN
-- ============================================================================
