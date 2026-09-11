Status: resolved
Type: grilling
Blocked by: 09, 10, 11, 15, 18

## Question

With the backend (ticket 09: Supabase), data model (ticket 10), Share transfer mechanism (ticket 11: `createShare`/`getShareDownloadUrl` Edge Functions), GDPR cleanup job (ticket 15: scheduled Edge Function), and push notifications (ticket 18: Database Webhook → Edge Function) all decided, specify the concrete deployment/CI shape for the MVP:

- How do Postgres migrations and Edge Functions get deployed — manual `supabase` CLI runs, or a CI pipeline (e.g. GitHub Actions) triggered on merge?
- Is there a staging Supabase project distinct from production, or is this solo 4-week build prod-only with local development against a linked project?
- Where do secrets live and get injected — the Supabase service role key, the APNs `.p8` key/Key ID/Team ID needed by ticket 18's Edge Function, any Sentry DSN (ticket 12)?
- Does ticket 15's scheduled cleanup job run via Supabase's own `pg_cron`/Scheduled Edge Functions, or an external scheduler?

## Answer

**Automated deploy on merge to `main`, gated by one manual approval.** A GitHub Actions workflow runs Postgres migrations (`supabase db push`) and deploys Edge Functions (`supabase functions deploy`) whenever code merges to `main`, using the Supabase CLI. Rather than firing straight through, the job sits behind a GitHub Environments manual-approval gate — one click before it's allowed to touch the live backend. This exists specifically to substitute for the safety net a staging environment would otherwise provide (see next point): full automation minus the "did I mean to do that" pause.

**Prod-only — no staging Supabase project.** A second hosted project would mean running every migration twice and duplicating every secret, which isn't worth it for a solo 4-week build. Local development uses the Supabase CLI's local stack (`supabase start`) for pre-merge testing; the manual-approval gate above is the compensating control for skipping a hosted staging tier.

**Secrets split by where they're needed.** CI-time secrets (the Supabase service role key / project access token the pipeline needs to authenticate and push migrations/functions) live in GitHub Actions' encrypted repo secrets. Runtime secrets the Edge Functions themselves read at execution time (ticket 18's APNs `.p8` key contents/Key ID/Team ID, ticket 12's Sentry DSN) live in Supabase's own Edge Function secrets store, set via `supabase secrets set` from the CI job. Nothing sensitive is ever committed to the repo.

**Ticket 15's cleanup job runs via Supabase's native Scheduled Edge Functions** — a cron-triggered Edge Function, not `pg_cron` and not an external scheduler. Same deploy path as every other function in this pipeline; no extra infrastructure to stand up or maintain for a single periodic job.

**iOS app build/TestFlight distribution is explicitly out of scope for this ticket** — this ticket only covers the Supabase backend's deploy/CI shape. Getting the SwiftUI app itself onto testers' devices (Xcode Cloud vs. manual archive+upload) is unresolved and carried forward on the map as a "Not yet specified" item.

No new domain vocabulary and no ADR — these are operational decisions (deploy mechanism, environment topology, secrets handling), not domain-model changes, and each is cheap enough to reverse later (add staging, drop the approval gate, swap the cron mechanism) that none of them clears the ADR bar.
