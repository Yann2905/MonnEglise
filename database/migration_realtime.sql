-- ============================================================================
-- MIGRATION : Activer Realtime sur les tables clés
-- ============================================================================
-- Sans ces lignes, les `supabase.channel().onPostgresChanges()` côté Flutter
-- ne reçoivent JAMAIS d'événement. Realtime doit être explicitement activé
-- table par table dans Supabase.
--
-- À exécuter dans le SQL Editor.
-- ============================================================================

-- Ajoute les tables à la publication Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.sermons;
ALTER PUBLICATION supabase_realtime ADD TABLE public.services;
ALTER PUBLICATION supabase_realtime ADD TABLE public.absences;

-- Vérification : lister les tables en Realtime
-- SELECT schemaname, tablename
-- FROM pg_publication_tables
-- WHERE pubname = 'supabase_realtime';

-- ============================================================================
-- ✅ FIN
-- ============================================================================
