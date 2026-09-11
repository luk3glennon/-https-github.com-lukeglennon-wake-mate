Status: resolved
Type: grilling
Assignee: lglennon

## Question

Given the received-queue/playback mechanic (ticket 03) and the data model (ticket 10), decide the snooze/dismiss interaction for a fired Alarm: does snooze replay the same Alarm Call on each subsequent ring, or re-evaluate/advance the Queue head each time it re-fires? Does dismiss have any effect beyond stopping playback — e.g. does it change anything ticket 10's `claim_queue_head`/`played_at`/Library-save behavior already assumed happens once, at first claim?

## Answer

**Snooze replays the exact same Alarm Call on every re-ring — it never advances or re-claims the Queue.** Snooze is implemented via AlarmKit's native snooze `AppIntent`, not a custom app-level reschedule: `AlarmConfiguration` bundles snooze in natively, and the system daemon can re-present the same alert (same baked-in teaser sound) without any app code running. This was chosen over a custom "stop + reschedule a new AlarmKit alarm per ring" approach because AlarmKit has no in-place update API — canceling a live alarm to change it would kill an alert the user hasn't yet acknowledged — and a custom approach would depend on the app getting an execution window to schedule each follow-up ring, the same class of fragility ticket 06 already ruled out the Alarmy-style keep-alive hack for. See [ADR-0003](../../../docs/adr/0003-native-alarmkit-snooze.md) and the new **Wake Event** term in CONTEXT.md (the span from first ring through final dismiss/timeout, including every snooze re-ring, across which the claimed Alarm Call is fixed).

This applies uniformly regardless of what's playing — the default WakeMate fallback tone (ticket 04) or a friend's recorded Alarm Call — since it's the same already-`claim_queue_head`'d clip either way.

**Snooze settings (duration, count) are fixed/global for the MVP**, not stored per-Alarm or user-configurable. Per-Alarm configurability (custom duration/max-snooze-count) is a deferred post-MVP idea, noted for later.

**Dismiss has no effect beyond stopping playback and canceling any pending snooze.** `claim_queue_head`'s `played_at`/Library-save already happened once, at the first tap-through into the app for this Wake Event (not necessarily the Wake Event's first ring — if the user never taps in until ring 3, the claim happens then). Dismiss doesn't touch that. What dismiss *does* do is flip the Alarm back to idle: only once dismissed (or once the Wake Event times out with no tap-through) is it safe for ticket 06's "resync wake trigger on queue mutation" hook to cancel/reschedule this Alarm's AlarmKit configuration for its next occurrence — that hook must never run while the alarm is actively ringing or snoozing, since canceling a live, unacknowledged alarm would abort it.

**A new Alarm Call arriving mid-ring or mid-snooze never interrupts the active Wake Event.** It inserts into `queue_entries` as normal, but the resync-on-mutation hook is gated (per above) to only act once this Alarm returns to idle — it cannot affect the clip already committed to the in-progress Wake Event, regardless of Auto-play vs. Library-override mode.

**Post-MVP idea captured, out of scope for this ticket:** an interactive/gamified dismiss interaction — e.g. letting a friend who sent the Alarm Call move or resize the dismiss button, or make it deliberately harder to hit, for a more playful/challenging wake experience. Logged on the map's Out of scope section and in memory for continuity.
