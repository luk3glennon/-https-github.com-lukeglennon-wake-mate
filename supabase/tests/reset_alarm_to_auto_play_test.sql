-- Direct data-level test for public.reset_alarm_to_auto_play (ticket 05).
--
-- CONTEXT.md's mode-reset rule ("receiving a new Alarm Call into an Alarm's
-- Queue always resets that Alarm back to auto_play") can't be tested through
-- a real queue_entries insert yet — that table and its trigger are ticket
-- 06's job. This exercises the reset function itself directly, standing in
-- for that trigger until it exists.
--
-- No local Supabase CLI/Docker is available in this dev environment, so this
-- hasn't been run here; it's meant to be run by a developer or a future CI
-- step against a real Postgres/Supabase instance with:
--   psql "$DATABASE_URL" -f supabase/tests/reset_alarm_to_auto_play_test.sql
-- Everything runs inside a transaction rolled back at the end, so it's safe
-- to run against a real (including production) database and leaves no
-- residue either way.
begin;

do $$
declare
  v_user_id uuid := gen_random_uuid();
  v_alarm_id uuid;
  v_alarm_call_id uuid;
  v_mode text;
begin
  insert into auth.users (id, email)
  values (v_user_id, v_user_id || '@example.com');

  insert into alarm_calls (id, owner_id, storage_path, duration_seconds)
  values (gen_random_uuid(), v_user_id, v_user_id || '/clip.m4a', 5)
  returning id into v_alarm_call_id;

  insert into alarms (id, owner_id, wake_time, mode, library_override_alarm_call_id)
  values (gen_random_uuid(), v_user_id, '07:00:00', 'library_override', v_alarm_call_id)
  returning id into v_alarm_id;

  perform public.reset_alarm_to_auto_play(v_alarm_id);

  select mode into v_mode from alarms where id = v_alarm_id;

  if v_mode <> 'auto_play' then
    raise exception 'FAIL: reset_alarm_to_auto_play left mode as % (expected auto_play)', v_mode;
  end if;

  raise notice 'PASS: reset_alarm_to_auto_play resets library_override -> auto_play';
end $$;

rollback;
