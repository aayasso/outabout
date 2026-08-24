-- Demo history that trips the adaptive wind suggestion.
--
-- NOT a migration. Nothing here should ever run against production — it
-- fabricates a user's history, which is the one thing this feature's whole
-- credibility rests on being real. It lives in the repo so the simulator
-- walkthrough is reproducible, and it deletes only rows it owns.
--
-- Run AFTER 20260826000000 (the conditions column) and 20260826000100 (the
-- suggestion event types), against a development project, with the email of
-- the account signed into the simulator.
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

do $$
declare
  -- The account signed into the simulator.
  v_email       text := 'CHANGE_ME@example.com';

  v_user_id     uuid;
  v_activity_id uuid;
  v_name        text;
  v_days_ago    int;
  v_outcome     text;
  v_wind        numeric;
  v_date        date;
begin
  select id into v_user_id from auth.users where email = v_email;
  if v_user_id is null then
    raise exception 'No auth user for %. Set v_email to the simulator account.',
      v_email;
  end if;

  foreach v_name in array array['Morning Run', 'Evening Walk'] loop

    -- Reuse the activity if it is already there, so re-running does not
    -- accumulate duplicates in the user's list.
    select id into v_activity_id
      from public.activities
     where user_id = v_user_id and name = v_name and not is_archived
     limit 1;

    if v_activity_id is null then
      insert into public.activities (user_id, name)
      values (v_user_id, v_name)
      returning id into v_activity_id;
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
        array[ 30,      27,      24,      20,      17,      12,       9,       5],
        array['done',  'done',  'done',  'done',  'done',  'skipped','skipped','skipped'],
        array[  8.0,    10.0,    12.0,     9.0,    14.0,     21.0,    23.0,    24.0]
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
