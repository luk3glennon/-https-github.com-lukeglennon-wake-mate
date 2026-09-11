# Wake Mate — MVP Technical Architecture Spec

Compiled from the [wayfinder map](map.md) — 22 resolved tickets and 3 ADRs. Every decision below is closed; nothing on the map is open, blocked, or unspecified. This document is the destination the map was charting toward: a spec sized so a dev (or Claude Code) can start the 4-week testable prototype build directly from it.

Full rationale for any decision lives in its source ticket (linked inline) — this doc states *what was decided*, not the debate that got there. Domain vocabulary (Alarm, Alarm Call, Share, Friend Connection, Queue, Library, Auto-play/Library Mode, Wake Event, Handle, Invite Link) is defined once in [`CONTEXT.md`](../../CONTEXT.md) and used as-is throughout.

## 1. Platform & client

- **Native SwiftUI**, not React Native/Flutter. No mature cross-platform bridge to AlarmKit exists; native sidesteps that risk entirely. Android is deferred to a future effort. — [Mobile client framework](issues/07-mobile-client-framework.md)
- **iOS 26+ hard minimum, no fallback tier.** AlarmKit (the only wake mechanism that survives force-quit/silent mode) requires it; a degraded pre-26 experience undermines the core reliability promise more than not installing at all. — [Minimum supported iOS version](issues/17-minimum-supported-ios-version.md), [ADR-0001](../../docs/adr/0001-minimum-ios-26.md)

## 2. Wake mechanism (AlarmKit)

- Built on Apple's **AlarmKit** (iOS 26+): fires through silent mode/Focus/DND, survives force-quit, presents full-screen/Lock Screen UI. Gated by a runtime `NSAlarmKitUsageDescription` authorization, not a restricted entitlement.
- The OS bakes in a short (≤30s) teaser sound at **schedule time** — it cannot play a not-yet-known file live. Architecture: AlarmKit fires the teaser reflecting the current Queue head; tapping through launches the app to play the full Alarm Call via `AVAudioPlayer`.
- "Resync wake trigger on queue mutation" hook: every Queue-head change (a new Share arriving) re-schedules AlarmKit's config (cancel + reschedule) opportunistically, on any execution window. If no window arises before fire time, the previously-scheduled head plays as-is — a benign degradation, not a broken state. This hook must **never** fire mid-Wake-Event (see §5) — only once the Alarm returns to idle.
— [iOS alarm reliability research](issues/06-ios-alarm-reliability-research.md)

## 3. Backend / infrastructure

- **Supabase** (Auth + Postgres + Storage + Edge Functions) — chosen over Firebase for being cheap/easy long-term (plain Postgres, no proprietary data model, no forced billing) over faster time-to-ship. Accepted tradeoff: push notifications must be hand-built (§7), since Supabase has no managed push service. — [Backend/storage/auth stack decision](issues/09-backend-storage-auth-stack-decision.md) (survey: [ticket 08](issues/08-backend-storage-auth-stack-survey.md))
- **Region: Ireland (`eu-west-1`)**, locked at project creation, immutable afterward without a full migration. — [GDPR technical policy decisions](issues/15-gdpr-technical-policy-decisions.md)
- **Deploy/CI**: GitHub Actions runs `supabase db push` (migrations) and `supabase functions deploy` (Edge Functions) on merge to `main`, gated by one manual GitHub Environments approval click — full automation minus a "did I mean to do that" pause.
- **Prod-only**, no staging Supabase project (not worth doubling migrations/secrets for a solo 4-week build). Local dev uses the Supabase CLI's local stack (`supabase start`) pre-merge.
- **Secrets**: CI-time secrets (service role key / project access token) live in GitHub encrypted repo secrets; runtime secrets the Edge Functions read (APNs `.p8` key/Key ID/Team ID, Sentry DSN) live in Supabase's own Edge Function secrets store, set via `supabase secrets set` from CI. Nothing sensitive is committed.
- **Scheduled cleanup job** (§6) runs via Supabase's native Scheduled Edge Functions — no `pg_cron`, no external scheduler.
- iOS app build/TestFlight distribution is a separate concern — see §11.
— [Deployment/CI pipeline](issues/21-deployment-ci-pipeline.md)

## 4. Data model

Postgres/Supabase DDL. `auth.users` is Supabase-managed identity; all other PKs are `gen_random_uuid()`.

