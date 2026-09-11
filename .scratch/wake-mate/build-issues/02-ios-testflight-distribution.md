# 02: iOS TestFlight distribution

**What to build:** A real tester, off the dev's own machine, can install a build of the app via TestFlight.

**Blocked by:** 01 (Foundation: account creation + deploy pipeline)

- [ ] Xcode Cloud configured with manual trigger only (not per-merge) — walkthrough written (`.scratch/wake-mate/setup-wizard.sh` stage 14), **not run**: needs Xcode on a Mac, not doable from this session
- [ ] Code signing fully automatic inside Xcode Cloud — nothing for the dev to store or rotate — same wizard stage 14, same Mac blocker
- [x] Build number auto-incremented by Xcode Cloud; marketing version bumped manually — code-complete (`ios/ci_scripts/ci_post_clone.sh` runs `agvtool new-version -all "$CI_BUILD_NUMBER"`, `VERSIONING_SYSTEM: apple-generic` added in `ios/project.yml`); **unverified** — no real Xcode Cloud build has run yet to exercise it
- [ ] External TestFlight tester group created (not internal-only) — walkthrough written (wizard stage 16), not run: needs an App Store Connect app record, which needs stage 13 done first
- [ ] Apple Beta App Review submitted and passed for the first external build — walkthrough written (wizard stage 17), not run: needs a real build from stage 14
- [ ] At least one external tester successfully installs and launches the app via TestFlight — walkthrough written (wizard stage 18), not run

## Held / deferred (2026-09-11)

Everything in this ticket beyond the `ci_post_clone.sh` build-numbering
piece is gated on Apple's own systems, which this session has no access
to:

- **Apple Developer Program enrollment** was never confirmed as actually
  complete in ticket 01 (its Held section flagged this) — wizard stage 12
  (Team ID) and stage 13 (App Store Connect app record) can't be run
  until it is. `WAKEMATE_BUNDLE_ID=com.wakemate.app` was captured in
  ticket 01's stage 6, and happens to already match `ios/project.yml`'s
  `PRODUCT_BUNDLE_IDENTIFIER` — but that's not confirmation the bundle ID
  is actually registered with Apple, just that no reconciliation edit is
  needed *if/when* it is.
- **Xcode Cloud workflow creation** (stage 14) requires Xcode running
  locally against a cloned/generated project connected to source control —
  there's no App Store Connect-only path to *create* a new workflow (only
  to edit one that already exists). This needs the same one-time Mac
  session flagged in ticket 01's stage 11, extended to also do this stage.
- **TestFlight external group, Beta App Review submission, and the tester
  install confirmation** (stages 16-18) all chain off stage 14 producing a
  real signed build — none of them can happen first.
- What *is* done: `ios/ci_scripts/ci_post_clone.sh` (installs XcodeGen,
  writes `Secrets.xcconfig` from Xcode Cloud environment variables,
  generates the project, stamps the build number), `VERSIONING_SYSTEM:
  apple-generic` in `ios/project.yml`, and wizard stages 12-18 documenting
  the exact manual path through the rest.
- Also fixed, as a carryover from ticket 01 rather than new ticket 02 work
  (separate commit): `setup-wizard.sh` had silently picked up CRLF line
  endings, and its `ask`/`ask_secret` used plain `read` instead of `read
  -e` (no readline editing, so arrow-key/paste bytes landed as literal
  characters — the actual cause of the corrupted `Secrets.xcconfig` values
  flagged in ticket 01). Both are fixed and committed; the new
  `.gitattributes` (`*.sh text eol=lf`) keeps the line-ending fix from
  regressing for any shell script, including `ci_post_clone.sh` above,
  which actually does need to run cleanly on Xcode Cloud's macOS shell.
