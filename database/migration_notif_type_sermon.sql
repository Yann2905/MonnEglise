-- ============================================================================
-- MIGRATION : Ajoute 'sermon' au CHECK de notifications.type
-- ============================================================================
-- Sans ça, les notifs auto envoyées quand l'admin ajoute une prédication
-- échouent avec "violates check constraint".
-- ============================================================================

ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check
  CHECK (type IN ('system', 'absence', 'reminder', 'alert', 'custom', 'sermon'));

-- ============================================================================
-- ✅ FIN
-- ============================================================================
