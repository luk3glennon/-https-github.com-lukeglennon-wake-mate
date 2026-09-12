# 01: Foundation: account creation + deploy pipeline

**What to build:** A user can install the app, accept the ToS, sign up, and land on a home stub backed by a real account — with the infrastructure to keep shipping safely behind it. This ticket also carries the small cross-cutting infra pieces (CI/CD, crash/analytics wiring) that every later slice depends on, since none of them is large enough to warrant its own ticket.

**Blocked by:** None (can start immediately)

**CLOSED 2026-09-12** by the dev. The ticket's purpose is met: a user can
install the app, accept the ToS, sign up, and land on a home stub backed by a
real account, and the infrastructure behind it ships safely. Verified on a
real device, not inferred.

Two boxes below are still unticked, and are left that way on purpose rather
than tidied away — closing a ticket is a decision about priority, not a claim
that everything in it happened:

- **Local dev via `supabase start`** — never attempted, not once. It buys
  offline/iterative backend work; the project has managed without it so far by
  working against the hosted project. Reopen if backend work gets heavy enough
  that pushing to hosted per change starts to hurt.
- **dSYM item, part (c)** — crash symbolication proven by a real crash. Parts
  (a) and (b) are done and a green release run carried the upload, so the
  machinery is in place and defended by hard failures; what is missing is the
  single observation that closes the loop. Per the decision recorded below,
  this waits on a genuine crash rather than a deliberate one. **If crashes
  ever come back as raw addresses, start here** — the answer is in this item.


