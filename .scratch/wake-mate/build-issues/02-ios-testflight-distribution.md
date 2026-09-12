# 02: iOS TestFlight distribution

**What to build:** A real tester, off the dev's own machine, can install a build of the app via TestFlight.

**Blocked by:** 01 (Foundation: account creation + deploy pipeline)

- [ ] GitHub Actions release pipeline (`ios-release.yml`) configured, manual trigger only (not per-merge) — **builds and signs successfully as of 2026-09-12** (see "First real runs" below); the upload step has not yet succeeded, blocked on the app icon
- [x] Code signing fully automatic — nothing for the dev to store or rotate — Fastlane `match` creates the certificate/profile itself via the App Store Connect API (`ios/fastlane/Fastfile`, `ios/fastlane/Matchfile`); **verified 2026-09-12** — `match` created the distribution certificate and App Store profile, stored them on the `certificates` branch, and a signed `.ipa` was produced, with no local Mac/Xcode step at any point
- [x] Build number auto-incremented by the pipeline; marketing version bumped manually — **verified 2026-09-12** (`agvtool new-version -all "$GITHUB_RUN_NUMBER"` in `ios/fastlane/Fastfile`'s `beta` lane ran in a successful archive)
- [x] TelemetryDeck app registered (**moved here from ticket 01 on 2026-09-12**) — resolved 2026-09-12: TelemetryDeck's app-creation form did ask for an App Store URL as feared, but it turned out not to be a hard blocker (exact workaround not captured, but the dev got past it) and the app was created; App ID `39F2D925-0E69-4C83-826A-5173D8FEA4A2` captured and pushed as the `TELEMETRYDECK_APP_ID` GitHub secret
- [ ] External TestFlight tester group created (not internal-only) — walkthrough written (wizard stage 16), not run: needs an App Store Connect app record, which needs stage 13 done first
- [ ] Apple Beta App Review submitted and passed for the first external build — walkthrough written (wizard stage 17), not run: needs a real build from the pipeline
- [ ] At least one external tester successfully installs and launches the app via TestFlight — walkthrough written (wizard stage 18), not run

## Pipeline pivot (2026-09-12): Xcode Cloud replaced with GitHub Actions + Fastlane

The dev has no Mac or iPad and didn't want to rent or borrow one even for a
one-time setup session. Xcode Cloud (the original plan) is dropped in favor
of `.github/workflows/ios-release.yml`: manual-trigger-only, builds on
GitHub's cloud-hosted macOS runners, signs and uploads to TestFlight via
Fastlane (`ios/fastlane/Fastfile`, `Appfile`, `Matchfile`). No local
Mac/Xcode step at any point, including the one-time certificate creation —
Fastlane's `match` generates it via the App Store Connect API and stores it
(encrypted) in this repo's own `certificates` branch, so no second repo is
needed either. `ios/ci_scripts/ci_post_clone.sh` (Xcode Cloud's clone hook)
is removed — dead code once Xcode Cloud left the picture.

**Apple Developer Program enrollment completed 2026-09-12** (Team ID
`AS72RCKC5R`). The bundle ID had to change: `com.wakemate.app` was already
taken by another developer (bundle IDs are globally unique across all of
Apple, not just this account), so the project now uses
`com.wakemate.alarmcall` everywhere (`ios/project.yml`,
`ios/fastlane/Appfile`, `ios/fastlane/Matchfile`,
`.scratch/wake-mate/setup-wizard.env`).

`gh` (GitHub's command-line tool) isn't installed in this environment, so
the wizard's automatic `set_secret`/`set_var` push couldn't run — every
value below was set by hand instead, in the repo's Settings -> Secrets and
variables -> Actions, and is now real (not placeholder):

- `APPLE_TEAM_ID` = `AS72RCKC5R`
- `APP_STORE_CONNECT_API_KEY_ID` = `SLY64XR3SL`
- `APP_STORE_CONNECT_API_ISSUER_ID` = `0456db42-749a-45af-bea4-b1bef24d8f1b`
- `APP_STORE_CONNECT_API_KEY_CONTENT` (the `.p8` key, base64-encoded —
  Apple only allows downloading this key once; the original file is kept
  locally, gitignored via the new `*.p8` rule, never committed)
- `MATCH_PASSWORD` = a passphrase the dev invented, set
- `TELEMETRYDECK_APP_ID` = `39F2D925-0E69-4C83-826A-5173D8FEA4A2`
- `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SENTRY_DSN` — carried over from
  ticket 01, also now pushed as real secrets
- `WAKEMATE_BUNDLE_ID=com.wakemate.alarmcall` — pushed as a GitHub
  repository **variable** (not secret)

All required secrets/variables for `ios-release.yml` are now in place.
The repo's Settings -> Actions -> General -> Workflow permissions was also
set to "Read and write" (needed so `match` can push the `certificates`
branch it creates). The pipeline has not been triggered yet — that's the
next thing to do.

Wizard stages 12-14 (`.scratch/wake-mate/setup-wizard.sh`) were rewritten
for this flow — stage 14 in particular now walks through generating the
App Store Connect API key and setting the above secrets, replacing the old
"open Xcode, create a Cloud workflow" steps entirely. Stage 17 (trigger the
first build) now points at GitHub's Actions tab instead of Xcode Cloud.
`ios/README.md`'s TestFlight section was rewritten to match.

Original pivot planning notes: the handoff doc this was planned from is
`C:\Users\luk3g\AppData\Local\Temp\wakemate-handoff-2026-09-12.md` (session-local
temp file, not part of the repo).

## First real runs of the pipeline (2026-09-12)

The five failures it took to get from "never triggered" to a signed
`.ipa`, in order — recorded because several were non-obvious and would
otherwise be re-derived:

1. **The workflow wasn't visible in GitHub's Actions tab at all.** This
   repo's default branch is `master`, but all work was being pushed to
   `main`. GitHub only registers workflow files that exist on the default
   branch, so `ios-release.yml` was invisible to the Actions UI and API
   even though it was pushed. `origin/master` was a strict ancestor of
   `origin/main`, so it was fast-forwarded (`git push origin main:master`)
   and the workflow appeared immediately. **Every push from here on must
   go to both branches** until the default branch is changed — an earlier
   "green run" that was mistaken for success was in fact `ios-build.yml`
   (the compile/test-only workflow), which is easy to confuse with this
   one in the run list.
2. **`TELEMETRYDECK_APP_ID not set`** — the value had been set as a
   repository *variable* rather than a *secret* (separate tabs under
   Settings -> Secrets and variables -> Actions). Re-added as a secret.
3. **"Signing for 'WakeMate' requires a development team."** `project.yml`
   carries no code-signing settings, so xcodegen's generated project
   defaults to Xcode's automatic signing, which needs a signed-in Apple ID
   — there is none on a CI runner. Adding `update_code_signing_settings`
   alone did not fix it.
4. **"`<package>` does not support provisioning profiles."** The next
   attempt forced the signing settings via gym's `xcargs`, which passes
   them on the `xcodebuild` command line — where they apply to *every*
   target in the build, including the Swift Package dependencies
   (TelemetryDeck, swift-crypto), which reject a manually specified
   profile. Fixed by writing the signing settings into the generated
   `Secrets.xcconfig` instead: that file is the WakeMate target's
   `configFile`, so it reaches only that target. `match` now runs *before*
   the xcconfig is written, so its profile name can be interpolated in,
   and `update_code_signing_settings` is pinned to `targets: ["WakeMate"]`.
   With this the archive succeeded and a signed `.ipa` was produced.
5. **Upload rejected: "Missing required icon file" / "CFBundleIconName is
   missing".** The project had no asset catalog and no app icon of any
   kind. Added `ios/WakeMate/Assets.xcassets/AppIcon.appiconset` with a
   single 1024x1024 source image (Xcode derives the rest) plus
   `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` in `project.yml`. **The
   icon is a generated placeholder** (indigo gradient, white alarm clock)
   — it satisfies Apple's validator and is fine for TestFlight, but it
   should be replaced with a real design before any public release.

Also added along the way: `setup_ci` at the top of the `beta` lane. Without
it `match` imports the certificate into the runner's locked login keychain,
whose password it doesn't have, and logs "Could not configure imported
keychain item (certificate) to prevent UI permission popup" — harmless
until `codesign` needs the private key, at which point it hangs or fails.

One warning is still unexplained and was worked around rather than fixed:
`[Xcodeproj] Consistency issue: no parent for object 'Secrets.xcconfig'`,
emitted by the `xcodeproj` gem while gym inspects the generated project. It
has not caused an observed failure.

## Held / deferred (2026-09-12)

Everything in this ticket beyond the pipeline's code itself is gated on
Apple's own systems, which this session has no access to:

- **Apple Developer Program enrollment is now complete** (2026-09-12,
  Team ID `AS72RCKC5R`) — this was the thing ticket 01's Held section
  flagged as unconfirmed. Wizard stages 12-14 (Team ID, App Store Connect
  app record, API key + signing secrets) are all done — see the pivot
  section above for the full list of secrets now set. Stage 13 surfaced
  that `com.wakemate.app` — the bundle ID carried over from ticket 01's
  stage 6 — was already taken by another developer; the project has been
  reconciled onto `com.wakemate.alarmcall` instead.
- **The release pipeline itself has never run** — all the secrets
  `ios-release.yml` needs now exist, but nobody has clicked "Run workflow"
  yet (the Fastfile's `require_env!` checks would have failed fast and
  loud if anything were still missing, rather than producing a broken
  build silently — that path is now untested since everything's in place).
- **TestFlight external group, Beta App Review submission, and the tester
  install confirmation** (stages 16-18) all chain off a real signed build
  existing — none of them can happen first.
- What *is* done: `ios/fastlane/{Fastfile,Appfile,Matchfile}`,
  `.github/workflows/ios-release.yml`, `VERSIONING_SYSTEM: apple-generic`
  in `ios/project.yml` (carried over from the pre-pivot plan, still
  correct), and wizard stages 12-18 documenting the exact manual path
  through the rest.
- Carryover from ticket 01 (separate commit, predates this pivot):
  `setup-wizard.sh` had silently picked up CRLF line endings, and its
  `ask`/`ask_secret` used plain `read` instead of `read -e` (no readline
  editing, so arrow-key/paste bytes landed as literal characters — the
  actual cause of corrupted `Secrets.xcconfig` values flagged in ticket
  01). Both fixed and committed; `.gitattributes` (`*.sh text eol=lf`)
  keeps the line-ending fix from regressing for any shell script.
