# Snooze re-presents the Wake Event via AlarmKit's native snooze, not a custom per-ring reschedule

AlarmKit's `AlarmConfiguration` bundles snooze in natively (schedule + sound + snooze + stop/snooze `AppIntent`s), and there is no in-place update API for a live alarm — changing one means cancel-and-reschedule, which would kill an alert the user hasn't yet acknowledged. We considered implementing snooze ourselves (stop the current alarm, schedule a new one N minutes later) so each snooze ring could re-evaluate the Queue head fresh, but rejected it: it reinvents reliability AlarmKit already provides for free and depends on the app getting an execution window to schedule the follow-up, the same class of fragility ticket 06 already ruled out the Alarmy-style keep-alive hack for.

**Decision**: snooze always uses AlarmKit's native snooze action. The system re-presents the exact same alert — same baked-in teaser sound, same already-`claim_queue_head`'d Alarm Call — on every re-ring of a Wake Event; the app never advances or re-claims the Queue mid-Wake-Event. A corollary: a new Alarm Call arriving mid-ring/mid-snooze must not touch the active AlarmKit alarm (canceling it would abort an unacknowledged wake); it waits in the Queue until the Alarm is idle again, and the "resync wake trigger on queue mutation" hook (ticket 06) is gated to only fire between Wake Events, not during one.

## Considered Options
- App-level custom snooze (stop + reschedule per ring), rejected as above.

## Consequences
- Snooze settings (duration, count) are fixed/global for the MVP, not stored per-alarm; per-Alarm configurability is a deferred post-MVP idea (see ticket 20).
- `claim_queue_head` fires exactly once per Wake Event, at the first tap-through into the app for that Wake Event (not necessarily its first ring) — subsequent taps within the same Wake Event only replay the already-resolved clip.
