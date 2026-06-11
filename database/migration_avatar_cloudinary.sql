-- ============================================================================
-- MIGRATION : Champ Cloudinary pour les avatars utilisateurs
-- ============================================================================
-- Stocke le public_id Cloudinary pour permettre la suppression du fichier
-- avatar quand l'utilisateur change ou supprime sa photo.
-- ============================================================================

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS avatar_public_id TEXT;

-- Pareil pour les logos d'église
ALTER TABLE public.churches
  ADD COLUMN IF NOT EXISTS logo_public_id TEXT;

-- ============================================================================
-- ✅ FIN
-- ============================================================================
