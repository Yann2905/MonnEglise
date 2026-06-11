-- ============================================================================
-- BACKFILL : Restaurer family_members depuis l'ancien array member_ids
-- ============================================================================
-- Si tu as créé des familles AVANT que le code écrive dans family_members,
-- les liens étaient stockés dans families.member_ids[]. Ce script les copie
-- dans la table de jointure.
--
-- À exécuter UNE SEULE FOIS si tu as des familles avec des membres "perdus".
-- ============================================================================

-- Si la colonne member_ids existe encore (legacy), on backfille
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'families'
      AND column_name = 'member_ids'
  ) THEN
    INSERT INTO public.family_members (family_id, user_id)
    SELECT f.id, member_id::UUID
    FROM public.families f, UNNEST(f.member_ids) AS member_id
    WHERE member_id IS NOT NULL
      AND member_id != ''
      AND member_id ~ '^[0-9a-f-]{36}$'  -- on n'insère que des UUIDs valides
    ON CONFLICT (family_id, user_id) DO NOTHING;
    RAISE NOTICE 'Backfill terminé.';
  ELSE
    RAISE NOTICE 'Colonne member_ids déjà supprimée — pas de backfill nécessaire.';
  END IF;
END $$;

-- Pareil depuis users.family_ids si la colonne existe
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'users'
      AND column_name = 'family_ids'
  ) THEN
    INSERT INTO public.family_members (family_id, user_id)
    SELECT family_id::UUID, u.id
    FROM public.users u, UNNEST(u.family_ids) AS family_id
    WHERE family_id IS NOT NULL
      AND family_id != ''
      AND family_id ~ '^[0-9a-f-]{36}$'
    ON CONFLICT (family_id, user_id) DO NOTHING;
    RAISE NOTICE 'Backfill family_ids terminé.';
  ELSE
    RAISE NOTICE 'Colonne family_ids déjà supprimée — pas de backfill nécessaire.';
  END IF;
END $$;

-- Vérification après backfill
SELECT f.name,
       (SELECT COUNT(*) FROM family_members fm WHERE fm.family_id = f.id) AS nb_membres
FROM families f
WHERE f.is_institutional = false
ORDER BY f.created_at DESC;
