-- Demo history that trips the adaptive wind suggestion.
--
-- NOT a migration. Nothing here should ever run against production — it
-- fabricates a user's history, which is the one thing this feature's whole
-- credibility rests on being real. It lives in the repo so the simulator
-- walkthrough is reproducible, and it deletes only rows it owns.
--
-- Run AFTER 20260826000000 (the conditions column) and 20260826000100 (the
-- suggestion event types).
--
-- TARGET: the most recently created auth user, because the simulator account
-- is anonymous and has no email to match on. That is a heuristic, not an
-- identity — if anyone else has signed in against this project since, it will
-- pick them instead. The script prints the account it chose before writing
-- anything, so check the NOTICE. To be certain, set v_user_id explicitly.
--
-- What it builds, twice — 'Morning Run' to accept on, 'Evening Walk' to
-- decline on, so both paths can be shown without re-seeding:
--
--   * a wind-only condition profile with wind_max = 25 km/h;
--   * five completed days at 8-14 km/h;
--   * three skipped days at 21, 23 and 24 km/h.
--
-- Eight decided days clears the cold-start floor of 8. Every skip sits above
-- the fastest day the user ever went out in (14), so all three qualify, which
-- clears the pattern floor of 3. The grid value below the lowest skip is 20,
-- which keeps every completed day and is 5 km/h below the current limit —
-- exactly the minimum delta. Expect:
--
--   "You've skipped 3 of your windiest matches. Lower the wind limit to
--    20 km/h?"
--
-- Wind only, so no other dimension can compete for the one suggestion slot
-- and the demo is deterministic.
--
-- Idempotent: re-running replaces these two activities' histories and touches
-- nothing else the user owns.

do $$
declare
  -- Leave null to take the most recently created auth user. Set it to a
  -- literal uuid to target a specific account instead.
  v_user_id     uuid := null;

  v_created_at  timestamptz;
  v_label       text;
  v_user_count  int;

  v_activity_id uuid;
  v_name        text;
  v_days_ago    int;
  v_outcome     text;
  v_wind        numeric;
  v_date        date;
begin
  if v_user_id is null then
    select count(*) into v_user_count from auth.users;
    if v_user_count = 0 then
      raise exception 'No auth users exist in this project.';
    end if;

    select id, created_at, coalesce(email, '(anonymous)')
      into v_user_id, v_created_at, v_label
      from auth.users
     order by created_at desc
     limit 1;

    raise notice
      'Seeding for the newest of % auth users: % — % — created %',
      v_user_count, v_user_id, v_label, v_created_at;
  else
    raise notice 'Seeding for the explicitly named user %', v_user_id;
  end if;

  foreach v_name in array array['Morning Run', 'Evening Walk'] loop

    -- Reuse the activity if it is already there, so re-running does not
    -- accumulate duplicates in the user's list.
    select id into v_activity_id
      from public.activities
     where user_id = v_user_id and name = v_name and not is_archived
     limit 1;

    if v_activity_id is null then
      begin
        insert into public.activities (user_id, name)
        values (v_user_id, v_name)
        returning id into v_activity_id;
      exception when foreign_key_violation then
        -- activities.user_id references profiles.id, and the app only ever
        -- reads that table — the row is created by a signup trigger. An
        -- account that never got one cannot own an activity, and the raw FK
        -- error does not say so.
        raise exception
          'User % cannot own an activity: no public.profiles row. Either the '
          'signup trigger did not run for this anonymous account, or the '
          'newest auth user is not the simulator account. Check the NOTICE '
          'above and set v_user_id explicitly.', v_user_id;
      end;
    end if;

    -- Wind only, at a limit the history is about to contradict.
    delete from public.condition_profiles where activity_id = v_activity_id;
    insert into public.condition_profiles
      (activity_id, temp_enabled, precip_enabled, wind_enabled, wind_max)
    values (v_activity_id, false, false, true, 25);

    -- Owned rows only. Re-running replaces this activity's history and
    -- touches nothing else.
    delete from public.activity_day_outcomes
     where user_id = v_user_id and activity_id = v_activity_id;

    for v_days_ago, v_outcome, v_wind in
      select * from unnest(
        array[    30,      27,      24,      20,      17,        12,        9,         5],
        array['done',  'done',  'done',  'done',  'done', 'skipped','skipped', 'skipped'],
        array[   8.0,    10.0,    12.0,     9.0,    14.0,      21.0,     23.0,      24.0]
      )
    loop
      v_date := current_date - v_days_ago;

      insert into public.activity_day_outcomes
        (user_id, activity_id, local_date, matched, outcome, answered_at,
         conditions)
      values (
        v_user_id,
        v_activity_id,
        v_date,
        true,
        v_outcome,
        (v_date + time '18:00')::timestamptz,
        -- DailyForecast.toJson(): wind already in km/h under windSpeedMaxKmh,
        -- temperatures in Celsius. Temperatures are held flat and unremarkable
        -- so they cannot produce a competing temperature suggestion.
        jsonb_build_object(
          'time', (v_date + time '13:00')::timestamptz,
          'values', jsonb_build_object(
            'temperatureMax', 22.0,
            'temperatureMin', 12.0,
            'precipitationProbability', 5.0,
            'windSpeedMaxKmh', v_wind,
            'weatherCode', 1000
          )
        )
      );
    end loop;

    raise notice 'Seeded % (%) with 8 decided days', v_name, v_activity_id;
  end loop;
end $$;
