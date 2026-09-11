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

## TestFlight distribution (Xcode Cloud)

Real builds (the ones an external tester installs, as opposed to the
GitHub Actions job above that only proves "does it compile") go out via
Xcode Cloud, triggered **manually only** — never per-merge — since every
build consumes App Store Connect's Beta App Review queue. See
`.scratch/wake-mate/setup-wizard.sh` (stages 12+) for the one-time Apple
Developer / App Store Connect / Xcode Cloud setup walkthrough.

- `ios/ci_scripts/ci_post_clone.sh` runs first in every Xcode Cloud build:
  installs XcodeGen, writes `Secrets.xcconfig` from environment variables
  set in the workflow's App Store Connect settings (Xcode Cloud ->
  workflow -> Environment -> Environment Variables — mark each one
  Secret), runs `xcodegen generate`, then stamps the build number from
  Xcode Cloud's `CI_BUILD_NUMBER` via `agvtool` (needs
  `VERSIONING_SYSTEM: apple-generic` in `project.yml`, already set).
- The marketing version (`MARKETING_VERSION` in `project.yml`) is bumped
  by hand before each release — nothing automates that.
- Code signing is fully automatic (Xcode Cloud manages certificates and
  profiles itself once "Automatically manage signing" is enabled on the
  workflow) — there is nothing for a developer to store or rotate.

## Auth

Email + password via Supabase Auth (not Sign in with Apple) — chosen for
this foundation ticket because it needs zero Apple Developer entitlement
configuration to test end-to-end locally against `supabase start`. Revisit
if/when Sign in with Apple is wanted; nothing here blocks adding it later.
