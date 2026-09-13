-- Ticket 04: Alarm scheduling core (AlarmKit).
--
-- One row per user-configured Alarm (the schedule), distinct from an Alarm
-- Call (the recorded audio) per CONTEXT.md. `library_override_alarm_call_id`
-- has no foreign key yet because `alarm_calls` doesn't exist until ticket
-- 05 — that ticket's migration adds the constraint once the referenced
-- table exists. Until then the app only ever writes NULL there (mode stays
-- 'auto_play' for this ticket; ticket 05 adds the Library-override UI).
--
-- repeat_days uses Foundation's Calendar.Component.weekday numbering
-- (1 = Sunday ... 7 = Saturday) so the client can pass DateComponents.weekday
-- values straight through without a translation table.
--
-- snooze_enabled/snooze_duration_minutes are per-row per the ticket's data
-- model, but ADR-0003 fixes actual snooze behavior to a single global
-- default for the MVP (no per-Alarm snooze UI yet) — these columns exist
-- now so ticket 20's later per-Alarm configurability doesn't need a
-- follow-up migration, but the app does not yet let a user change them
-- from their defaults.
create table alarms (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  label text,
  wake_time time not null,
  repeat_days smallint[] not null default '{}',
  mode text not null default 'auto_play' check (mode in ('auto_play', 'library_override')),
  library_override_alarm_call_id uuid,
  snooze_enabled boolean not null default true,
  snooze_duration_minutes int not null default 9 check (snooze_duration_minutes > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (repeat_days <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[])
);

create index alarms_owner_idx on alarms (owner_id);

alter table alarms enable row level security;

create policy "Users can view their own alarms"
  on alarms for select
  using (auth.uid() = owner_id);

create policy "Users can create their own alarms"
  on alarms for insert
  with check (auth.uid() = owner_id);

create policy "Users can update their own alarms"
  on alarms for update
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create policy "Users can delete their own alarms"
  on alarms for delete
  using (auth.uid() = owner_id);
