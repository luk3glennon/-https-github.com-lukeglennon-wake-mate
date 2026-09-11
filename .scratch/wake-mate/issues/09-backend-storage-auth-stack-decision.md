Status: resolved
Type: grilling
Blocked by: 08

## Question

Given the findings of ticket 08, lock the actual backend/storage/auth stack for the MVP prototype.

## Answer

**Supabase** (Auth + Postgres + Storage + Edge Functions) is locked as the backend/storage/auth stack for the MVP — a deliberate switch away from ticket 08's Firebase recommendation.

Ticket 08 recommended Firebase on speed-to-ship grounds. Put to the human, the priority was reframed: cheap and easy matter more than the 4-week timeline. Re-ranked on that basis:
- **Cheap**: Firebase, Supabase, and AWS Amplify are all ~$0/mo at this scale. Supabase's free tier pauses after a week of inactivity (a minor prototype-stage wrinkle, not a blocker) but needs no billing enablement at all, unlike Firebase, which requires enabling Blaze (card on file) immediately just to run the scheduled cleanup function.
- **Easy long-term**: Supabase is plain Postgres/SQL underneath — no proprietary data model to migrate off later, unlike Firestore/Firebase Auth's Google-proprietary formats.
- **Team context**: solo developer, no prior experience with GCP/Firebase, AWS, or Postgres either way — no experience tiebreaker in either direction.

Accepted tradeoff: Supabase has **no managed push notification service** — APNs must be hand-built (a Supabase Edge Function calling Apple's APNs HTTP/2 API directly, per ticket 08's findings). This was disqualifying under the original time pressure; with time pressure reduced, it's accepted as a one-time build cost. The concrete implementation approach is **not** decided here — see the new ticket it surfaces.

Also locked here as a build constraint (specifics deferred to ticket 15): the Supabase project's data region must be **explicitly chosen at project creation**, not left to a default, to keep EU user-data residency clean per ticket 14's GDPR findings.

Consequence for ticket 12 (already resolved): its conditional "Sentry if not Firebase" answer is now concretely **Sentry** for crash reporting.
