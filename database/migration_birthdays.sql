-- ============================================================================
-- MIGRATION : Notifications d'anniversaire automatiques
-- ============================================================================
-- Phase 1 (actuelle) : seul l'anniversaire du PASTEUR (admin) est diffusé
-- à tous les membres de son église.
--
-- Mécanique : pg_cron déclenche notify_pastor_birthdays() chaque jour à 8h.
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Activer pg_cron si pas déjà fait
-- ─────────────────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Fonction principale — envoie les notifs d'anniversaire pasteur
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_pastor_birthdays()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  pastor       RECORD;
  inserted_cnt INTEGER := 0;
BEGIN
  -- Boucle sur tous les pasteurs (admins) qui ont un anniversaire aujourd'hui
  FOR pastor IN
    SELECT u.id, u.first_name, u.last_name, u.church_id
    FROM public.users u
    WHERE u.role_global = 'admin'
      AND u.birth_date IS NOT NULL
      AND u.church_id IS NOT NULL
      AND EXTRACT(MONTH FROM u.birth_date) = EXTRACT(MONTH FROM NOW())
      AND EXTRACT(DAY FROM u.birth_date)   = EXTRACT(DAY FROM NOW())
  LOOP
    -- Notifie tous les membres de l'église du pasteur (sauf le pasteur lui-même)
    INSERT INTO public.notifications (
      title, message, type, sender_id, receiver_id, actor_name, is_read
    )
    SELECT
      '🎉 Anniversaire du pasteur',
      'Aujourd''hui c''est l''anniversaire du Pasteur '
        || pastor.first_name || ' ' || pastor.last_name
        || '. Pensez à le saluer !',
      'system',
      'system',
      m.id,
      pastor.first_name || ' ' || pastor.last_name,
      false
    FROM public.users m
    WHERE m.church_id = pastor.church_id
      AND m.id != pastor.id
      -- Évite les doublons : pas de notif si déjà envoyée aujourd'hui à ce membre
      AND NOT EXISTS (
        SELECT 1 FROM public.notifications n
        WHERE n.receiver_id = m.id
          AND n.title = '🎉 Anniversaire du pasteur'
          AND DATE(n.created_at) = CURRENT_DATE
      );

    GET DIAGNOSTICS inserted_cnt = ROW_COUNT;
  END LOOP;

  RETURN inserted_cnt;
END;
$$;

GRANT EXECUTE ON FUNCTION public.notify_pastor_birthdays() TO postgres;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Schedule pg_cron — tous les jours à 08:00 UTC
-- ─────────────────────────────────────────────────────────────────────────────
-- Note : Supabase Cloud est en UTC. Adapte à ton fuseau horaire si besoin :
--   Côte d'Ivoire = UTC (pas de décalage), donc 08:00 UTC = 08:00 locale
--
-- Pour supprimer un job existant avant de le recréer :
SELECT cron.unschedule('notify-pastor-birthdays')
WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'notify-pastor-birthdays'
);

SELECT cron.schedule(
  'notify-pastor-birthdays',     -- nom du job
  '0 8 * * *',                   -- tous les jours à 8h00 UTC
  $$ SELECT public.notify_pastor_birthdays(); $$
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Vérifier que le job est bien programmé
-- ─────────────────────────────────────────────────────────────────────────────
-- SELECT * FROM cron.job WHERE jobname = 'notify-pastor-birthdays';

-- Pour tester manuellement la fonction sans attendre 8h du matin :
-- SELECT public.notify_pastor_birthdays();

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Phase 2 — Anniversaires des MEMBRES (notif aux membres de leur famille)
-- ─────────────────────────────────────────────────────────────────────────────
-- Le membre dont c'est l'anniversaire NE reçoit PAS de notif.
-- Les autres membres de chacune de ses familles reçoivent une notif "type=system"
-- avec son prénom, son nom et SANS afficher l'âge.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_member_birthdays()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  birthday_user RECORD;
  total_inserted INTEGER := 0;
  inserted_cnt INTEGER;
BEGIN
  -- Pour chaque user (non-admin) qui a son anniversaire aujourd'hui
  FOR birthday_user IN
    SELECT u.id, u.first_name, u.last_name
    FROM public.users u
    WHERE u.role_global != 'admin'
      AND u.birth_date IS NOT NULL
      AND EXTRACT(MONTH FROM u.birth_date) = EXTRACT(MONTH FROM NOW())
      AND EXTRACT(DAY FROM u.birth_date)   = EXTRACT(DAY FROM NOW())
  LOOP
    -- Notifie tous les autres membres des familles auxquelles il appartient
    -- (via la table de jointure family_members)
    INSERT INTO public.notifications (
      title, message, type, sender_id, receiver_id, actor_name, is_read
    )
    SELECT DISTINCT
      '🎂 Anniversaire',
      'Aujourd''hui c''est l''anniversaire de '
        || birthday_user.first_name || ' ' || birthday_user.last_name
        || ' ! Pensez à le souhaiter.',
      'system',
      'system',
      other.user_id,
      birthday_user.first_name || ' ' || birthday_user.last_name,
      false
    FROM public.family_members mine
    JOIN public.family_members other ON other.family_id = mine.family_id
    WHERE mine.user_id = birthday_user.id
      AND other.user_id != birthday_user.id
      -- Anti-doublon : pas plusieurs notifs au même membre le même jour
      AND NOT EXISTS (
        SELECT 1 FROM public.notifications n
        WHERE n.receiver_id = other.user_id
          AND n.title = '🎂 Anniversaire'
          AND n.actor_name =
              birthday_user.first_name || ' ' || birthday_user.last_name
          AND DATE(n.created_at) = CURRENT_DATE
      );

    GET DIAGNOSTICS inserted_cnt = ROW_COUNT;
    total_inserted := total_inserted + inserted_cnt;
  END LOOP;

  RETURN total_inserted;
END;
$$;

GRANT EXECUTE ON FUNCTION public.notify_member_birthdays() TO postgres;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Schedule pg_cron pour les anniversaires des membres (8h05 UTC)
-- ─────────────────────────────────────────────────────────────────────────────
SELECT cron.unschedule('notify-member-birthdays')
WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'notify-member-birthdays'
);

SELECT cron.schedule(
  'notify-member-birthdays',
  '5 8 * * *',
  $$ SELECT public.notify_member_birthdays(); $$
);

-- ============================================================================
-- ✅ FIN
-- ============================================================================
-- Pour tester manuellement :
--   SELECT public.notify_pastor_birthdays();
--   SELECT public.notify_member_birthdays();
-- ============================================================================
