Status: resolved
Type: grilling
Blocked by: 09

## Question

Given ticket 09 locked Supabase (no managed push notification service), decide how push notifications get implemented: a Supabase Edge Function calling Apple's APNs HTTP/2 API directly (own `.p8` key, own retry/backoff, own device-token bookkeeping), versus bringing in a separate third-party push-only service (e.g. OneSignal, Pusher Beams) alongside Supabase to avoid hand-rolling APNs plumbing. Weigh build effort, ongoing cost, and how much this matters given push here is only a teaser alert (per ticket 06, the full Alarm Call plays in-app on launch via AlarmKit — the push/APNs path is not the reliability-critical wake mechanism itself).

## Answer

**Direct APNs via a Supabase Edge Function** is locked — no third-party push vendor, no Firebase Cloud Messaging.

A Supabase Database Webhook (pg_net-based) fires on INSERT of a new received Alarm Call into a recipient's Queue, invoking an Edge Function that signs an ES256 JWT with the app's `.p8` key and POSTs directly to Apple's APNs HTTP/2 endpoint via Deno's native `fetch()`. This trigger mechanism is a confirmed fact (not a tradeoff between options) — full research and citations: [`research/18-push-notification-implementation-approach-findings.md`](../research/18-push-notification-implementation-approach-findings.md).

Two alternatives were weighed and rejected:
- **A dedicated push vendor** (OneSignal, Courier, Novu — Pusher Beams looks stale/uninvested-in despite still being sold): rejected to avoid a second vendor account/bill, consistent with ticket 09's "cheap/easy, no extra lock-in" stance. A vendor's real advantages (multi-type templates, segmentation dashboards) don't pay off for a single notification type. OneSignal's own "Supabase integration" is the same Database Webhook → Edge Function → REST pattern being hand-built here anyway.
- **FCM used only for push** (not full Firebase adoption) — this is what Supabase's own official push guide actually recommends, since Deno's edge runtime has no mature APNs library (`node-apn`/`apns2` don't run there); direct APNs means hand-rolling the ES256 JWT and raw HTTP/2 POST rather than using a maintained SDK. Rejected anyway: it reintroduces Firebase, which ticket 09 deliberately moved away from, even though it's a real build-effort saving.

Reliability bar: **best-effort, fire-and-forget** — no retry/backoff, no dead-letter tracking. Justified by ticket 06: this push is a teaser only; the actual wake-up depends on AlarmKit firing locally, not on the push arriving.

Scope: this ticket covers **one notification type only** — "new Alarm Call received into a Queue." Any other notification type (e.g. a friend-request alert) is a fresh question, not assumed in scope here.

Deferred, not decided here: device-token storage and multi-device lifecycle belongs to ticket 10's schema (a device-tokens table/column set must exist there for the Edge Function to look up recipients).

**Addendum (ticket 11 session):** a second notification type is now in scope — "Share expired without being downloaded," sent to both the sender and the recipient. Same mechanism (Database Webhook → Edge Function → direct APNs), triggered by ticket 15's scheduled cleanup job marking a `shares` row expired-undownloaded, rather than by a new-Share insert. Still best-effort/fire-and-forget, no retry.
