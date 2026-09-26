-- Ticket 06: Share sending & Queue population.
--
-- shares is the record of one clip being sent to one friend (CONTEXT.md: a
-- Share is per-recipient, even though the underlying alarm_calls recording
-- is reusable). storage_path/uploaded_at start null and are filled in by the
-- createShare Edge Function once it has server-side copied the sender's
-- clip into this Share's own Storage object (ticket 11: never reuse the
-- sender's original object, so a later delete of the source clip can't take
-- a live Share down with it). expires_at is fixed at insert time; ticket 08
-- owns actually deleting expired rows.
create table shares (
  id uuid primary key default gen_random_uuid(),
  alarm_call_id uuid not null references alarm_calls (id) on delete cascade,
  friend_connection_id uuid not null references friend_connections (id) on delete cascade,
  sender_id uuid not null references auth.users (id) on delete cascade,
  recipient_id uuid not null references auth.users (id) on delete cascade,
  storage_path text,
  uploaded_at timestamptz,
  downloaded_at timestamptz,
  expires_at timestamptz not null default (now() + interval '48 hours'),
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

create index shares_recipient_idx on shares (recipient_id);
create index shares_sender_idx on shares (sender_id);

alter table shares enable row level security;

-- No insert/update/delete policy: every write to this table goes through
-- createShare/getShareDownloadUrl (service-role Edge Functions, ticket 11),
-- since both need to act across the sender/recipient boundary that a single
-- user's RLS-scoped client can never satisfy.
create policy "Sender or recipient can view a share"
  on shares for select
  using (auth.uid() = sender_id or auth.uid() = recipient_id);

-- queue_entries: one row per (Alarm, Share) — a Share fans out to every one
-- of the recipient's *current* Alarms at send time (ADR-0002), never
-- retroactively to Alarms created afterward. The unique pair below is what
-- makes that fan-out idempotent if createShare's insert were ever retried.
create table queue_entries (
  id uuid primary key default gen_random_uuid(),
  alarm_id uuid not null references alarms (id) on delete cascade,
  share_id uuid not null references shares (id) on delete cascade,
  alarm_call_id uuid not null references alarm_calls (id) on delete cascade,
  received_at timestamptz not null default now(),
  played_at timestamptz,
  unique (alarm_id, share_id)
);

-- FIFO order within one Alarm's Queue (CONTEXT.md: Queue is FIFO, locked).
-- Partial on unplayed rows only: those are the only ones a FIFO scan of "what
-- plays next" ever needs, and it keeps the index from growing with history.
create index queue_entries_alarm_fifo_idx on queue_entries (alarm_id, received_at) where played_at is null;

alter table queue_entries enable row level security;

-- "Metadata only, never storage_path": storage_path isn't even a column on
-- this table (it lives on alarm_calls, whose own RLS already restricts
-- reads to that clip's owner — the sender, not the recipient), so scoping
-- this row-level policy to the Alarm's owner is sufficient on its own; no
-- separate column-level grant is needed.
create policy "Users can view queue entries for their own alarms"
  on queue_entries for select
  using (
    exists (
      select 1 from alarms a
      where a.id = queue_entries.alarm_id
        and a.owner_id = auth.uid()
    )
  );

-- Receiving a new Alarm Call into an Alarm's Queue always resets that Alarm
-- back to auto_play (CONTEXT.md), via the same function ticket 05 already
-- data-level-tested ahead of this trigger existing.
create or replace function public.queue_entries_reset_alarm_mode()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.reset_alarm_to_auto_play(new.alarm_id);
  return new;
end;
$$;

create trigger queue_entries_after_insert
  after insert on queue_entries
  for each row
  execute function public.queue_entries_reset_alarm_mode();

-- device_tokens: one row per physical device registration. A given APNs
-- token is unique across the whole table (not per-user) because reinstalls,
-- restores, and account switches can hand the same token to a different
-- signed-in user over time — register_device_token below reassigns rather
-- than erroring on that reuse.
create table device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  apns_token text not null unique,
  created_at timestamptz not null default now(),
  invalidated_at timestamptz
);

create index device_tokens_user_idx on device_tokens (user_id, invalidated_at);

alter table device_tokens enable row level security;

create policy "Users can view their own device tokens"
  on device_tokens for select
  using (auth.uid() = user_id);

-- The only write path for this table. security definer because a plain
-- client-side upsert can't reassign a row RLS says belongs to someone else
-- (see the header note above) — this function is the one place that
-- reassignment is allowed to happen, and only ever to auth.uid() itself.
create or replace function public.register_device_token(p_apns_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into device_tokens (user_id, apns_token)
  values (auth.uid(), p_apns_token)
  on conflict (apns_token) do update
  set user_id = excluded.user_id, invalidated_at = null
  where device_tokens.user_id is distinct from excluded.user_id
     or device_tokens.invalidated_at is not null;
end;
$$;

grant execute on function public.register_device_token(text) to authenticated;

-- Push-on-upload trigger (ticket 18: Database Webhook -> Edge Function ->
-- direct APNs, best-effort, no retry/backoff).
--
-- The Dashboard's "Database Webhooks" feature normally generates a trigger
-- calling a convenience wrapper, supabase_functions.http_request() — but
-- that wrapper does not exist in this project (confirmed directly against
-- the live database: no such schema/function). This hand-rolls the same
-- effect with pg_net's net.http_post() instead, which is available as a
-- listed extension here.
--
-- This intentionally does not send any Authorization header carrying the
-- service-role key: that secret can't be embedded in a migration file
-- committed to git. Instead share-notify (see its config.toml entry) is
-- deployed with verify_jwt = false and treats its input as informational
-- only (it never trusts the payload for anything beyond "look up this
-- recipient's device tokens and try to push them a notification"). Worst
-- case of that being hit directly is an unwanted push, not any data
-- exposure — consistent with this project's already-documented
-- non-adversarial MVP threat model (see .scratch/wake-mate/issues/10, Q6).
create extension if not exists pg_net;

create or replace function public.notify_share_uploaded()
returns trigger
language plpgsql
security definer
set search_path = public, net, extensions
as $$
begin
  perform net.http_post(
    url := 'https://worfipnzoovqfgcaclkf.supabase.co/functions/v1/share-notify',
    body := jsonb_build_object(
      'share_id', new.id,
      'sender_id', new.sender_id,
      'recipient_id', new.recipient_id
    ),
    headers := '{"Content-Type": "application/json"}'::jsonb,
    timeout_milliseconds := 5000
  );
  return new;
end;
$$;

-- Fires once, on the specific null -> non-null transition that means "the
-- server-side copy just finished" — not on every future update of the row
-- (e.g. downloaded_at being stamped later doesn't re-fire this).
create trigger shares_after_upload
  after update of uploaded_at on shares
  for each row
  when (old.uploaded_at is null and new.uploaded_at is not null)
  execute function public.notify_share_uploaded();

-- One row per Alarm that currently has at least one *unplayed* queued entry,
-- for the Home screen's per-Alarm Queue-count badge — a played entry has
-- already been heard, so it shouldn't keep inflating the badge forever.
-- Plain "language sql" (not security definer) so it runs with the caller's
-- own privileges — the existing "Users can view queue entries for their own
-- alarms" policy above already scopes the underlying rows to ones the
-- caller owns.
create or replace function public.alarm_queue_counts()
returns table (alarm_id uuid, queue_count bigint)
language sql
stable
as $$
  select alarm_id, count(*) as queue_count
  from queue_entries
  where played_at is null
  group by alarm_id;
$$;

grant execute on function public.alarm_queue_counts() to authenticated;

-- Storage bucket for a Share's own copy of the audio (ticket 11: distinct
-- from the sender's alarm-calls object). Deliberately no storage.objects RLS
-- policies here: every read/write of this bucket goes through createShare/
-- getShareDownloadUrl using the service-role client, which bypasses RLS
-- entirely, so a client-facing policy would just be dead code.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('shares', 'shares', false, 2097152, array['audio/mp4', 'audio/x-m4a', 'audio/aac']);
