-- ============================================================================
-- MIGRATION : Nettoyage des données démo (bypass DEV)
-- ============================================================================
-- Supprime le faux admin, le faux membre et la fausse église insérés par le
-- bypass `loadDemoAdmin / loadDemoMember` (qui n'existe plus dans le code).
--
-- ⚠️ NE PAS exécuter si tu as encore besoin de ces données pour tester.
-- ============================================================================

-- IDs hardcoded utilisés par l'ancien bypass
-- Demo admin   : 00000000-0000-0000-0000-000000000001
-- Demo membre  : 00000000-0000-0000-0000-000000000002
-- Demo église  : 00000000-0000-0000-0000-0000000000aa

-- Supprime d'abord les rows dépendantes (CASCADE prendra le reste)
DELETE FROM public.family_members
  WHERE user_id IN (
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000002'
  );

DELETE FROM public.notifications
  WHERE sender_id IN (
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000002'
  )
  OR receiver_id IN (
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000002'
  );

DELETE FROM public.device_tokens
  WHERE user_id IN (
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000002'
  );

-- L'église (CASCADE supprime les familles/sermons/services associés)
DELETE FROM public.churches
  WHERE id = '00000000-0000-0000-0000-0000000000aa';

-- Les faux users (au cas où le CASCADE n'a pas tout pris)
DELETE FROM public.users
  WHERE id IN (
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000002'
  );

-- ============================================================================
-- ✅ FIN
-- ============================================================================
