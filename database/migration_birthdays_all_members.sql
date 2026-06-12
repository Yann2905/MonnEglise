-- ============================================================================
-- MIGRATION : Anniversaires pour TOUS les membres (pas seulement le pasteur)
-- ============================================================================
-- Étend la fonction d'anniversaire pour notifier tous les membres d'une église
-- quand n'importe quel membre fête son anniversaire ce jour-là.
--
-- À exécuter dans le SQL Editor Supabase une seule fois.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;

CREATE OR REPLACE FUNCTION public.notify_all_birthdays()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  birthday_user RECORD;
  inserted_cnt  INTEGER := 0;
BEGIN
  FOR birthday_user IN
    SELECT u.id, u.first_name, u.last_name, u.church_id, u.role_global
    FROM public.users u
    WHERE u.birth_date IS NOT NULL
      AND u.church_id IS NOT NULL
      AND EXTRACT(MONTH FROM u.birth_date) = EXTRACT(MONTH FROM NOW())
      AND EXTRACT(DAY FROM u.birth_date)   = EXTRACT(DAY FROM NOW())
  LOOP
    -- Notifie tous les autres membres de la même église
    INSERT INTO public.notifications (
      title, message, type, sender_id, receiver_id, actor_name, is_read, metadata
    )
    SELECT
      '🎂 Anniversaire',
      CASE
        WHEN birthday_user.role_global = 'admin'
        THEN 'Aujourd''hui c''est l''anniversaire du pasteur ' || birthday_user.first_name || ' ' || birthday_user.last_name || ' ! Souhaitez-lui une belle journée.'
        ELSE 'Aujourd''hui c''est l''anniversaire de ' || birthday_user.first_name || ' ' || birthday_user.last_name || '. Pensez à lui souhaiter !'
      END,
      'system',
      birthday_user.id,
      receiver.id,
      birthday_user.first_name || ' ' || birthday_user.last_name,
      FALSE,
      jsonb_build_object('birthday_user_id', birthday_user.id)
    FROM public.users receiver
    WHERE receiver.church_id = birthday_user.church_id
      AND receiver.id != birthday_user.id;

    inserted_cnt := inserted_cnt + 1;
  END LOOP;

  RETURN inserted_cnt;
END;
$$;

-- Désactive l'ancien job pasteur-seulement si présent
DO $$
DECLARE
  v_jobid BIGINT;
BEGIN
  SELECT jobid INTO v_jobid FROM cron.job WHERE jobname = 'pastor_birthdays_8am';
  IF v_jobid IS NOT NULL THEN
    PERFORM cron.unschedule(v_jobid);
  END IF;
END $$;

-- Désactive le nouveau job s'il existe déjà (pour ré-exécution idempotente)
DO $$
DECLARE
  v_jobid BIGINT;
BEGIN
  SELECT jobid INTO v_jobid FROM cron.job WHERE jobname = 'all_birthdays_8am';
  IF v_jobid IS NOT NULL THEN
    PERFORM cron.unschedule(v_jobid);
  END IF;
END $$;

-- Cron : tous les jours à 8h UTC = ~8h GMT (Côte d'Ivoire = UTC+0)
SELECT cron.schedule(
  'all_birthdays_8am',
  '0 8 * * *',
  $$SELECT public.notify_all_birthdays();$$
);

-- ─── Test ────────────────────────────────────────────────────────────────────
-- Pour vérifier manuellement (à exécuter avec un user qui a birth_date = aujourd'hui) :
--   SELECT public.notify_all_birthdays();
--   SELECT * FROM cron.job;
--   SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 5;
