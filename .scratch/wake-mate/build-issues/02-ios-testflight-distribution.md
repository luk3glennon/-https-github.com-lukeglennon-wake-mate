# 02: iOS TestFlight distribution

**What to build:** A real tester, off the dev's own machine, can install a build of the app via TestFlight.

**Blocked by:** 01 (Foundation: account creation + deploy pipeline)

- [x] GitHub Actions release pipeline (`ios-release.yml`) configured, manual trigger only (not per-merge) — **verified end-to-end 2026-09-12**: builds, signs, uploads, and the build reached App Store Connect (build `4`, `processingState: VALID`). Took six attempts to get there — see "First real runs" below
- [x] Code signing fully automatic — nothing for the dev to store or rotate — Fastlane `match` creates the certificate/profile itself via the App Store Connect API (`ios/fastlane/Fastfile`, `ios/fastlane/Matchfile`); **verified 2026-09-12** — `match` created the distribution certificate and App Store profile, stored them on the `certificates` branch, and a signed `.ipa` was produced, with no local Mac/Xcode step at any point
- [x] Build number auto-incremented by the pipeline; marketing version bumped manually — **verified 2026-09-12** (`agvtool new-version -all "$GITHUB_RUN_NUMBER"` in `ios/fastlane/Fastfile`'s `beta` lane ran in a successful archive)
- [x] TelemetryDeck app registered (**moved here from ticket 01 on 2026-09-12**) — resolved 2026-09-12: TelemetryDeck's app-creation form did ask for an App Store URL as feared, but it turned out not to be a hard blocker (exact workaround not captured, but the dev got past it) and the app was created; App ID `39F2D925-0E69-4C83-826A-5173D8FEA4A2` captured and pushed as the `TELEMETRYDECK_APP_ID` GitHub secret
- [x] External TestFlight tester group created (not internal-only) — **done 2026-09-12**: group "External Testers" (`isInternalGroup: false`), one tester added, currently `NOT_INVITED` (invites don't send until a build is attached). Created via the App Store Connect API, not the web UI — see "Finishing TestFlight setup" below
- [~] Apple Beta App Review **submitted 2026-09-12T09:57:05-07:00**, currently `betaReviewState: WAITING_FOR_REVIEW`. Build `4` is attached to the External Testers group; everything the review needs was already filled in (export compliance, Test Information, review contact, reviewer notes). Not yet passed — reopen this as failed if Apple rejects it, otherwise tick on approval. Note the tester stays `NOT_INVITED` until the review passes; Apple holds external invites behind approval, so `NOT_INVITED` here is expected, not a missed step
- [x] Internal tester group created and the account holder invited — **done 2026-09-12**: group "Internal Testers" (`isInternalGroup: true`, `hasAccessToAllBuilds: true`), tester `state: INVITED`, build `4` visible to the group. Internal testing is **not** gated on Beta App Review, so this is the route that works today — see "Internal testing group" below
- [ ] The dev installs and launches build `4` via the internal group — invite sent 2026-09-12, not yet confirmed. This is what unblocks ticket 01's Sentry / sign-up / `profiles`-row items
- [ ] At least one external tester successfully installs and launches the app via TestFlight — walkthrough written (wizard stage 18), not run; still waiting on Beta App Review

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

## Finishing TestFlight setup (2026-09-12)

**"External Testing" never appears in App Store Connect until the beta
paperwork is complete.** This looks exactly like a broken/ineligible
build and sends you hunting in the wrong direction — the popular advice
online is that the build was distributed with the wrong Xcode export
method, which cannot apply to this project at all (there is no Xcode, and
`build_app`'s `export_method` is already `app-store`).

What was actually missing, all four blank:

- export compliance unanswered on the build (`usesNonExemptEncryption: null`)
- no beta groups of any kind
- `betaAppReviewDetail` entirely empty (contact name/email/phone)
- no `betaAppLocalizations` (Test Information: feedback email + description)

All four were filled via the App Store Connect REST API rather than the
web UI. The credential is the same `AuthKey_<KEYID>.p8` the pipeline
already uses (`.scratch/wake-mate/`, gitignored), and the request just
needs an ES256 JWT — `openssl` can sign it, so no Ruby/Python is needed.
Signing gotcha: `openssl dgst -sign` emits a DER `SEQUENCE{r,s}`, which
has to be converted to raw `r||s` with each half zero-padded to 32 bytes
before base64url-encoding, or Apple rejects the token. Also pass `curl -g`,
since the API's `filter[...]` query params otherwise trip curl's globbing.

Useful identifiers (not secret):

- app id `6811360354`
- build `4` id `c5fcca18-a381-4c5a-9168-640595286677`
- beta group "External Testers" id `ad198acf-f704-4184-8d8f-1d805b14e780`

Two related facts worth keeping: the hosted Supabase project has
`mailer_autoconfirm` on (readable from `<SUPABASE_URL>/auth/v1/settings`,
which is unauthenticated), so sign-up needs no confirmation email and
Apple's reviewer can self-register — hence `demoAccountRequired: false`
and a reviewer note explaining it, rather than inventing credentials
(Apple actually tries them). Checking that also surfaced that the app has
no sign-in screen at all — written up as ticket 09.

## Internal testing group (2026-09-12, later session)

External testers are gated behind Beta App Review, which build `4` is still
waiting on. Internal testers are not — so an internal group was created to get
the app onto the dev's own device the same day and unblock ticket 01's three
"never run end-to-end" items.

- Group `Internal Testers` (`isInternalGroup: true`,
  `hasAccessToAllBuilds: true`), id `9d2575e9-93c3-4e74-8e01-40c2b1620eb0`.
  `hasAccessToAllBuilds` means builds are visible implicitly — there is no
  explicit build relationship to create, and `GET /v1/betaGroups/{id}/builds`
  confirms build `4` is visible to the group.
- Tester `luk3glennon@gmail.com` (the App Store Connect **account holder**),
  `state: INVITED`.

**The gotcha, which cost two failed calls:** internal beta groups only accept
testers whose email matches an App Store Connect **team member**. The tester
already sitting in the External Testers group uses a *different* address from
the account holder's, so both
`POST /v1/betaGroups/{internal}/relationships/betaTesters` (moving the existing
tester) and `POST /v1/betaTesters` (recreating it against the internal group)
fail with:

```
409 STATE_ERROR — "Tester(s) cannot be assigned"
```

The error names neither the email nor the reason. Creating the tester with the
account holder's own address against the same group succeeds first try. If this
recurs, compare `GET /v1/users` → `attributes.username` against the tester email
before assuming anything else is wrong.

The external group was left untouched — re-verified after the change that it
still has build `4` attached and `betaReviewState` is still
`WAITING_FOR_REVIEW`.

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
- ~~**The release pipeline itself has never run**~~ — **stale, resolved
  2026-09-12**: it has now run end-to-end six times, the last successfully,
  producing build `4`. Left struck through rather than deleted because this
  Held list is otherwise a record of what was true at pivot time.
- **TestFlight external group, Beta App Review submission, and the tester
  install confirmation** (stages 16-18) all chain off a real signed build
  existing — none of them can happen first. **Partly resolved 2026-09-12**:
  the group exists and the review is submitted (`WAITING_FOR_REVIEW`); only
  the install confirmation is still outstanding.
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
