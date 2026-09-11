Status: resolved
Type: grilling
Blocked by: 14

## Question

Given the findings of ticket 14, lock the concrete technical policies: exact deletion window for the temporary cloud copy, specific encryption approach, and where/how consent is captured in the product.

## Answer

Supabase fact-check backing this answer: [15-supabase-eu-hosting-encryption-ttl-findings.md](../research/15-supabase-eu-hosting-encryption-ttl-findings.md).

**Deletion window: 48 hours** (revised from the originally locked 24 hours during ticket 11's session, reverting to ticket 14's original recommendation — the stricter 24-hour posture wasn't worth the extra undelivered-Share/resend friction it created). The temporary cloud copy of a shared Alarm Call is deleted on the earlier of (a) confirmed recipient-device download or (b) a fixed 48-hour timeout.

**Encryption:**
- At rest: provider-managed AES-256 (Supabase's single blanket claim, covering both Postgres and Storage — no split, no CMEK/BYOK option). No additional column-level encryption (e.g. pgcrypto/Vault) for MVP; provider defaults are sufficient per ticket 14's Art. 32 analysis.
- In transit: Supabase's own docs state no explicit minimum TLS version. The floor is instead guaranteed by iOS's App Transport Security, which enforces TLS 1.2+ by default on every network connection the app makes — a more defensible citation than an unsourced "Supabase does 1.2+" claim.

**EU region: Ireland (`eu-west-1`).** Locked at Supabase project creation per ticket 09's constraint; immutable afterward without a full data migration. Chosen over Frankfurt for developer/user proximity — both are EU member states, so no GDPR/adequacy trade-off either way (unlike London/Zurich, which are GDPR-adequate third countries, not EU member states).

**Deletion mechanism:** no native Storage object TTL exists on Supabase, and raw SQL deletes against `storage.objects` orphan the underlying files. Implemented as a scheduled (cron-triggered) Supabase Edge Function that queries Postgres for expired/downloaded temporary copies and deletes them via the Storage API.

**Consent capture, by moment:**
- Account creation (contract necessity, Art. 6(1)(b)) — a ToS/Privacy Policy acceptance click at signup, framed as acknowledgment, not a consent gate.
- Contacts/address-book access (Art. 6(1)(a)) — asked just-in-time, when the user opens friend-discovery, not upfront during onboarding.
- Microphone/recording (Art. 6(1)(a)) — an in-app acknowledgment alongside the OS mic-permission prompt.
- Marketing comms — none in MVP; the separate-opt-in consent point is deferred until marketing comms exist as a feature.
- Contacts and mic consent are each additionally recorded in an explicit `consent_log` (user_id, consent_type, granted_at, revoked_at), rather than relying on iOS's permission state alone as evidence of consent.

**New requirements surfaced for ticket 10** (data model schema, still open): a `consent_log` table, and `uploaded_at`/`downloaded_at`/`expires_at` tracking columns on whatever holds the temporary cloud copy, to support the deletion job above. Noted on ticket 10 directly.

**Explicitly redirected, not decided here:** download-timing (background prefetch vs. on-open) and arrival-notification design belong to tickets 11 and 18. A paywall-on-Library-retention idea raised during this session is monetization/subscription-tier work, out of scope for this map's MVP-architecture destination — parked outside the tracker, not actioned.

**Addendum (ticket 11 session):** deletion window revised from 24h to 48h — see above. Ticket 10's `shares.expires_at` default and ticket 11's transfer-mechanism design both use 48h.
