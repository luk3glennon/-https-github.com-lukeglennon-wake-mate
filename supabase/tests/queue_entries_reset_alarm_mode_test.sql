-- Direct data-level test for the queue_entries_after_insert trigger
-- (ticket 06), which is the real mechanism reset_alarm_to_auto_play_test.sql
-- said it was standing in for until this table/trigger existed.
--
-- No local Supabase CLI/Docker is available in this dev environment, so this
-- hasn't been run here; it's meant to be run by a developer or a future CI
-- step against a real Postgres/Supabase instance with:
--   psql "$DATABASE_URL" -f supabase/tests/queue_entries_reset_alarm_mode_test.sql
-- Everything runs inside a transaction rolled back at the end, so it's safe
-- to run against a real (including production) database and leaves no
-- residue either way.
begin;

do $$
declare
  v_sender_id uuid := gen_random_uuid();
  v_recipient_id uuid := gen_random_uuid();
  v_connection_id uuid;
  v_alarm_call_id uuid;
  v_alarm_id uuid;
  v_share_id uuid;
  v_mode text;
begin
  insert into auth.users (id, email)
  values
    (v_sender_id, v_sender_id || '@example.com'),
    (v_recipient_id, v_recipient_id || '@example.com');

  insert into friend_connections (requester_id, addressee_id, status, responded_at)
  values (v_sender_id, v_recipient_id, 'accepted', now())
  returning id into v_connection_id;

  insert into alarm_calls (id, owner_id, storage_path, duration_seconds)
  values (gen_random_uuid(), v_sender_id, v_sender_id || '/clip.m4a', 5)
  returning id into v_alarm_call_id;

  -- The recipient's Alarm starts in library_override so the test can prove
  -- the trigger actually resets it, not just that it happens to already be
  -- auto_play.
  insert into alarms (id, owner_id, wake_time, mode, library_override_alarm_call_id)
  values (gen_random_uuid(), v_recipient_id, '07:00:00', 'library_override', v_alarm_call_id)
  returning id into v_alarm_id;

  insert into shares (alarm_call_id, friend_connection_id, sender_id, recipient_id)
  values (v_alarm_call_id, v_connection_id, v_sender_id, v_recipient_id)
  returning id into v_share_id;

  insert into queue_entries (alarm_id, share_id, alarm_call_id)
  values (v_alarm_id, v_share_id, v_alarm_call_id);

  select mode into v_mode from alarms where id = v_alarm_id;

  if v_mode <> 'auto_play' then
    raise exception 'FAIL: queue_entries_after_insert left mode as % (expected auto_play)', v_mode;
  end if;

  raise notice 'PASS: inserting a queue_entries row resets its alarm to auto_play';
end $$;

rollback;
