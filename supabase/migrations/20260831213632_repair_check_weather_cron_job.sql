-- Repair the hourly job that invokes check-weather.
--
-- It has failed 4,185 times in a row since 2026-03-10 — every scheduled run
-- since it was created, without a single success — for three independent
-- reasons, any one of which was sufficient:
--
--   1. The headers were built by concatenating a secret into a JSON *literal*:
--        '{"Authorization": "Bearer ' || current_setting(...) || '"}'::jsonb
--      which never produced valid JSON. This is the error that actually fired:
--        ERROR: invalid input syntax for type json
--        DETAIL: Token ""}" is invalid.
--
--   2. app.service_role_key was never set, so there was nothing to concatenate.
--
--   3. pg_net was never installed, so net.http_post does not exist. Even a
--      correctly built request had nothing to send it.
--
-- All three are fixed here. The secret itself is not: it is supplied out of
-- band, through Vault, so that no key is ever written into a migration, a
-- cron command, or this repository.
--
-- Behaviour until the secret is added: the job runs, finds no secret, raises a
-- NOTICE and returns. That is a clean success rather than a failure, which
-- keeps cron.job_run_details usable as a signal instead of a wall of identical
-- errors.

-- 1. The HTTP client the job has always assumed existed.
create extension if not exists pg_net;

-- 2. Rebuild the command.
do $$
declare
  j bigint;
  new_command text;
begin
  select jobid into j
    from cron.job
   where command ilike '%functions/v1/check-weather%'
   limit 1;

  if j is null then
    raise notice 'no check-weather cron job found; nothing to repair';
    return;
  end if;

  -- jsonb_build_object rather than string concatenation. A key containing a
  -- quote, a slash or a newline cannot corrupt the document, which is exactly
  -- how the previous version failed every hour for six months.
  --
  -- The secret comes from Vault, read at run time. Absent secret => NOTICE and
  -- return, never an exception and never an unauthenticated request: the
  -- function now refuses anything but the service role key, so a request
  -- without it would only produce a 401 an hour, forever.
  new_command := $cmd$
do $inner$
declare
  k text;
begin
  select decrypted_secret into k
    from vault.decrypted_secrets
   where name = 'service_role_key'
   limit 1;

  if k is null or k = '' then
    raise notice 'check-weather: vault secret service_role_key not set; skipping';
    return;
  end if;

  perform net.http_post(
    url     := 'https://tswxxjwqnppqlfcbfowt.supabase.co/functions/v1/check-weather',
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'Authorization', 'Bearer ' || k
               ),
    body    := '{}'::jsonb
  );
end
$inner$;
$cmd$;

  perform cron.alter_job(job_id => j, command => new_command);
  raise notice 'repaired check-weather cron job %', j;
end $$;
