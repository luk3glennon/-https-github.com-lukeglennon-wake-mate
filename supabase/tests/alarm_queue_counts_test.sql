-- Direct data-level test for public.alarm_queue_counts() (ticket 06), which
-- backs the Home screen's per-Alarm Queue-count badge.
--
-- No local Supabase CLI/Docker is available in this dev environment, so this
-- hasn't been run here; it's meant to be run by a developer or a future CI
-- step against a real Postgres/Supabase instance with:
--   psql "$DATABASE_URL" -f supabase/tests/alarm_queue_counts_test.sql
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
  v_other_alarm_id uuid;
  v_share_id uuid;
  v_other_share_id uuid;
  v_count bigint;
  v_other_count bigint;
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

  insert into alarms (id, owner_id, wake_time)
  values
    (gen_random_uuid(), v_recipient_id, '07:00:00'),
    (gen_random_uuid(), v_recipient_id, '08:00:00')
  returning id into v_alarm_id;

  -- second row of the two-row insert above isn't captured by the single
  -- "returning into" above, so fetch it explicitly.
  select id into v_other_alarm_id from alarms where owner_id = v_recipient_id and id <> v_alarm_id;

  insert into shares (alarm_call_id, friend_connection_id, sender_id, recipient_id)
  values (v_alarm_call_id, v_connection_id, v_sender_id, v_recipient_id)
  returning id into v_share_id;

  insert into shares (alarm_call_id, friend_connection_id, sender_id, recipient_id)
  values (v_alarm_call_id, v_connection_id, v_sender_id, v_recipient_id)
  returning id into v_other_share_id;

  -- Three queue entries land on the first Alarm, one of them already
  -- played, none on the second: the count-per-alarm should only count the
  -- two still-unplayed entries (a played one has already been heard, so it
  -- shouldn't keep inflating the badge), and an Alarm with zero unplayed
  -- entries shouldn't show up as a row at all (plain inner group by).
  --
  -- This runs as the postgres role, which bypasses RLS entirely, so it
  -- exercises the aggregation logic only, not the "invoker's own alarms
  -- only" scoping that RLS adds on top for a real authenticated caller
  -- (that scoping is exactly what the "Users can view queue entries for
  -- their own alarms" policy already has, and is otherwise identical
  -- Postgres RLS machinery already relied on elsewhere in this schema).
  insert into queue_entries (alarm_id, share_id, alarm_call_id, played_at)
  values
    (v_alarm_id, v_share_id, v_alarm_call_id, null),
    (v_alarm_id, v_other_share_id, v_alarm_call_id, null);

  insert into shares (alarm_call_id, friend_connection_id, sender_id, recipient_id)
  values (v_alarm_call_id, v_connection_id, v_sender_id, v_recipient_id)
  returning id into v_share_id;

  insert into queue_entries (alarm_id, share_id, alarm_call_id, played_at)
  values (v_alarm_id, v_share_id, v_alarm_call_id, now());

  select queue_count into v_count from public.alarm_queue_counts() where alarm_id = v_alarm_id;
  select queue_count into v_other_count from public.alarm_queue_counts() where alarm_id = v_other_alarm_id;

  if v_count is distinct from 2 then
    raise exception 'FAIL: alarm_queue_counts() returned % for the alarm with two unplayed entries (expected 2, played entries should not count)', v_count;
  end if;

  if v_other_count is not null then
    raise exception 'FAIL: alarm_queue_counts() returned a row for an alarm with no unplayed entries (%)', v_other_count;
  end if;

  raise notice 'PASS: alarm_queue_counts() reflects each alarm''s own unplayed queue depth only';
end $$;

rollback;
