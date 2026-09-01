-- Deactivate the monthly job that deletes behavioral_events it never actually
-- summarised.
--
-- It aggregates into aggregate_insights and then runs
--   DELETE FROM behavioral_events WHERE created_at < now() - interval '18 months'
--
-- Its SELECT reads three keys that are never written:
--   conditions_at_event->>'activity_category'  — no such key; ConditionsAtEvent
--       .toJson has no category at all
--   conditions_at_event->>'precipitation'      — the real key is
--       precipitation_probability
--   geographic_context->>'state'               — present but empty in practice
--
-- So the summary written before the delete is almost entirely NULL, and the
-- delete is irreversible. Oldest row today is 2026-04-15, putting the first
-- destructive run around October 2027 — far enough away to be forgotten.
--
-- Deactivated, not dropped: the intent is sound and the schedule is worth
-- keeping as a record. Rewrite it against keys that exist, and against a
-- definition of "region" that survives geographic_context.state being empty,
-- before switching it back on.
--
-- cron.alter_job rather than UPDATE cron.job: the table is owned by the pg_cron
-- extension role and a direct UPDATE is permission denied. Matched on command
-- content rather than jobid, which is environment-specific; both ilike
-- conditions are required, since job 2 also mentions aggregate_insights but
-- only calls compute_aggregate_insights(), which reads monetization_events and
-- deletes nothing.

do $$
declare
  j bigint;
begin
  select jobid into j
    from cron.job
   where command ilike '%aggregate_insights%'
     and command ilike '%DELETE FROM behavioral_events%'
   limit 1;

  if j is null then
    raise notice 'no destructive compaction job found; nothing to do';
  else
    perform cron.alter_job(job_id => j, active => false);
    raise notice 'deactivated cron job %', j;
  end if;
end $$;
