-- Ticket 05: Alarm Call recording & Library.
--
-- alarm_calls is the sender's permanent, reusable recording (CONTEXT.md);
-- library_entries is the unified per-user pool of both self-created and
-- (later, ticket 06/07) received-and-played calls. Schema matches
-- .scratch/wake-mate/issues/10-data-model-schema.md exactly.
create table alarm_calls (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  storage_path text not null,
  duration_seconds numeric not null check (duration_seconds > 0 and duration_seconds <= 30),
  created_at timestamptz not null default now()
);

create index alarm_calls_owner_idx on alarm_calls (owner_id);

alter table alarm_calls enable row level security;

create policy "Users can view their own alarm calls"
  on alarm_calls for select
  using (auth.uid() = owner_id);

create policy "Users can create their own alarm calls"
  on alarm_calls for insert
  with check (auth.uid() = owner_id);

-- library_entries: source = 'created' rows are inserted by the client in
-- the same flow as the alarm_calls insert above; source = 'received' rows
-- are ticket 06/07's job (claim_queue_head upserting on playback). The
-- unique (user_id, alarm_call_id) pair means re-adding an already-owned
-- clip is a no-op, not a duplicate.
create table library_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  alarm_call_id uuid not null references alarm_calls (id) on delete cascade,
  source text not null check (source in ('created', 'received')),
  added_at timestamptz not null default now(),
  unique (user_id, alarm_call_id)
);

create index library_entries_user_idx on library_entries (user_id);

alter table library_entries enable row level security;

create policy "Users can view their own library entries"
  on library_entries for select
  using (auth.uid() = user_id);

create policy "Users can add their own library entries"
  on library_entries for insert
  with check (auth.uid() = user_id);

-- alarms.library_override_alarm_call_id has been NULL-only until now (see
-- the ticket 04 migration's header comment) because alarm_calls didn't
-- exist yet. `on delete set null` falls an Alarm back to auto_play's
-- absence-of-override state rather than leaving a dangling reference if
-- the referenced clip is ever removed.
alter table alarms
  add constraint alarms_library_override_alarm_call_id_fkey
  foreign key (library_override_alarm_call_id) references alarm_calls (id) on delete set null;

-- consent_log: exactly per ticket 15/10. Mic-recording consent is captured
-- in-app alongside (not instead of) the OS mic permission prompt, logged
-- here rather than relying on OS permission state as evidence. No
-- update/delete policy yet — revocation flows are a future ticket's job;
-- for now this is an append-only log the client can read back for itself.
create table consent_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  consent_type text not null,
  granted_at timestamptz,
  revoked_at timestamptz
);

create index consent_log_user_idx on consent_log (user_id);

alter table consent_log enable row level security;

create policy "Users can view their own consent log"
  on consent_log for select
  using (auth.uid() = user_id);

create policy "Users can log their own consent"
  on consent_log for insert
  with check (auth.uid() = user_id);

-- Storage bucket for the client's presigned upload of a recorded Alarm
-- Call (ticket 11: this initial upload is ticket 05's job, distinct from
-- ticket 06's server-side per-Share copy mechanism). Objects are stored at
-- "{owner's auth.uid()}/{alarm_call id}.m4a"; the folder-prefix check below
-- is the standard Supabase Storage RLS idiom for per-user ownership.
-- Size limit is generous headroom over the ~120KB a 30s/32kbps clip
-- produces (ticket 13's locked recording format).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('alarm-calls', 'alarm-calls', false, 2097152, array['audio/mp4', 'audio/x-m4a', 'audio/aac']);

create policy "Users can upload their own alarm call audio"
  on storage.objects for insert
  with check (
    bucket_id = 'alarm-calls'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can read their own alarm call audio"
  on storage.objects for select
  using (
    bucket_id = 'alarm-calls'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Receiving a new Alarm Call into an Alarm's Queue always resets that
-- Alarm back to auto_play (CONTEXT.md). The real trigger source is
-- queue_entries, which doesn't exist until ticket 06 (it has a hard FK to
-- shares, also ticket 06's table). This standalone function is the
-- reset behavior itself, callable directly now so it can be data-level
-- tested ahead of ticket 06 wiring a trigger on queue_entries' insert to
-- call it per affected alarm_id. Not exposed to `authenticated` — it's an
-- internal mechanism, not a user-facing action.
create or replace function public.reset_alarm_to_auto_play(p_alarm_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update alarms
  set mode = 'auto_play', updated_at = now()
  where id = p_alarm_id;
$$;