```sql
create table profiles (
  user_id uuid primary key references auth.users(id),
  handle text not null unique,
  created_at timestamptz not null default now()
);

create table friend_connections (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references profiles(user_id),
  addressee_id uuid not null references profiles(user_id),
  status text not null check (status in ('pending','accepted','declined')) default 'pending',
  requested_at timestamptz not null default now(),
  responded_at timestamptz,
  check (requester_id <> addressee_id)
);
create unique index friend_connections_pair_idx
  on friend_connections (least(requester_id, addressee_id), greatest(requester_id, addressee_id));

create table alarms (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(user_id),
  label text,
  wake_time time not null,
  repeat_days smallint[] not null default '{}',
  mode text not null check (mode in ('auto_play','library_override')) default 'auto_play',
  library_override_alarm_call_id uuid references alarm_calls(id),
  snooze_enabled boolean not null default true,
  snooze_duration_minutes int not null default 9,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table alarm_calls (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(user_id),
  storage_path text not null,
  duration_seconds numeric not null,
  created_at timestamptz not null default now()
);

create table shares (
  id uuid primary key default gen_random_uuid(),
  alarm_call_id uuid not null references alarm_calls(id),
  friend_connection_id uuid not null references friend_connections(id),
  sender_id uuid not null references profiles(user_id),
  recipient_id uuid not null references profiles(user_id),
  storage_path text,
  created_at timestamptz not null default now(),
  uploaded_at timestamptz,
  downloaded_at timestamptz,
  expires_at timestamptz not null default (now() + interval '48 hours'),
  deleted_at timestamptz
);

create table queue_entries (
  id uuid primary key default gen_random_uuid(),
  alarm_id uuid not null references alarms(id),
  share_id uuid not null references shares(id),
  alarm_call_id uuid not null references alarm_calls(id),
  received_at timestamptz not null default now(),
  played_at timestamptz,
  unique (alarm_id, share_id)
);
create index queue_entries_fifo_idx on queue_entries (alarm_id, received_at) where played_at is null;

create table library_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(user_id),
  alarm_call_id uuid not null references alarm_calls(id),
  source text not null check (source in ('created','received')),
  added_at timestamptz not null default now(),
  unique (user_id, alarm_call_id)
);

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
-- invalidation: set invalidated_at = now() when APNs returns 410 Unregistered

create table consent_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(user_id),
  consent_type text not null,
  granted_at timestamptz,
  revoked_at timestamptz
);
```

**Server-enforced "locked" Queue** — RLS can't express "before that Alarm fires" (the DB doesn't know a device's local clock), so play/claim is gated by a `security definer` RPC instead of a table policy:

```sql
create function claim_queue_head(p_alarm_id uuid)
returns table (storage_path text, alarm_call_id uuid)
security definer as $$
  -- verify auth.uid() owns p_alarm_id
  -- if mode = 'library_override': return the override alarm_call's storage_path, no queue_entries mutation
  -- if mode = 'auto_play': select the oldest unplayed queue_entries row for p_alarm_id (FIFO head);
  --   if none, return empty (client falls back to the default tone, §6);
  --   else set played_at = now(), upsert library_entries(user_id, alarm_call_id, 'received'), return its storage_path
$$;
```

RLS on `queue_entries` permits the owner to `select` metadata (`id`, `received_at`, `played_at`) for counts/ordering; the client never reads an unplayed entry's `storage_path` directly, only via `claim_queue_head` (called when the Alarm actually fires). This gates the *play/claim* transition only — download/prefetch of a Share's audio is unrestricted from the moment it's queued (§5), so the clip is already local by fire time.

**Design decisions worth flagging:**
- **Shares fan out to every one of the recipient's current Alarms**, not one designated receiving Alarm — accepted double-play quirk, avoids building a "which Alarm receives Shares" settings surface. Alarms created after a Share was queued don't retroactively receive it. — [ADR-0002](../../docs/adr/0002-shares-fan-out-to-every-alarm.md)
- **Each Share gets its own Storage object** (`shares.storage_path`), server-copied from `alarm_calls.storage_path` at `createShare` time — never the same object, so one Share's expiry can never affect another Share of the same reused Alarm Call (§5).
- **Library is one unified table** across all of a user's Alarms, not siloed per-Alarm.
- **Friend Connection is a single asymmetric row**, not a pair of symmetric rows; normalized-pair unique index prevents duplicate/reverse requests.
- **Device tokens upsert-reassign** on reuse rather than erroring.

— [Data model schema](issues/10-data-model-schema.md)

## 5. Alarm sharing / transfer mechanism

