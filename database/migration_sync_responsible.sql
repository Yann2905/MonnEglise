-- ============================================================================
-- MIGRATION : Trigger de sync families.responsible_id ⇄ users.church_role
-- ============================================================================
-- Quand l'admin change le responsable d'une famille :
--   • Le NOUVEAU responsable → church_role = 'responsable_famille' (donc
--     auto-ajouté au Comité par le trigger sync_church_role)
--   • L'ANCIEN responsable → si son rôle était 'responsable_famille' ET qu'il
--     n'est plus responsable d'aucune AUTRE famille → church_role = 'fidele'
--     (donc auto-retiré du Comité)
--
-- ⚠️ Ne touche PAS aux familles institutionnelles (Comité).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.trg_sync_responsible_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- On ignore le Comité institutionnel
  IF NEW.is_institutional = TRUE THEN
    RETURN NEW;
  END IF;

  -- Cas INSERT ou UPDATE avec changement de responsible_id
  IF TG_OP = 'INSERT' OR NEW.responsible_id IS DISTINCT FROM OLD.responsible_id THEN

    -- 1. ANCIEN responsable (UPDATE seulement) — démotion si plus aucune autre famille
    IF TG_OP = 'UPDATE' AND OLD.responsible_id IS NOT NULL THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.families
        WHERE responsible_id = OLD.responsible_id
          AND id != NEW.id
          AND is_institutional = FALSE
      ) THEN
        -- Plus responsable d'aucune autre famille → fidèle
        -- (sauf s'il a un autre rôle élevé : pasteur, diacre, diaconesse, etc.
        --  Dans ce cas on garde son rôle actuel et on ne touche à rien.)
        UPDATE public.users
          SET church_role = 'fidele', updated_at = NOW()
          WHERE id = OLD.responsible_id
            AND church_role = 'responsable_famille';
      END IF;
    END IF;

    -- 2. NOUVEAU responsable → role = responsable_famille (sauf déjà supérieur)
    IF NEW.responsible_id IS NOT NULL THEN
      UPDATE public.users
        SET church_role = 'responsable_famille', updated_at = NOW()
        WHERE id = NEW.responsible_id
          AND church_role = 'fidele';
      -- Si l'user a déjà un rôle hiérarchiquement supérieur (pasteur_secondaire,
      -- diacre, diaconesse), on ne le rétrograde pas. Il peut être responsable
      -- d'une famille tout en gardant son rôle.
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_responsible_change ON public.families;
CREATE TRIGGER sync_responsible_change
  AFTER INSERT OR UPDATE OF responsible_id ON public.families
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_sync_responsible_change();

-- ============================================================================
-- ✅ FIN
-- ============================================================================
