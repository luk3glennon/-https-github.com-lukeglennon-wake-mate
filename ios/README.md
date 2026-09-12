# iOS app

Native SwiftUI, iOS 26+ only (see [ADR-0001](../docs/adr/0001-minimum-ios-26.md)).

## Why this isn't a checked-in `.xcodeproj`

This repo was scaffolded from a Windows machine with no Xcode/Swift
toolchain, and Xcode only runs on macOS — that's an Apple platform
restriction, not something to work around. So:

- `project.yml` (an [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec)
  is the source of truth for the project structure, targets, and
  dependencies. It's plain text and diffs cleanly.
- The generated `WakeMate.xcodeproj` and `WakeMate/Info.plist` are
  **gitignored** — regenerate them any time with `xcodegen generate`.
- `.github/workflows/ios-build.yml` builds and tests this project on
  GitHub's macOS cloud runners on every push, so "does it compile" is
  answered by CI without anyone needing to own or rent a Mac.

## First time setup (needs a Mac, even a rented/borrowed one, once)

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
2. `cp Secrets.xcconfig.example Secrets.xcconfig` and fill in real values
   (Supabase project URL/anon key, Sentry DSN, TelemetryDeck app ID — see
   the setup wizard).
3. `cd ios && xcodegen generate`
4. Open `WakeMate.xcodeproj` and run on an iOS 26+ simulator.

## TestFlight distribution (GitHub Actions + Fastlane)

Real builds (the ones an external tester installs, as opposed to the
`ios-build.yml` job above that only proves "does it compile") go out via
`.github/workflows/ios-release.yml`, triggered **manually only** (GitHub's
"Run workflow" button) — never per-merge — since every build consumes App
Store Connect's Beta App Review queue.

This runs entirely on GitHub's macOS cloud runners, with **no local
Mac/Xcode step at any point** — including the one-time certificate
creation, which was the last thing the original Xcode Cloud plan would
have needed a Mac for. See `.scratch/wake-mate/setup-wizard.sh` (stages
12-14) for the one-time Apple Developer / App Store Connect API key setup
walkthrough.

- `ios/fastlane/Fastfile`'s `beta` lane runs the whole pipeline: writes
  `Secrets.xcconfig` from GitHub Actions secrets, `xcodegen generate`,
  stamps the build number via `agvtool` using GitHub's own run number
  (needs `VERSIONING_SYSTEM: apple-generic` in `project.yml`, already
  set), authenticates to the App Store Connect API, then builds, signs,
  and uploads.
- Code signing is handled by Fastlane **match**: it creates the
  distribution certificate and provisioning profile itself via the App
  Store Connect API (no Xcode GUI, no human clicking through Apple's
  signing UI), and stores them — encrypted with a passphrase only this
  project's secrets know — in a `certificates` branch of this same repo,
  so later runs reuse them instead of creating a fresh certificate every
  time. See `ios/fastlane/Matchfile`.
- The marketing version (`MARKETING_VERSION` in `project.yml`) is bumped
  by hand before each release — nothing automates that.
- Required GitHub repository secrets (set by the wizard once the Apple
  Developer account exists): `APPLE_TEAM_ID`, `APP_STORE_CONNECT_API_KEY_ID`,
  `APP_STORE_CONNECT_API_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_CONTENT`
  (the App Store Connect API `.p8` key, base64-encoded), `MATCH_PASSWORD`
  (a passphrase Fastlane invents/uses to encrypt the certificate it
  stores), plus the existing `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
  `SENTRY_DSN`, `TELEMETRYDECK_APP_ID` secrets, the `SENTRY_AUTH_TOKEN`
  secret (see below), and the `WAKEMATE_BUNDLE_ID`, `SENTRY_ORG`,
  `SENTRY_PROJECT` repository variables. The repo's Settings -> Actions -> General ->
  Workflow permissions must be set to "Read and write" so match can push
  the `certificates` branch.

- **Sentry symbol (dSYM) upload.** The `beta` lane uploads debug symbols
  to Sentry via `sentry-cli` before it uploads the build to TestFlight,
  because a release build is stripped and optimised and its crashes are
  unreadable without them. This needs `SENTRY_AUTH_TOKEN` (a Sentry
  **auth token** with `project:releases` scope — the DSN is write-only and
  cannot upload symbols) plus `SENTRY_ORG` and `SENTRY_PROJECT` slugs.
  The step is allowed to fail the whole lane on purpose: shipping a build
  whose crash reports are undiagnosable is the failure it exists to
  prevent, and the release trigger is manual so a retry is one click.
  Confirmed values (not secrets — hence repository *variables*):
  `SENTRY_ORG=luk3glennon`, `SENTRY_PROJECT=wakemate-ios`, on Sentry's
  EU region (`de.sentry.io`).
  **`SENTRY_PROJECT` must name the project the DSN actually points at.**
  This org has three projects and the iOS one was auto-named `apple` by
  Sentry's onboarding (renamed to `wakemate-ios` on 2026-09-12); the two
  WakeMate-named projects were empty, one of them reserved for the backend
  DSN in ticket 12. Uploading symbols to the wrong project leaves crashes
  just as unreadable while appearing to succeed. Verify by matching the
  project's Settings -> Client Keys DSN against the trailing project id in
  `SENTRY_DSN` (`4512068537090128`); a project's slug can be renamed
  freely without breaking the DSN, which addresses the project by that
  numeric id, not by name.
  Beware a false positive here — `WakeMateApp.swift`'s
  `SentrySDK.capture(message:)` smoke test appears in Sentry regardless,
  since a message carries no stack trace to symbolicate.

## Auth

Email + password via Supabase Auth (not Sign in with Apple) — chosen for
this foundation ticket because it needs zero Apple Developer entitlement
configuration to test end-to-end locally against `supabase start`. Revisit
if/when Sign in with Apple is wanted; nothing here blocks adding it later.
