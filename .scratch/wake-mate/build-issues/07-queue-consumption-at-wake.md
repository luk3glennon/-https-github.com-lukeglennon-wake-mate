# 07: Queue consumption at wake

**What to build:** A recipient's Alarm actually fires and plays the real shared clip end-to-end — including the resync-on-mutation AlarmKit rescheduling, best-effort background downloads, fire-time fallback, auto-save-to-Library, and correct snooze/dismiss interaction with the Queue.

**Blocked by:** 04 (Alarm scheduling core (AlarmKit)), 06 (Share sending & Queue population)

- [ ] `claim_queue_head(p_alarm_id)` `security definer` RPC: verifies caller owns the Alarm; if `library_override`, returns the override clip's `storage_path` with no `queue_entries` mutation; if `auto_play`, selects the oldest unplayed `queue_entries` row (FIFO head), returns empty if none, else sets `played_at = now()`, upserts `library_entries(user_id, alarm_call_id, 'received')`, and returns the `storage_path`
- [ ] Resync-on-queue-mutation hook: every Queue-head change opportunistically cancels + reschedules AlarmKit's config on any execution window; if no window arises before fire time, the previously-scheduled head plays as-is; this hook must never fire mid-Wake-Event, only once the Alarm returns to idle
- [ ] Download/prefetch is layered and best-effort, decoupled from `claim_queue_head`: attempted on push arrival, on every app foreground, and on any AlarmKit scheduling callback ahead of wake time
- [ ] Fire-time fallback: if `claim_queue_head` returns a head that isn't yet local, the Alarm plays the default fallback tone and the `queue_entries` row is *not* marked played, so it retries on the next fire (up to the Share's 48h expiry)
- [ ] Tapping through the AlarmKit teaser launches the app and plays the full clip via `AVAudioPlayer`
- [ ] A played Alarm Call auto-saves to the recipient's Library
- [ ] Snooze replays the exact same claimed Alarm Call on every re-ring, never advancing or re-claiming the Queue
- [ ] Dismiss only stops playback and cancels any pending snooze — `claim_queue_head`'s `played_at`/Library-save already happened at first tap-through and is not repeated
- [ ] A new Alarm Call arriving mid-Wake-Event never interrupts the active ring/snooze; it waits in the Queue
- [ ] End-to-end: recipient's Alarm fires, plays the actual shared clip (or falls back correctly if undownloaded), and receiving a new Alarm Call resets that Alarm to `auto_play`
