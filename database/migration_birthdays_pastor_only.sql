-- ============================================================================
-- MIGRATION : Anniversaires — pasteur uniquement
-- ============================================================================
-- Garde le cron qui notifie l'église de l'anniversaire du pasteur.
-- DÉSACTIVE les autres crons d'anniversaire éventuellement créés
-- (membres standards, ancienne version "all members").
--
-- À exécuter dans le SQL Editor de Supabase.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ─── 1. S'assurer que la fonction pasteur existe et est à jour ───
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
  FOR pastor IN
    SELECT u.id, u.first_name, u.last_name, u.church_id
    FROM public.users u
    WHERE u.role_global = 'admin'
      AND u.birth_date IS NOT NULL
      AND u.church_id IS NOT NULL
      AND EXTRACT(MONTH FROM u.birth_date) = EXTRACT(MONTH FROM NOW())
      AND EXTRACT(DAY FROM u.birth_date)   = EXTRACT(DAY FROM NOW())
  LOOP
    INSERT INTO public.notifications (
      title, message, type, sender_id, receiver_id, actor_name, is_read
    )
    SELECT
      '🎉 Anniversaire du pasteur',
      'Aujourd''hui c''est l''anniversaire du Pasteur '
        || pastor.first_name || ' ' || pastor.last_name
        || '. Pensez à le saluer !',
      'system',
      pastor.id,
      m.id,
      pastor.first_name || ' ' || pastor.last_name,
      false
    FROM public.users m
    WHERE m.church_id = pastor.church_id
      AND m.id != pastor.id
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

-- ─── 2. Désactive TOUS les autres crons d'anniversaire ───
DO $$
DECLARE
  v_jobid BIGINT;
BEGIN
  FOR v_jobid IN
    SELECT jobid FROM cron.job
    WHERE jobname IN (
      'notify-member-birthdays',
      'all_birthdays_8am',
      'all-birthdays-8am'
    )
  LOOP
    PERFORM cron.unschedule(v_jobid);
  END LOOP;
END $$;

-- ─── 3. Drop fonctions devenues inutiles ───
DROP FUNCTION IF EXISTS public.notify_member_birthdays();
DROP FUNCTION IF EXISTS public.notify_all_birthdays();

-- ─── 4. Re-schedule le cron pasteur (idempotent) ───
DO $$
DECLARE
  v_jobid BIGINT;
BEGIN
  SELECT jobid INTO v_jobid FROM cron.job WHERE jobname = 'notify-pastor-birthdays';
  IF v_jobid IS NOT NULL THEN
    PERFORM cron.unschedule(v_jobid);
  END IF;
END $$;

SELECT cron.schedule(
  'notify-pastor-birthdays',
  '0 8 * * *', -- 8h UTC = 8h Côte d'Ivoire
  $$ SELECT public.notify_pastor_birthdays(); $$
);

-- ─── Vérification ───
-- SELECT * FROM cron.job;  -- doit afficher SEULEMENT notify-pastor-birthdays
-- SELECT public.notify_pastor_birthdays(); -- test manuel
