# Build progress

Terse running log, one entry per finished build issue. This is the file to
read when starting a new ticket — not the older ticket files themselves,
which carry full detail (decisions, bugs, on-device notes) and are only
worth opening if this summary or the current ticket points at one by name.

- **01 — Foundation: account creation + deploy pipeline.** CLOSED
  2026-09-12. Sign-up, Supabase backend (`eu-west-1`), GitHub Actions
  deploy pipeline, and Sentry crash reporting all verified on-device. Open:
  local dev via `supabase start` never exercised; Sentry symbol upload is
  proven by CI but not yet by a real crash.
- **02 — iOS TestFlight distribution.** CLOSED 2026-09-12. Signed builds
  ship via GitHub Actions + Fastlane with no Mac/Xcode needed; internal
  TestFlight install verified on a real device. Open: no *external* tester
  has installed yet — blocked on Apple's Beta App Review, nobody is
  watching for that outcome.
- **03 — Returning-user sign-in, friend discovery & connection** (absorbed
  the originally-separate ticket 09, sign-in). CLOSED 2026-09-13. Sign-in,
  exact-handle search, and invite-code friend connections verified
  end-to-end on-device, both directions. Open: password reset not built;
  the "invite link" is actually a pasted code, not a tappable link (needs a
  real domain to become one).
- **04 — Alarm scheduling core (AlarmKit).** CLOSED 2026-09-14. Create/
  edit/delete Alarms; firing confirmed on-device through force-quit and
  silent/Focus mode; snooze and dismiss confirmed on-device. Nothing open.
- **05 — Alarm Call recording & Library.** CLOSED 2026-09-14 (checklist
  updated 2026-09-26 — it had been left unchecked despite shipping). Record
  a short clip, save it to the Library, and set an Alarm to play it
  directly; consent logging and the mode-reset safety net both verified.
  Nothing open.
- **05 follow-up — fix: clip-titling/delete migrations never applied.**
  CLOSED 2026-09-26. User saw an empty Library, couldn't title a clip, and
  a recorded clip wouldn't show up on alarm creation — all traced (via a
  newly-connected read-only Supabase database link) to two migrations that
  were written but never actually run against the live database. Ran them,
  verified in the database, confirmed fixed on-device. No app code change,
  no new TestFlight build needed.

- **06 — Share sending & Queue population.** CLOSED 2026-09-26. Sharing a
  Library clip fans it out to every one of the recipient's current Alarms
  (new `shares`/`queue_entries`/`device_tokens` tables), a Queue-count badge
  shows on each Alarm, and a hand-rolled `pg_net` webhook sends a direct
  APNs push on upload. Not yet verified on-device (no local Xcode; needs a
  CI build). Open: an actual push notification needs the one-time Apple
  Developer Portal "Push Notifications" capability step, same as the
  TestFlight signing setup in tickets 01/02 — the code is ready and waiting.

## How to add an entry

When a ticket closes, append a bullet here in the same style: ticket number
+ name, close date, what shipped in one sentence, an "Open:" clause only if
something real is still outstanding. Keep it to 3-5 lines. The full
decisions/bugs/testing log stays in the ticket file itself — this file
never replaces that, it just means nobody has to re-read it to know what's
already built.
