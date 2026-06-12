-- ============================================================================
-- MIGRATION : Bucket Storage privé pour les backups quotidiens
-- ============================================================================
-- À exécuter dans le SQL Editor de Supabase une seule fois.
-- Le bucket "backups" est PRIVÉ : seul le service role peut y lire/écrire.
-- ============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'backups',
  'backups',
  FALSE,
  524288000, -- 500 MB max par fichier
  ARRAY['application/json']
)
ON CONFLICT (id) DO NOTHING;

-- Pas de RLS sur ce bucket : tout est géré par le service role
-- (les Edge Functions utilisent le service_role_key).