- **Presigned URLs directly against Supabase Storage — no relay endpoint.** Both legs minted by Edge Functions so authorization and `shares` lifecycle bookkeeping stay server-side:
  - `createShare(alarmCallId, recipientId)` — validates ownership + accepted Friend Connection, inserts the `shares` row (`expires_at` = now + 48h), server-side copies bytes from `alarm_calls.storage_path` into a new per-Share object, writes that path to `shares.storage_path`. (The Alarm Call's own presigned *upload* happened once already, when it was first recorded — a Share never re-uploads.)
  - Completing the copy flips `shares.uploaded_at` — this Postgres write fires the Database Webhook that sends the "new Alarm Call received" push (§7).
  - `getShareDownloadUrl(shareId)` — validates caller is `shares.recipient_id` and not expired/deleted, mints a presigned download URL, stamps `downloaded_at` (enables early cleanup on confirmed download).
- **Download is layered and best-effort, decoupled from `claim_queue_head`**: attempted on push arrival, on every app foreground, and on any AlarmKit scheduling callback ahead of wake time — never gated to fire time.
- **Fire-time fallback**: if `claim_queue_head` is called and the head isn't yet local, the Alarm plays the default fallback tone (§6); the `queue_entries` row is **not** marked played, so it retries on the next fire, up to the Share's 48h expiry.
- **On 48h expiry with no download**: the scheduled cleanup job (§3, §8) deletes `shares.storage_path`, sets `deleted_at`, removes the orphaned `queue_entries` row(s), and sends a "Share expired without being downloaded" push to **both** sender and recipient. Sender can manually re-Share (fresh `createShare`); no auto-resend.
— [Alarm sharing/transfer mechanism](issues/11-alarm-sharing-transfer-mechanism.md)

## 6. Queue, playback, snooze & dismiss

- Users may have **multiple independent Alarms**, each with its own FIFO Queue and Auto-play/Library-override Mode. Receiving a new Alarm Call resets that Alarm to Auto-play. A played Alarm Call auto-saves to the Library. — [Received queue & playback mechanic](issues/03-received-queue-playback-mechanic.md)
- **Empty Queue + empty Library**: falls back to a bundled default alarm tone. — [Empty queue fallback sound](issues/04-empty-queue-fallback-sound.md)
- **Snooze replays the exact same Alarm Call on every re-ring** via AlarmKit's native snooze `AppIntent` — never advances or re-claims the Queue. No custom app-level reschedule (AlarmKit has no in-place update API; canceling a live alarm would abort an unacknowledged wake). Snooze duration/count are fixed/global for MVP, not per-Alarm.
- **Dismiss only stops playback and cancels any pending snooze** — no other side effects. `claim_queue_head`'s `played_at`/Library-save already happened once, at first tap-through for the Wake Event. Only once dismissed (or timed out) is it safe for the resync-on-mutation hook (§2) to act — it must never fire mid-ring/mid-snooze.
- A new Alarm Call arriving mid-Wake-Event never interrupts the active ring/snooze; it waits in the Queue.
— [Snooze/dismiss interaction mechanic](issues/20-snooze-dismiss-interaction-mechanic.md), [ADR-0003](../../docs/adr/0003-native-alarmkit-snooze.md)

## 7. Push notifications

- **Direct APNs via a Supabase Database Webhook → Edge Function** — no third-party vendor, no FCM. A Database Webhook fires on relevant inserts, invoking an Edge Function that signs an ES256 JWT with the app's `.p8` key and POSTs directly to Apple's APNs HTTP/2 endpoint.
- **Best-effort/fire-and-forget** — no retry/backoff. Justified because push here is only a teaser; AlarmKit firing locally is what actually wakes the user.
- **Two notification types**: (1) new Alarm Call received into a Queue; (2) Share expired without being downloaded, sent to both sender and recipient (§5).
— [Push notification implementation approach](issues/18-push-notification-implementation-approach.md)

## 8. Audio recording constraints

- **Codec**: AAC-HE, mono, 44.1kHz, `.m4a` container, via `AVAudioRecorder`. Chosen over Opus (no first-party iOS encoder) and AAC-LC (needs higher bitrate for comparable voice quality).
- **Max duration**: 30 seconds. **Bitrate**: 32 kbps (Apple's own HE-AAC speech guidance).
- **Worst-case size**: ~120 KB — trivial even on poor cellular.
— [Audio recording constraints](issues/13-audio-recording-constraints.md)

## 9. Friend discovery & onboarding

- **Mutual acceptance required** for any Friend Connection (Facebook-friend style) — both users must confirm before either can Share. — [Friend connection model](issues/01-friend-connection-model.md)
- Two discovery mechanisms: a personal, reusable **Invite Link** per user (supports invite-to-install) and **exact-handle-only search** (no directory/partial search, to prevent enumeration). Phone-contacts sync deferred to post-MVP. Tapping an Invite Link never auto-creates the connection — same explicit accept step either way. — [Friend discovery/onboarding mechanism](issues/16-friend-discovery-onboarding-mechanism.md)
- **Onboarding sequence**: account creation → invite/search screen ("Inline Minimal" layout: compact single column, Skip always available in the nav bar, Invite Link shown as a prominent inline row) → pending-request accept/decline (shown **only** if the user arrived via a resolved Invite Link — organic signups skip this step) → home.
— [Onboarding flow screens prototype](issues/19-onboarding-flow-screens-prototype.md)

## 10. Terminology reuse

- "Alarm" (the schedule) and "Alarm Call" (the recorded audio) are distinct terms; one Alarm Call is a reusable asset shareable to any number of friends and attachable to more than one of a recipient's own Alarms. — [Alarm vs Alarm Call terminology and reuse](issues/02-alarm-vs-alarm-call-terminology-and-reuse.md)
- "Alarm discovery" in the original brief means people-search, not content browsing (content discovery is a post-MVP monetization concern, out of scope). — [Scope clarification](issues/05-alarm-discovery-scope-clarification.md)

## 11. iOS app build & distribution

- **Xcode Cloud**, manually triggered (not per-merge) — kicked off only when there's something worth testers seeing.
- **External TestFlight testers** (not internal-only) — the core Share mechanic needs multiple real people testing together, and internal testing would mean adding casual testers to the paid Apple Developer team account. Accepted one-time Apple Beta App Review (~24–48h) before the first external build installs.
- **Code signing fully automatic**, managed entirely inside Xcode Cloud — nothing for the dev to store or rotate.
- **Versioning**: build number auto-incremented by Xcode Cloud; marketing version bumped manually.
— [iOS app build & TestFlight distribution](issues/22-ios-app-build-testflight-distribution.md)

## 12. GDPR / privacy / security

- **Deletion window: 48 hours** for a Share's temporary cloud copy — deleted on the earlier of confirmed recipient download or a 48h timeout. — [GDPR technical policy decisions](issues/15-gdpr-technical-policy-decisions.md) (research: [ticket 14](issues/14-gdpr-technical-requirements-research.md))
- **Encryption**: provider-managed AES-256 at rest (Supabase's blanket claim, both Postgres and Storage — no CMEK/BYOK for MVP); TLS floor guaranteed by iOS App Transport Security (1.2+ enforced by default).
- **Deletion mechanism**: scheduled Supabase Edge Function (§3) queries Postgres for expired/downloaded Shares and deletes via the Storage API — no native object TTL exists.
- **Consent capture**: account creation rests on contract necessity (ToS click at signup, not a consent gate); contacts access and microphone/recording each get explicit consent at the point of use (just-in-time for contacts, in-app acknowledgment alongside the OS mic prompt for recording), both logged in `consent_log`. No marketing-consent point yet (no marketing comms in MVP).
- Raw voice audio is **not** Art. 9 special-category data unless a future voice-ID feature is added.

## 13. Analytics & crash reporting

- **TelemetryDeck** for analytics (backend-independent, low integration friction, documented anonymization). **Sentry** for crash reporting (concretized once Supabase — a non-Firebase backend — was locked).
— [Analytics/crash reporting tool](issues/12-analytics-crash-reporting-tool.md)

## 14. Explicitly out of scope (this MVP)

- Post-MVP monetization: premium alarm packs, subscription tiers, challenge-based features, alarm analytics/insights, virtual gifts.
- Android (deferred to a future effort).
- Legal document drafting (ToS/privacy-policy text) — only the technical requirements are in scope here.
- Branding/visual design.
- Alarm-content discovery/browsing.
- Phone-contacts sync for friend-finding.
- Interactive/gamified dismiss interaction (a friend making the dismiss button harder to hit).

Two post-MVP product ideas were parked in memory during charting, not on this map: a paywalled Library-retention feature, and the gamified-dismiss idea above.

## Architecture Decision Records

- [ADR-0001](../../docs/adr/0001-minimum-ios-26.md) — Minimum supported iOS version: 26+, no fallback tier
- [ADR-0002](../../docs/adr/0002-shares-fan-out-to-every-alarm.md) — Shares fan out to every current Alarm
- [ADR-0003](../../docs/adr/0003-native-alarmkit-snooze.md) — Snooze via AlarmKit's native snooze, not a custom per-ring reschedule
