# 02: iOS TestFlight distribution

**What to build:** A real tester, off the dev's own machine, can install a build of the app via TestFlight.

**Blocked by:** 01 (Foundation: account creation + deploy pipeline)

- [ ] GitHub Actions release pipeline (`ios-release.yml`) configured, manual trigger only (not per-merge) — code-complete, **unverified**: needs the Apple Developer account below before it can actually run
- [x] Code signing fully automatic — nothing for the dev to store or rotate — Fastlane `match` creates the certificate/profile itself via the App Store Connect API (`ios/fastlane/Fastfile`, `ios/fastlane/Matchfile`); code-complete, unverified, no real Mac/Xcode step at any point
- [x] Build number auto-incremented by the pipeline; marketing version bumped manually — code-complete (`ios/fastlane/Fastfile`'s `beta` lane runs `agvtool new-version -all "$GITHUB_RUN_NUMBER"`, `VERSIONING_SYSTEM: apple-generic` already set in `ios/project.yml`); **unverified** — no real pipeline run has happened yet to exercise it
- [ ] TelemetryDeck app registered (**moved here from ticket 01 on 2026-09-12**) — TelemetryDeck's registration flow requires an App Store URL, which doesn't exist until the App Store Connect app record above is created; try registering once that record exists (unconfirmed whether the record alone is enough, or whether the app needs to be publicly live — find out when you get there)
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

**Apple Developer Program enrollment has not happened yet** — the account
doesn't exist, so this whole pipeline is code-complete but unverified. The
credentials it needs are wired as placeholder GitHub secrets until then:

- `APPLE_TEAM_ID`
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_CONTENT` (the `.p8` key, base64-encoded)
- `MATCH_PASSWORD` (a passphrase Fastlane invents to encrypt the
  certificate it stores)
- `WAKEMATE_BUNDLE_ID=com.wakemate.app` is already known (not secret, not
  blocked) and is now also pushed as a GitHub repository variable by the
  wizard — see `.scratch/wake-mate/setup-wizard.env` (gitignored)

Wizard stages 12-14 (`.scratch/wake-mate/setup-wizard.sh`) were rewritten
for this flow — stage 14 in particular now walks through generating the
App Store Connect API key and setting the above secrets, replacing the old
"open Xcode, create a Cloud workflow" steps entirely. Stage 17 (trigger the
first build) now points at GitHub's Actions tab instead of Xcode Cloud.
`ios/README.md`'s TestFlight section was rewritten to match.

Original pivot planning notes: the handoff doc this was planned from is
`C:\Users\luk3g\AppData\Local\Temp\wakemate-handoff-2026-09-12.md` (session-local
temp file, not part of the repo).

## Held / deferred (2026-09-12)

Everything in this ticket beyond the pipeline's code itself is gated on
Apple's own systems, which this session has no access to:

- **Apple Developer Program enrollment** was never confirmed as actually
  complete in ticket 01 (its Held section flagged this) — wizard stage 12
  (Team ID), stage 13 (App Store Connect app record), and stage 14 (API
  key + signing secrets) can't be run for real until it is.
  `WAKEMATE_BUNDLE_ID=com.wakemate.app` was captured in ticket 01's stage
  6, and happens to already match `ios/project.yml`'s
  `PRODUCT_BUNDLE_IDENTIFIER` — but that's not confirmation the bundle ID
  is actually registered with Apple, just that no reconciliation edit is
  needed *if/when* it is.
- **The release pipeline itself has never run** — it needs the stage
  12-14 secrets to exist before `ios-release.yml` can do anything but fail
  fast (the Fastfile's `require_env!` checks are deliberately loud about
  this rather than producing a broken build silently).
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
