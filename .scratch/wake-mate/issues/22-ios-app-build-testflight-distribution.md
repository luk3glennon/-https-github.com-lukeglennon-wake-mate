Status: resolved
Type: grilling
Blocked by: 07, 21
Assigned: lglennon@nucleo.ie

## Question

With the client framework (ticket 07: native SwiftUI) and the backend deploy/CI shape (ticket 21: GitHub Actions, manual-approval gated) both decided, specify how the iOS app itself gets built and onto testers'/reviewers' devices for the MVP:

- Build path: Xcode Cloud, or a manual local archive + upload to App Store Connect?
- What triggers a new build — every merge to `main` (mirroring ticket 21's backend pipeline), or a manual cut when the solo dev decides one's ready?
- TestFlight setup: internal-only testing group, or external testers too (and if external, the added App Store review wait for the first external build)?
- Code signing: automatic signing managed by Xcode, or manually managed provisioning profiles/certificates — and where do the signing certificate and any App Store Connect API key live (mirroring ticket 21's secrets-split question, now for the client side)?
- Versioning: how are build number/marketing version bumped — manually per build, or automated by whatever builds it?

## Answer

**Xcode Cloud.** Apple's own automated build service, free within a solo dev's build cadence (25 compute-hours/month included on a paid Apple Developer Program membership). Mirrors ticket 21's pattern for the backend (automated pipeline over a manual, repeatable chore) and, as a side effect, resolves signing and versioning almost for free (see below).

**Manual trigger, not per-merge.** Every commit doesn't need a fresh TestFlight build, and auto-building on every merge to `main` would burn through the free compute allowance on builds nobody's waiting on. The dev manually kicks off the Xcode Cloud workflow (or pushes a release tag) only when there's something worth testers seeing.

**External TestFlight testers.** Wake Mate's core mechanic (Sharing an Alarm Call to a friend) requires multiple real people testing together — internal testing alone can't exercise it. Internal testers would also mean adding casual friend-testers directly into the paid Apple Developer team account, which is disproportionate. External testers join via a plain TestFlight link with no account entanglement. Accepted tradeoff: the first external build needs a one-time Apple Beta App Review (typically 24–48h, occasionally longer) before anyone can install it; later builds don't re-incur this.

**Code signing: fully automatic, managed entirely inside Xcode Cloud.** Access is granted once via a role in App Store Connect; from then on Xcode Cloud creates and manages the signing certificate for every build itself. Unlike ticket 21's backend secrets (split between GitHub and Supabase because no single automated system held them), there's nothing here for the dev to store, rotate, or leak — it never leaves Apple's infrastructure.

**Versioning is split.** Build number (the internal counter) auto-increments via Xcode Cloud on every build. Marketing version (the human-facing release number) stays a manual decision, since it's meant to signal something to testers/reviewers rather than tick up mechanically.

No new domain vocabulary and no ADR — same reasoning as ticket 21: purely operational (build mechanism, release trigger, signing management), doesn't touch any term in `CONTEXT.md`, and every part is cheap to reverse later (swap Xcode Cloud for manual archiving, flip the trigger, add internal testers) with nothing surprising enough to warrant a paper trail.
