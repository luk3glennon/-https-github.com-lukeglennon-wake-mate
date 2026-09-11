# 01: Foundation: account creation + deploy pipeline

**What to build:** A user can install the app, accept the ToS, sign up, and land on a home stub backed by a real account — with the infrastructure to keep shipping safely behind it. This ticket also carries the small cross-cutting infra pieces (CI/CD, crash/analytics wiring) that every later slice depends on, since none of them is large enough to warrant its own ticket.

**Blocked by:** None (can start immediately)

- [ ] Supabase project created, region locked to `eu-west-1`
- [ ] `profiles` table (`user_id`, `handle`, `created_at`) with Supabase Auth wired up
- [ ] GitHub Actions pipeline runs `supabase db push` and `supabase functions deploy` on merge to `main`, gated by one manual GitHub Environments approval
- [ ] CI-time secrets in GitHub encrypted repo secrets; runtime secrets (APNs `.p8`/Key ID/Team ID, Sentry DSN) set in Supabase Edge Function secrets via `supabase secrets set` from CI
- [ ] Local dev works end-to-end via `supabase start`
- [ ] iOS app target created with iOS 26 as the hard deployment minimum, no fallback tier
- [ ] Sentry crash reporting and TelemetryDeck analytics both wired in and firing at least one real event
- [ ] Sign-up flow: account creation, ToS click captured (contract-necessity basis, not a consent gate), lands on a home stub
- [ ] A `profiles` row exists for the signed-up user, visible via Supabase dashboard or a debug query
