Status: resolved
Type: grilling
Blocked by: 09

## Question

Given the chosen backend's data paradigm (ticket 09), formalize the concrete schema/fields/relations for: Alarm, Alarm Call, Share, Friend Connection, Queue, Library. See CONTEXT.md for the settled domain vocabulary these schemas must express.

## Notes

Ticket 15 (GDPR technical policy decisions) surfaced two concrete schema requirements to fold in here: a `consent_log` table (user_id, consent_type, granted_at, revoked_at) for contacts/mic consent records, and `uploaded_at`/`downloaded_at`/`expires_at` tracking columns on whatever holds a Share's temporary cloud copy, needed by ticket 15's scheduled-deletion Edge Function.

Also cover device-token storage: ticket 18 (push notification implementation approach, resolved) requires a device-tokens table/relation so its Edge Function can look up a recipient's APNs token(s) when a new Alarm Call lands in their Queue; multi-device lifecycle (registration, invalidation on 410 Unregistered) is this ticket's to decide, not ticket 18's.

## Answer

Five load-bearing forks were grilled and resolved (see [ADR-0002](../../docs/adr/0002-shares-fan-out-to-every-alarm.md) for the one surprising enough to warrant a standing record). Schema below is Postgres/Supabase DDL, `auth.users` as the Supabase-managed identity table, `gen_random_uuid()` PKs throughout.

### profiles

