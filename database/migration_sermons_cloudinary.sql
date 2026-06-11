-- ============================================================================
-- MIGRATION : Champ Cloudinary sur les sermons
-- ============================================================================
-- Stocke le public_id Cloudinary pour permettre la suppression du fichier
-- audio quand le sermon est supprimé (via Edge Function plus tard).
-- ============================================================================

ALTER TABLE public.sermons
  ADD COLUMN IF NOT EXISTS audio_public_id TEXT;

-- ============================================================================
-- ✅ FIN
-- ============================================================================
