# Wake Mate

Social alarm app — record a custom "alarm call" and send it to a friend to
use as their actual alarm. See `Brief.txt` for the product pitch,
`CONTEXT.md` for settled domain vocabulary, and `.scratch/wake-mate/map.md`
for the full architecture decision log.

## Repo layout

- `supabase/` — Postgres migrations, Edge Functions, local dev config
  (Supabase Auth + Postgres + Storage + Edge Functions backend).
- `ios/` — native SwiftUI app (iOS 26+ only). See `ios/README.md` — the
  `.xcodeproj` is generated from `ios/project.yml`, not committed.
- `.github/workflows/` — CI: backend deploy-on-merge (manual-approval
  gated) and iOS build verification on GitHub's macOS runners.
- `docs/adr/` — architecture decision records.
- `.scratch/wake-mate/` — the planning trail (map, tickets, research) this
  build was specced from.

## Local backend dev

Requires [Docker](https://www.docker.com/) and the
[Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started)
(or use `npx supabase <command>`, no install needed).

```sh
npx supabase start   # spins up local Postgres/Auth/Storage/Studio
npx supabase db reset  # applies all migrations from scratch
```

Studio (dashboard) runs at http://127.0.0.1:54323 once started — use it to
confirm a `profiles` row was created after signing up through the app.

## First-time project setup

Creating the actual Supabase project, Apple Developer app record, Sentry
project, TelemetryDeck app, and GitHub repo secrets all require dashboard
logins this assistant doesn't have. Run the setup wizard for a guided,
step-by-step walkthrough: `.scratch/wake-mate/setup-wizard.sh`.