Extends `auth.users` with the app-facing identity (ticket 16's Handle).

```sql
create table profiles (
  user_id uuid primary key references auth.users(id),
  handle text not null unique,
  created_at timestamptz not null default now()
);
```

### friend_connections

Single asymmetric row per connection (**Q5**), not a pair of symmetric rows.

```sql
create table friend_connections (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references profiles(user_id),
  addressee_id uuid not null references profiles(user_id),
  status text not null check (status in ('pending','accepted','declined')) default 'pending',
  requested_at timestamptz not null default now(),
  responded_at timestamptz,
  check (requester_id <> addressee_id)
);
-- normalized-pair uniqueness prevents duplicate/reverse-duplicate requests between the same two users
create unique index friend_connections_pair_idx
  on friend_connections (least(requester_id, addressee_id), greatest(requester_id, addressee_id));
```

### alarms

```sql
create table alarms (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(user_id),
  label text,
  wake_time time not null,
  repeat_days smallint[] not null default '{}',  -- ISO weekday ints, empty = one-off
  mode text not null check (mode in ('auto_play','library_override')) default 'auto_play',
  library_override_alarm_call_id uuid references alarm_calls(id),
  snooze_enabled boolean not null default true,
  snooze_duration_minutes int not null default 9,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

Snooze fields are a stub — the snooze/dismiss *interaction* (e.g. does snooze replay the same clip) is explicitly deferred; see the new ticket this resolution graduates.

### alarm_calls

The sender's permanent, reusable recording (CONTEXT.md: "one recording can be Shared to any number of friends independently"). Fixed encoding profile per ticket 13 (AAC-HE mono 44.1kHz 32kbps, ≤30s), so no per-row codec metadata is needed.

```sql
create table alarm_calls (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(user_id),
  storage_path text not null,
  duration_seconds numeric not null,
  created_at timestamptz not null default now()
);
```

### shares

One row per fan-out send. Doubles as the temporary-cloud-copy tracker (**Q2**) — no separate delivery table.

```sql
create table shares (
  id uuid primary key default gen_random_uuid(),
  alarm_call_id uuid not null references alarm_calls(id),
  friend_connection_id uuid not null references friend_connections(id),
  sender_id uuid not null references profiles(user_id),
  recipient_id uuid not null references profiles(user_id),  -- denormalized for query convenience
  storage_path text,  -- per-Share copy of alarm_calls.storage_path (ticket 11 Q7); null until confirmUpload
  created_at timestamptz not null default now(),
  uploaded_at timestamptz,
  downloaded_at timestamptz,
  expires_at timestamptz not null default (now() + interval '48 hours'),  -- ticket 15's 48h window
  deleted_at timestamptz  -- set once the scheduled cleanup Edge Function (ticket 15) removes this Share's cloud object
);
```

**Addendum (ticket 11 session):** `shares.storage_path` was added and the `expires_at` default changed from 24h to 48h (ticket 15 revised its window). Ticket 11 decided each Share gets its own Storage object, server-copied from `alarm_calls.storage_path` at Share-creation time — not a shared/reused object — so `alarm_calls.storage_path` (the sender's permanent copy) is never touched by ticket 15's cleanup job, and one Share's expiry/deletion can never affect another Share of the same reused Alarm Call. See ticket 11 for the full upload/download flow.

### queue_entries

Materialized fan-out (**Q1**): on `shares` insert, one row is created here for *every* Alarm the recipient currently owns (a trigger or the same Edge Function that handles the Share). Each entry tracks its own `played_at` independently, so the same underlying Share can be "played" via one Alarm while still sitting unplayed in another's Queue — the accepted consequence of fan-to-all (see ADR-0002).

```sql
create table queue_entries (
  id uuid primary key default gen_random_uuid(),
  alarm_id uuid not null references alarms(id),
  share_id uuid not null references shares(id),
  alarm_call_id uuid not null references alarm_calls(id),  -- denormalized from shares for query convenience
  received_at timestamptz not null default now(),
  played_at timestamptz,
  unique (alarm_id, share_id)
);
create index queue_entries_fifo_idx on queue_entries (alarm_id, received_at) where played_at is null;
```

Receiving a new entry resets that Alarm's `mode` back to `auto_play` (CONTEXT.md) — a trigger on insert, per affected `alarm_id`.

### library_entries

One unified table (**Q3**) covering both a user's own creations and saved-from-received calls.

```sql
create table library_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(user_id),
  alarm_call_id uuid not null references alarm_calls(id),
  source text not null check (source in ('created','received')),
  added_at timestamptz not null default now(),
  unique (user_id, alarm_call_id)
);
```

Inserted with `source = 'created'` at `alarm_calls` insert time (owner's own row), and with `source = 'received'` (on conflict do nothing — the same call may already be there) whenever a `queue_entries` row is claimed played.

### device_tokens

Multi-device (**Q4**); a re-registered token string reassigns ownership rather than erroring.

```sql
create table device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(user_id),
  apns_token text not null unique,
  platform text not null default 'ios',
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  invalidated_at timestamptz
);
-- registration: insert ... on conflict (apns_token) do update
--   set user_id = excluded.user_id, last_seen_at = now(), invalidated_at = null;
-- invalidation: set invalidated_at = now() when APNs returns 410 Unregistered (ticket 18)
```

### consent_log

Exactly as ticket 15 specified.

```sql
create table consent_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(user_id),
  consent_type text not null,
  granted_at timestamptz,
  revoked_at timestamptz
);
```

### Server-enforced "locked" Queue (**Q6**)

RLS alone can't express "before that Alarm fires" (the DB doesn't know a device's local fire clock), so the gate is a `security definer` RPC, not a raw table policy:

```sql
create function claim_queue_head(p_alarm_id uuid)
returns table (storage_path text, alarm_call_id uuid)
security definer as $$
  -- verify auth.uid() owns p_alarm_id
  -- if mode = 'library_override': return the override alarm_call's storage_path, no queue_entries mutation
  -- if mode = 'auto_play': select the oldest unplayed queue_entries row for p_alarm_id (FIFO head);
  --   if none, return empty (client falls back per ticket 04);
  --   else set played_at = now(), upsert library_entries(user_id, alarm_call_id, 'received'), return its storage_path
$$;
```

RLS on `queue_entries` permits the owner to `select` metadata (`id`, `received_at`, `played_at`) for counts/ordering, but the client never reads `alarm_calls.storage_path` for an unplayed entry directly — only `claim_queue_head` (called when the Alarm actually fires) returns it.

**Reconciles with ticket 06's reliability requirement**: this gates the *play/claim* transition only, not file transfer. Downloading/prefetching a Share's audio to the device is unrestricted from the moment it's queued — required so the full clip is already local, network-independent, by the time AlarmKit fires. "Locked" means the app never shows playback controls or flips `played_at` early under normal use, not that the ciphertext-in-transit is withheld; this is a security definer boundary against API misuse (skipping the FIFO order via a raw query), not a DRM guarantee against a compromised client, consistent with this MVP's non-adversarial threat model (ticket 14/15). Flagged as a note on ticket 11 (Share transfer mechanism), which still owns presigned-vs-relay and retry/expiry specifics.
