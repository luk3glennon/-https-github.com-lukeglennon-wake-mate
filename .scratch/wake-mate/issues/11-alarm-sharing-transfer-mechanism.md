Status: resolved
Type: grilling
Blocked by: 09

## Question

Given the chosen backend/storage stack (ticket 09), decide the concrete Share transfer mechanism: presigned upload/download URLs vs a relay endpoint, the expiration window for the temporary cloud copy, and failure/retry handling if the recipient doesn't download before it expires.

## Notes

Ticket 10 (data model schema, resolved) locked the temporary-cloud-copy tracking columns (`uploaded_at`/`downloaded_at`/`expires_at`) directly on the `shares` row, and the expiration window was already locked at 24 hours (ticket 15) when this ticket opened — this ticket owns presigned-vs-relay and retry/failure handling, not the expiry number itself. (That window was revised to 48h during this session — see Answer.)

Also carries a constraint from ticket 10's Q6: the recipient's download/prefetch of a Share's audio must stay unrestricted from the moment it's queued (not gated behind Alarm-fire time) — required so the clip is already local before AlarmKit fires (ticket 06's offline-reliability need). Whatever mechanism this ticket picks, it must not introduce a fire-time-gated download step; only the *playback/claim* transition is server-gated (ticket 10's `claim_queue_head`), not the transfer itself.

## Answer

**Presigned URLs directly against Supabase Storage, no relay endpoint.** Both upload and download legs are minted by Edge Functions rather than raw client + Storage-RLS, so authorization and the `shares` row's lifecycle bookkeeping stay in one server-side code path:

- `createShare(alarmCallId, recipientId)` — validates the sender owns the Alarm Call and has an accepted Friend Connection with the recipient; inserts the `shares` row (`expires_at` = now + 48h); **server-side copies** the bytes from `alarm_calls.storage_path` into a new per-Share object and writes that path to `shares.storage_path`. No client-side presigned *upload* is involved on the Share leg at all — the client already uploaded the Alarm Call once, via its own presigned upload URL, when it was first recorded (that's `alarm_calls.storage_path`'s creation, outside this ticket's scope); a Share only ever needs a server-side copy of bytes the client sent once. The "upload URL" half of this ticket's original question therefore resolves to: presigned upload is used exactly once per Alarm Call, not once per Share — see Q7 below for why.
- Once the copy completes, the Edge Function flips `shares.uploaded_at` to now — this Postgres write is what fires ticket 18's existing Database Webhook, sending the recipient the "new Alarm Call received" push.
- `getShareDownloadUrl(shareId)` — validates the caller is `shares.recipient_id` and `expires_at`/`deleted_at` haven't passed; mints a presigned **download** URL against `shares.storage_path`; stamps `downloaded_at` (this is what lets ticket 15's cleanup job delete early on confirmed download).

A relay was rejected: nothing on this map needs to inspect the bytes in flight (format/size are already fixed client-side by ticket 13), and a relay reintroduces the always-on-compute cost profile tickets 08/09 picked Supabase to avoid, for no security or functional gain over Storage's own signed URLs.

**Per-Share object, not a shared/reused one (Q7).** Each Share gets its own Storage object (`shares.storage_path`), server-copied from the sender's permanent `alarm_calls.storage_path` at `createShare` time. `alarm_calls.storage_path` itself is never touched by ticket 15's cleanup job — only the per-Share copies are — so a reused Alarm Call (CONTEXT.md: "Shared to any number of friends independently") can be re-shared indefinitely without re-upload, while each individual Share still gets an independent, correctly-scoped TTL and deletion. Costs one extra server-side copy per Share (cheap at ticket 13's ~120KB worst case) but keeps ticket 15's per-row `expires_at` scan correct with no cross-Share existence checks, and means a leaked/expired Share's URL can never expose bytes for a different, still-active Share of the same Alarm Call.

**Download timing: layered, not gated to Alarm-fire time.** Consistent with ticket 10 Q6's constraint, the recipient's device may call `getShareDownloadUrl` as soon as the Share lands in its Queue. To avoid depending on any single trigger (ticket 18's push is explicitly best-effort/no-retry): attempt the download on push arrival, retry on every app foreground, and retry on any AlarmKit scheduling callback ahead of the wake time. This is fully decoupled from ticket 10's `claim_queue_head` RPC, which gates only the *play/claim* transition at Alarm-fire time (FIFO order, `played_at`) — a Share's audio can finish downloading well before `claim_queue_head` is ever called, and `claim_queue_head` never blocks on download state.

**Fire-time fallback if the download hasn't finished.** If `claim_queue_head` is called and the head Alarm Call isn't yet local, the Alarm plays ticket 04's default fallback tone. The `queue_entries` row is **not** marked played — it stays at the head, the client keeps retrying the download in the background, and the next fire gets another shot at the real content, up until the Share's 48h expiry.

**Failure/retry on expiry.** If a Share's 48h window elapses with no `downloaded_at`, the scheduled cleanup Edge Function (ticket 15) deletes `shares.storage_path`, sets `deleted_at`, and removes the corresponding `queue_entries` row(s) (the object no longer exists to serve). It also triggers a second push notification type (addendum to ticket 18) — "Share expired without being downloaded" — sent to **both** the sender and the recipient via the same Database-Webhook → Edge Function → APNs mechanism. The sender sees a manual "Share again" action, reusing the same `alarm_call_id` (a fresh `createShare` call); there is no automatic resend.

**Ripples into other tickets** (applied in this session): ticket 15's deletion window revised 24h → 48h; ticket 18 gains a second notification type; ticket 10's `shares` table gains a `storage_path` column and its `expires_at` default changes to 48h.