- [x] Supabase project created, region locked to `eu-west-1` (captured via wizard: project ref, URL, anon key, DB password all present in `.scratch/wake-mate/setup-wizard.env`)
- [x] `profiles` table (`user_id`, `handle`, `created_at`) with Supabase Auth wired up (`supabase/migrations/20260911141557_initial_schema.sql` — RLS + `handle_new_user()` trigger on `auth.users` insert)
- [x] GitHub Actions pipeline runs `supabase db push` and `supabase functions deploy` on merge to `main`, gated by one manual GitHub Environments approval (`.github/workflows/deploy-backend.yml` targets the `production` environment) — **verified 2026-09-12**: the "Deploy backend" workflow has 4 runs, the last of which (2026-09-11T18:16:38Z) concluded `success`
- [x] CI-time secrets in GitHub encrypted repo secrets; runtime secrets (APNs `.p8`/Key ID/Team ID, Sentry DSN) set in Supabase Edge Function secrets via `supabase secrets set` from CI — **verified 2026-09-12** for the CI-time secrets (`SUPABASE_ACCESS_TOKEN`/`SUPABASE_PROJECT_ID`/`SUPABASE_DB_PASSWORD`): the green Deploy backend run above could not have pushed migrations or deployed functions without all three being set correctly. Runtime APNs secrets deliberately blank (ticket 18)
- [ ] Local dev works end-to-end via `supabase start` — not exercised this session
- [x] iOS app target created with iOS 26 as the hard deployment minimum, no fallback tier (`ios/project.yml` — `deploymentTarget: "26.0"` on app + test targets)
- [x] Sentry crash reporting wired in and firing at least one real event — **verified 2026-09-12** by the dev: the `SentrySDK.capture(message: "WakeMate launched")` smoke test in `WakeMateApp.swift:17` appears in the Sentry project's Issues list, sent from the real signed build `4` on a physical iPhone. This proves the DSN is valid and events reach Sentry from a shipped build — note it does **not** prove an actual crash is captured or readable; see the symbol-upload item below
- [ ] Sentry dSYM (debug symbol) upload from CI — **(a) and (b) done 2026-09-12; (c) still open**. Found missing while ticking the Sentry item above: nothing in `.github/workflows/` or `ios/fastlane/` referenced dSYMs or `sentry-cli`, so a real crash in a TestFlight build would have reported as raw addresses. The smoke-test message carries no stack trace, which is exactly why it looked healthy anyway. Now implemented:
  - `ios/project.yml` sets `DEBUG_INFORMATION_FORMAT: dwarf-with-dsym` on the Release config explicitly. This was **not** previously inherited — Xcode's *project template* sets it, but xcodegen generates the project from scratch and the build system's default for an unset value is plain `dwarf`, i.e. no `.dSYM` bundles produced at all.
  - `ios/fastlane/Fastfile`'s `beta` lane uploads the archive's `dSYMs/` directory (preferred over `DSYM_OUTPUT_PATH`, since it also covers the Swift Package dependencies) via `sentry-cli debug-files upload`, placed **before** `upload_to_testflight` and allowed to fail the lane — shipping an undiagnosable build is the failure being prevented, and the trigger is manual so a retry is one click.
  - `.github/workflows/ios-release.yml` installs `sentry-cli` and passes `SENTRY_AUTH_TOKEN` / `SENTRY_ORG` / `SENTRY_PROJECT`.

  **Sentry coordinates confirmed 2026-09-12:** org `luk3glennon`, project `wakemate-ios` (EU region, `de.sentry.io`). The iOS project had been auto-named `apple` by Sentry's onboarding and was the *only* one of the org's three projects receiving events — the two WakeMate-named ones were empty (one is reserved for ticket 12's backend DSN). Verified by matching that project's Client Keys DSN to the trailing project id in `SENTRY_DSN` (`4512068537090128`) before renaming it to `wakemate-ios`; the rename is safe because a DSN addresses a project by numeric id, not slug. Had `SENTRY_PROJECT` been pointed at a WakeMate-named project instead, the upload would have succeeded and crashes would have stayed unreadable.

  **Outstanding before this can be ticked:** (a) the three new CI settings must be created — `SENTRY_AUTH_TOKEN` needs a Sentry auth token with `project:releases` scope, since the DSN is write-only and cannot upload symbols; (b) one release run must go green with the upload step in it; (c) a crash from a TestFlight build appearing in Sentry with readable file-and-line — the only thing that actually proves symbolication end-to-end. Do not tick on (a) and (b) alone.

  **Progress 2026-09-12 (evening):** (a) and (b) are now done. The three CI
  settings were created and release run #6 went green with the dSYM upload step
  in it, producing build `6` (uploaded 18:04 UTC, `PROCESSING` at time of
  writing). That run is stronger evidence than "the job passed": the lane
  hard-fails with `UI.user_error!` if `build_app` yields no dSYMs, and
  `sentry-cli debug-files upload` runs through `sh` so a non-zero exit aborts
  the lane — so a green run means symbols were both produced and accepted by
  Sentry. **(c) remains open** and is the only thing that proves symbolication
  end-to-end; per the decision below, it waits on a genuine crash.

  The failure that preceded it was worth the detour: the first attempt stopped
  in `require_env!` naming a single empty variable, which is true but not
  actionable — GitHub keeps repository *secrets* and repository *variables* on
  two tabs of the same settings page and `${{ vars.X }}` does not fall back to
  `${{ secrets.X }}`. `preflight_env!` (commit `05780b4`) now validates the
  whole `REQUIRED_ENV` set before any work happens and prints every missing
  name with the tab it belongs on, plus the ones that did arrive.
  **Decision 2026-09-12:** a temporary in-app "test crash" button (`SentrySDK.crash()`) was offered and **declined** — the dev chose to wait for a real crash rather than ship a deliberate one. So (c) will be satisfied opportunistically, by the first genuine crash, rather than on demand. Recorded because the alternative reading — that nobody thought to check — is exactly the assumption that hid the missing dSYM upload in the first place. If this item is still open when the tester group grows, revisit: the cost of finding out symbolication is broken at that point is a wasted crash report from a real user.
- [x] ~~TelemetryDeck analytics~~ — **moved to ticket 02** and **resolved there 2026-09-12** (App ID captured and set as a GitHub secret); nothing outstanding under this ticket
- [x] Sign-up flow: account creation, ToS click captured (contract-necessity basis, not a consent gate), lands on a home stub — **verified end-to-end 2026-09-12** on a real iPhone, build `4` via the internal TestFlight group. `auth.users` has exactly one row; email present and `email_confirmed_at` set (`mailer_autoconfirm` working as designed); `last_sign_in_at` populated, so the session was established rather than just the account created. ToS capture verified specifically: `raw_user_meta_data ->> 'tos_accepted_at'` is `2026-09-12T17:21:11Z` while the row's `created_at` is `17:21:13.41`, so the value came from the **client's claim**, not `handle_new_user()`'s `coalesce(..., now())` fallback — i.e. the real ToS click timestamp was captured and round-tripped, which a `now()` fallback would have silently faked
- [x] A `profiles` row exists for the signed-up user — **verified 2026-09-12** by querying the hosted project (Supabase Management API `POST /v1/projects/{ref}/database/query`). The row was created by the `handle_new_user()` trigger with no client involvement, `handle` auto-generated as `user_1c538ad31e2f` (matches ticket 16's `^[a-z0-9_]{3,20}$` format), `tos_accepted_at` correct. Note `profiles` holds no email column by design — the email lives on `auth.users`, which is where it was checked
- [ ] ~~Sign-in for a returning user~~ — **split out 2026-09-12, now in ticket 03** (briefly its own ticket 09, since merged): never in this ticket's scope, but its absence means signing out is a one-way door, so it's tracked rather than lost

## Held / deferred (2026-09-11)

Items the wizard walked through but that were deliberately or unavoidably left incomplete:

- **Apple Developer account & App ID** — ~~not created this session~~ **resolved 2026-09-12 under ticket 02**: the paid account exists (Team ID `AS72RCKC5R`), and the placeholder `com.wakemate.app` turned out to be taken by another developer, so everything is now on `com.wakemate.alarmcall`. No longer blocks TestFlight; ticket 18's push work can assume a real Team ID.
- **TelemetryDeck — moved to ticket 02 and closed out there (2026-09-12).** Registration did turn out to work off the App Store Connect app record alone, with no public App Store URL needed; the App ID is now a GitHub secret and ships in every signed build. Nothing outstanding. Original note, kept for the bug write-up underneath it: the dev tried registering an app in TelemetryDeck and found it demands an App Store URL, which doesn't exist yet — that URL only shows up once an App Store Connect app record has been created, which is a ticket 02 step (Team ID + app record, wizard stages 12-13), not a ticket 01 one. Re-attempt TelemetryDeck registration once that app record exists; it's possible the record alone is enough without the app being publicly live, but that's unconfirmed — try it at that point rather than waiting for public launch.
  **Bug found and fixed along the way:** `ios/Secrets.xcconfig`'s `TELEMETRYDECK_APP_ID` had a stray wizard stage-banner string in it, and `SUPABASE_URL` in the same file had ~200 bytes of literal cursor-movement escape sequences (`[D`/`[C`/...) tacked onto the end. Root cause: `ask`/`ask_secret` in `setup-wizard.sh` used plain `read -r`, which doesn't do readline editing — an arrow-key press (or a paste containing cursor-movement bytes) got inserted as literal characters instead of moving the cursor. Fixed in `setup-wizard.sh`: `ask`/`ask_secret` now use `read -e` (readline editing handles arrow keys properly) plus a `_strip_control` backstop that strips any escape/control bytes that still get through; the TelemetryDeck stage also now validates the input looks like a UUID (or is explicitly skipped) before writing it anywhere. The corrupted values already sitting in the local (gitignored, uncommitted) `ios/Secrets.xcconfig` were repaired directly — `SUPABASE_URL` restored to the real value from `setup-wizard.env`, `TELEMETRYDECK_APP_ID` reset to the example placeholder since no real App ID was ever captured.
- **APNs secrets** (`APNS_AUTH_KEY_BASE64`, `APNS_KEY_ID`, `APNS_TEAM_ID`) — left blank in GitHub Actions secrets by design; scoped to ticket 18. Pipeline tolerates the empty values.
- **`SENTRY_DSN_EDGE`** (backend Edge Functions crash reporting, separate from the client DSN) — left blank by design; scoped to ticket 12.
- **GitHub CLI (`gh`)** — not installed on this machine, so every GitHub-side step (repo secrets, the `production` environment + required reviewer, confirming Actions runs went green) was walked manually through the web UI by the user rather than validated programmatically from this session. Worth a manual double-check that the `production` environment actually exists with a required reviewer before the first real merge to `main` triggers a backend deploy.
- **Repo remote is misnamed** — `git remote -v` shows `origin` pointing at `https://github.com/luk3glennon/-https-github.com-lukeglennon-wake-mate.git` (an auto-generated slug from a pasted URL, not a clean repo name). Rename the GitHub repo to `wake-mate` via Settings → General, then update the local remote to `https://github.com/luk3glennon/wake-mate.git`.
- **End-to-end verification** (sign-up flow actually running, `profiles` row appearing, Sentry firing a real event) is still outstanding, but is no longer blocked on anything — **as of 2026-09-12 the route described below actually exists**: ticket 02's pipeline is green end-to-end and build `4` is sitting in TestFlight as `VALID`. Installing it on an iPhone and tapping through sign-up is all that's left to close these three items. Original reasoning, now confirmed rather than hypothetical: a real build is produced by GitHub's cloud runners and installed straight onto the dev's own iPhone via TestFlight — no Mac, no simulator, and no Beta App Review needed (that review only gates *external* testers, not the account owner testing their own build). A Mac/simulator session remains a fallback if that route is preferred, but is no longer the only option. **Update, later on 2026-09-12:** the route is now actually set up, not just theoretically available — an internal TestFlight group (`Internal Testers`) exists with the account holder invited (`state: INVITED`) and build `4` visible to it. The invite email has gone out; nothing further is needed from Apple. See `.scratch/wake-mate/build-issues/02-ios-testflight-distribution.md`.
