Status: resolved
Type: research

## Question

Survey and pick an analytics + crash reporting tool for the iOS MVP (e.g. Firebase Analytics/Crashlytics, Sentry, TelemetryDeck). Consider cost, ease of integration, and any bundling advantage if it overlaps with the backend chosen in ticket 09. Low-stakes decision — research findings can include a direct recommendation.

## Answer

**Use TelemetryDeck for analytics in all cases, and Firebase Crashlytics for crash reporting if ticket 09 picks Firebase as the backend, or Sentry for crash reporting if ticket 09 picks a non-Firebase backend (Supabase, Amplify, or custom).**

Reasoning:
- TelemetryDeck is analytics-only (no native symbolicated crash reporting), so it always needs to be paired with a real crash reporter regardless of backend.
- TelemetryDeck is the right analytics choice independent of ticket 09: free up to 50,000 signals/month for new accounts (likely to cover Wake Mate's expected volume for a long while), lowest iOS integration friction of anything evaluated (SPM install, no extra console/cloud project needed), and its documented anonymization (on-device + server double-hashing, no cookies, no stored IPs) meaningfully reduces the compliance surface relevant to the still-open GDPR tickets (14/15) — worth flagging there, but not decided here.
- Crash reporting is conditional on ticket 09's backend choice: if Firebase, Crashlytics is free and already-present (shared SDK/project/console, unified user IDs with Firebase Auth) — no reason to add Sentry just for crashes. If the backend is not Firebase, adopting Firebase solely for Crashlytics means standing up an unrelated Google Cloud project for no other benefit, so Sentry is the better pick there: same crash-reporting quality, backend-agnostic, no separate console dependency, and its setup wizard is arguably less fiddly than Firebase's (no plist, no dSYM build-phase script). Sentry's free tier is capped at 1 seat, so a small team will likely need its $26/mo Team plan once more than one person needs console access — an acceptable cost for a low-stakes, reversible MVP decision.

This recommendation flips only on the crash-reporting half, based on ticket 09's outcome (Firebase backend to Crashlytics, any other backend to Sentry); the TelemetryDeck analytics choice is stable regardless.

Full findings and sourcing: `.scratch/wake-mate/research/12-analytics-crash-reporting-tool-findings.md`

**Concretized 2026-09-05:** ticket 09 locked Supabase as the backend, so crash reporting is **Sentry** (not Firebase Crashlytics).
