# 02: iOS TestFlight distribution

**What to build:** A real tester, off the dev's own machine, can install a build of the app via TestFlight.

**Blocked by:** 01 (Foundation: account creation + deploy pipeline)

- [ ] Xcode Cloud configured with manual trigger only (not per-merge)
- [ ] Code signing fully automatic inside Xcode Cloud — nothing for the dev to store or rotate
- [ ] Build number auto-incremented by Xcode Cloud; marketing version bumped manually
- [ ] External TestFlight tester group created (not internal-only)
- [ ] Apple Beta App Review submitted and passed for the first external build
- [ ] At least one external tester successfully installs and launches the app via TestFlight
