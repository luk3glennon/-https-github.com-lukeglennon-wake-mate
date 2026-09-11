Status: research findings
Type: research
Relates to: 12-analytics-crash-reporting-tool.md (open), 09-backend-storage-auth-stack-decision.md (open, blocked by 08), 14/15-gdpr tickets (open)
Date: 2026-09-05

# Analytics + Crash Reporting Tool for Wake Mate iOS MVP

## Context recap

- Wake Mate is a pre-launch iOS-only MVP, small team, low volume expected for a long while (likely under a few thousand MAU/events/month).
- Ticket 09 (backend/storage/auth stack) is **still open** — candidates are Firebase, Supabase, AWS Amplify, or a custom Node/Postgres+S3 backend. Nothing is locked yet, so this decision should not assume Firebase.
- Tickets 14/15 (GDPR) are also open. 14 asks what personal data Wake Mate collects and what consent-capture points are required; 15 is the follow-up policy-lock ticket. Relevant here only insofar as an analytics tool that avoids collecting personal data can sidestep a whole category of consent-banner/DPA work — that's noted below but the actual GDPR architecture decision belongs to 14/15, not this ticket.

## 1. Firebase Analytics + Crashlytics

**Cost at small scale.** Both Analytics and Crashlytics are listed as no-cost products on the free **Spark** plan, with no numeric event/crash caps published (unlike e.g. Firestore, which lists explicit reads/day quotas) — the pricing page simply marks them "No-cost," and Spark explicitly requires no payment method ("No payment method needed") [Firebase Pricing](https://firebase.google.com/pricing). In practice this means Analytics and Crashlytics stay free indefinitely regardless of MAU — Google monetizes Firebase via the paid infrastructure products (Firestore, Functions, Hosting egress, BigQuery export beyond the sandbox), not via Analytics/Crashlytics usage. There is no seat limit for a small team either.

**Ease of iOS integration.** Setup requires:
1. A Firebase project in the console, with `GoogleService-Info.plist` added to the app and referenced in build settings.
2. Adding the SDK via Swift Package Manager: File → Add Packages → `https://github.com/firebase/firebase-ios-sdk.git`, selecting the Crashlytics (and Analytics) library, plus adding the `-ObjC` linker flag.
3. Calling `FirebaseApp.configure()` at launch.
4. For Crashlytics specifically, additional friction: setting **Debug Information Format** to `DWARF with dSYM File`, and adding a Run Script build phase (`.../Crashlytics/run`) to upload dSYMs/symbol data for crash symbolication.
[Firebase Crashlytics — Get started (iOS)](https://firebase.google.com/docs/crashlytics/ios/get-started)

This is a real but one-time setup cost (~15–30 min), and it is the same "add Firebase to your app" step whether or not Firebase is your data backend — but it unconditionally requires a Firebase project to exist, i.e. it pulls in a Google Cloud console footprint even if you use Firebase for nothing else.

**Bundling advantage with backend choice.** If ticket 09 selects Firebase as the backend (Firestore/Auth/Storage), Crashlytics + Analytics become essentially free to add: the Firebase project and SDK are already there, `FirebaseApp.configure()` is already called, and Firebase Auth UIDs flow naturally into Analytics user properties and Crashlytics user identifiers via the shared console. This is the strongest "bundling" case of any option evaluated. If ticket 09 selects a **non-Firebase** backend (Supabase, Amplify, custom Node/Postgres), adopting Firebase purely for Analytics/Crashlytics means standing up and maintaining a second cloud project/console with no other purpose — still free, but an extra account, an extra SDK, an extra dependency surface, and (per GDPR ticket 14/15) an extra vendor/subprocessor to track in a DPA — for a benefit (unified console) that only exists if you're also using Firebase elsewhere.

**Privacy/compliance simplicity.** Firebase Analytics collects device identifiers and (unless configured otherwise) advertising-related signals, and Google is a data processor under GDPR — Wake Mate would need a Firebase-specific Data Processing Amendment, IP anonymization/consent configuration, and likely a cookie/tracking consent flow depending on what's enabled. This is the same general GDPR posture as any Google product; it does not avoid consent-banner obligations the way a data-minimizing tool can. (Full GDPR requirements are ticket 14/15's job, not re-litigated here — but this is a meaningfully heavier compliance surface than TelemetryDeck's.)

## 2. Sentry

**Cost at small scale.** The free **Developer** plan includes: 5,000 error events/month (error and transaction/performance events share overlapping limits depending on product), 5M spans (tracing), 50 session replays, 5GB of logs, 10 custom dashboards, 30-day data retention, and is capped at **1 seat** ("Limited to one user") [Sentry Pricing](https://sentry.io/pricing/). For a small team of more than one person this 1-seat cap is the binding constraint before the event volume is. The next tier, **Team**, is $26/mo (billed annually) and raises this to 50,000 errors/month, unlimited seats, 90-day retention, and adds third-party integrations. For an MVP with a handful of testers/team members needing console access, Wake Mate would likely need Team ($26/mo) fairly quickly — not because of event volume (a few thousand crashes/month is nowhere near 5K–50K) but because of the 1-seat restriction on Developer.

**Ease of iOS integration.** Sentry has a mature, actively maintained Apple SDK with first-class SwiftUI support (dedicated `App` conformer initialization pattern) and a one-command setup wizard: `brew install getsentry/tools/sentry-wizard && sentry-wizard -i ios`, which patches the Xcode project, adds the SPM dependency, and configures dSYM/debug-symbol upload automatically [Sentry iOS docs](https://docs.sentry.io/platforms/apple/guides/ios/). No backend/server component is required — it's a pure SaaS; you just configure a DSN. This is arguably lower setup friction than Firebase because there's no separate "create a project in a console, add a plist, wire it into build settings before anything works" step beyond the wizard itself, and no dependency on any other Wake Mate infrastructure choice.

**Bundling advantage with backend choice.** None. Sentry is backend-agnostic by design — it doesn't care whether Wake Mate uses Firebase, Supabase, Amplify, or a custom Node backend. This makes it a safe choice to lock in now, independent of how ticket 09 resolves.

**Privacy/compliance simplicity.** Sentry error events can contain personal data (user context, device info, stack traces, breadcrumbs including user actions) unless explicitly scrubbed; Sentry offers PII-scrubbing controls and is GDPR/DPA-capable (Sentry is a well-known enterprise vendor with a standard DPA), but out of the box it does not avoid consent-banner-triggering data collection the way TelemetryDeck claims to. This is a normal, common vendor posture — no better or worse than Firebase here — not a differentiator.

## 3. TelemetryDeck

**What it is (and isn't).** TelemetryDeck markets itself as "privacy-focused analytics" and is **not a native crash reporter**. Its "Automatic Error Tracking" feature is signal-based, not stack-trace/symbolication-based: per its own feature page, "to track an error, you have to set up the TelemetryDeck SDK to send signals in a specific configuration" — i.e., the developer manually instruments error events (e.g. via a "Purchases"/"Errors" preset), and the dashboard aggregates and categorizes them. It does **not** automatically capture uncaught exceptions/native crashes with symbolicated stack traces the way Crashlytics or Sentry do. So the premise in the task brief is confirmed: TelemetryDeck is an analytics tool, not a crash-reporting replacement, and would need to be paired with something else (Crashlytics or Sentry) for actual crash diagnostics.

**Cost at small scale.** Free tier ("Sparrow"): **100,000 signals/month** for accounts created before July 1, 2026; for **new** accounts (which Wake Mate would be) the free tier was lowered to **50,000 signals/month** as part of TelemetryDeck's first price increase since April 2023 [TelemetryDeck — Pricing Update July 2026](https://telemetrydeck.com/blog/pricing-update-2026/). Paid tiers (per third-party pricing summaries corroborating the same July 2026 update, since the live pricing calculator at dashboard.telemetrydeck.com/plans is a JS app that doesn't expose plain-text pricing to static fetch): an Individual tier around **$8/mo for up to 500,000 signals/month** (1-year retention) and a Team tier around **$49/mo for up to 5,000,000 signals/month** (2-year retention). At Wake Mate's expected scale (a few thousand MAU, presumably well under 50,000 analytics events/month for an alarm/social app with modest per-session event counts), the free 50,000/month tier is very likely sufficient for a long while.

**Ease of iOS integration.** SPM installation: File → Add Package Dependencies → `https://github.com/TelemetryDeck/SwiftSDK`. Initialization is a few lines in the `App` struct:
```swift
import TelemetryDeck
let config = TelemetryDeck.Config(appID: "YOUR-APP-ID")
TelemetryDeck.initialize(config: config)
```
[TelemetryDeck Swift Setup Guide](https://telemetrydeck.com/docs/guides/swift-setup/). No backend/server component and no third-party console/project (Google, AWS, etc.) is required beyond a TelemetryDeck account — this is the lowest-friction, most self-contained setup of the three.

**Bundling advantage with backend choice.** None either way — like Sentry, it's backend-agnostic, so it doesn't change regardless of what ticket 09 decides.

**Privacy/compliance.** This is TelemetryDeck's headline differentiator, and the specific technical claims (verified against their own docs, not marketing copy) are:
- **No cookies**: "TelemetryDeck does not use cookies" [Privacy FAQ](https://telemetrydeck.com/docs/guides/privacy-faq/).
- **No IP storage**: "IP addresses are never stored on the TelemetryDeck server, neither in the database nor in log files or anywhere else" (for web SDK requests only the first three octets are inspected transiently to estimate country, then discarded) [Privacy FAQ](https://telemetrydeck.com/docs/guides/privacy-faq/).
- **Double-hashed identifiers**: user/device identifiers are salted and hashed **on-device** first, then TelemetryDeck's server adds its own salt and hashes again — so neither the developer nor TelemetryDeck can reconstruct the original identifier, and re-identification is described as ruled out because the "identification date" needed to reverse the hash is not retained [Anonymization: how it works](https://telemetrydeck.com/docs/articles/anonymization-how-it-works/).
- **Their own legal conclusion**: because (per their claim) the data is truly anonymized rather than merely pseudonymized, "anonymized data is not personal data anymore," and therefore "there is no need to request consent" and no cookie/consent banner is legally required for using TelemetryDeck specifically [Privacy FAQ](https://telemetrydeck.com/docs/guides/privacy-faq/).

Caveat for Wake Mate's own GDPR ticket (14/15): this is TelemetryDeck's self-assessment of its own product, not independent legal confirmation for Wake Mate's specific data flows — worth a one-line flag to whoever resolves ticket 15, but not something to re-derive here. The practical takeaway for *this* ticket is narrower and safely statable: TelemetryDeck is architected to not collect IP addresses, cookies, or reversible identifiers, which is a meaningfully lighter compliance footprint than Firebase Analytics or Sentry, both of which collect richer, potentially re-identifiable data by default.

## Other contenders briefly considered

- **PostHog** — genuinely a strong analytics contender: free tier is generous (1M analytics events/month, 100K "exceptions"/error-tracking events/month, resets monthly, no credit card until you opt into pay-as-you-go) [PostHog Pricing](https://posthog.com/pricing). Has a maintained iOS SDK with SPM support and SwiftUI setup (`posthog-ios`, tracked at v3.59.3 at time of writing) [PostHog iOS docs](https://posthog.com/docs/libraries/ios). However its error tracking is not confirmed to be native-crash/dSYM-symbolicated crash reporting either (docs describe event tracking, session replay, feature flags, experiments — not confirmed automatic uncaught-exception capture), and PostHog is a heavier, more "growth analytics platform" tool (funnels, session replay, feature flags, A/B testing) than Wake Mate's MVP needs. It's worth naming as a TelemetryDeck alternative if the team later wants funnels/session-replay/experimentation, but it doesn't solve crash reporting either and adds more surface area than needed right now.
- **Bugsnag / Instabug** — not investigated in depth; both are credible crash-reporting alternatives to Crashlytics/Sentry but neither offers a clear cost or integration advantage over Sentry at this scale, and introducing them would just be a third vendor to evaluate without a specific reason pulling Wake Mate toward them. Not recommended for further investigation unless Sentry's 1-seat free-tier limit or its pricing becomes a real problem.

## Evaluation summary

| Criterion | Firebase (Analytics+Crashlytics) | Sentry | TelemetryDeck |
|---|---|---|---|
| Free tier at MVP scale | Unlimited, free, no seat cap | 5K errors/mo, **1 seat only** — likely needs $26/mo Team plan for a multi-person team | 50K signals/mo free (new accounts) — likely sufficient |
| Crash reporting? | Yes, native, symbolicated | Yes, native, symbolicated | No — signal-based error logging only |
| Analytics? | Yes | Limited (not its purpose) | Yes, purpose-built |
| iOS setup friction | Console + plist + SPM + dSYM build phase | SPM/wizard, no separate console dependency | SPM, no separate console dependency |
| Requires unrelated cloud project? | Yes (Firebase project) | No | No |
| Bundling win if backend = Firebase | Large (shared console/SDK/user IDs) | None | None |
| Bundling cost if backend ≠ Firebase | Extra vendor/console for no other purpose | N/A (backend-agnostic anyway) | N/A (backend-agnostic anyway) |
| GDPR/consent posture | Standard Google processor terms; likely needs consent flow | Standard SaaS processor terms; needs PII scrubbing review | Claims no personal data collected; no consent banner needed per own docs |

## Recommendation

**Use Firebase Crashlytics for crash reporting + TelemetryDeck for analytics, *unless* ticket 09 picks a non-Firebase backend, in which case use Sentry for crash reporting + TelemetryDeck for analytics.**

Justification:
- Crash reporting needs native, symbolicated stack traces — TelemetryDeck explicitly doesn't provide that, so it must be paired with a real crash reporter regardless of the analytics choice.
- TelemetryDeck is the right analytics tool independent of the backend decision: it's free at Wake Mate's expected scale (50K signals/month free tier, likely to cover a few-thousand-MAU app for a long time), has the lowest integration friction of everything evaluated (no extra console/project needed beyond a TelemetryDeck account), and its documented anonymization approach (on-device + server double-hashing, no cookies, no stored IPs) meaningfully reduces the compliance surface that tickets 14/15 will otherwise have to account for — worth flagging to whoever locks 15, but not a decision this ticket needs to make.
- For crash reporting specifically, the right choice is conditional on ticket 09: if Firebase ends up as the backend, Crashlytics is free, already-present (shared SDK/project/console, unified user IDs with Firebase Auth), and there's no reason to add a second vendor (Sentry) purely for crashes. If the backend is Supabase, Amplify, or custom Node/Postgres, adopting Firebase *solely* for Crashlytics means standing up an unrelated Google Cloud project for no other benefit — at that point Sentry is the better pick: same crash-reporting quality, zero coupling to backend choice, no separate console to maintain, and setup is arguably *less* fiddly than Firebase's (no plist, no dSYM Run Script build phase — the Sentry wizard automates it). The only friction with Sentry is its free tier's 1-seat cap, which will likely force a $26/mo Team plan once more than one person needs console access — a small, acceptable cost for a "low-stakes, reversible" MVP decision.

**This recommendation flips only on the crash-reporting half**, and only based on ticket 09's outcome: Firebase backend → Crashlytics; any other backend → Sentry. The analytics half (TelemetryDeck) is stable regardless of what ticket 09 decides.
