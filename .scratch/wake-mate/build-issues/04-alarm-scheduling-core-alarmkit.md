# 04: Alarm scheduling core (AlarmKit)

**What to build:** A user can create, edit, and delete Alarms that reliably fire via AlarmKit — surviving force-quit and silent mode — and can snooze or dismiss them, all playing the bundled default tone (no Queue/Sharing yet).

**Blocked by:** 01 (Foundation: account creation + deploy pipeline)

**Status (2026-09-14): Implemented, code-reviewed, and on-device-verified for the
core ring/snooze cycle.** Committed across `224a02b` (initial implementation),
`92d9997` (unrelated CLAUDE.md note), `76d67eb`, and `8c8415d` (both post-review,
on-device bug fixes) on `main`.

- [x] `alarms` table (`owner_id`, `label`, `wake_time`, `repeat_days`, `mode`, `library_override_alarm_call_id`, `snooze_enabled`, `snooze_duration_minutes`, timestamps)
- [x] Create/edit/delete Alarm UI
- [x] AlarmKit runtime authorization (`NSAlarmKitUsageDescription`) requested and handled
- [x] Alarm scheduled via AlarmKit fires through silent mode/Focus/DND and survives force-quit, presenting full-screen/Lock Screen UI — confirmed on-device (iOS 26.6.1) for a fired-at-wake-time alarm; force-quit and silent/Focus/DND specifically not yet separately exercised
- [x] Empty Queue + empty Library falls back to the bundled default alarm tone — bug fixed 2026-09-13 (see Decisions); re-verification on-device after the fix still pending
- [x] Snooze uses AlarmKit's native snooze `AppIntent`, replaying the same tone on every re-ring; duration/count fixed/global for MVP — confirmed on-device: snoozed alarm re-rang 9 minutes later
- [ ] Dismiss stops playback and cancels any pending snooze, with no other side effects — implemented (`StopAlarmIntent` → `AlarmManager.shared.stop(id:)`), not yet exercised on-device
- [x] A new Alarm Call arriving mid-Wake-Event never interrupts an active ring/snooze (verify with the default-tone path — no real Shares exist yet, but the ring/snooze state machine must already respect this) — enforced in `AlarmSyncCoordinator`/`AlarmKitScheduler` and covered by unit tests; no real Queue/Sharing exists yet to exercise this on-device, consistent with this ticket's scope

## Decisions made

- **Snooze duration/count is fixed and global (9 minutes), not read from the
  per-row `snooze_duration_minutes`/`snooze_enabled` columns**, per ADR-0003.
  Those columns stay in the schema for a future ticket; `AlarmKitScheduler`
  hard-codes `AlarmKit.Alarm.CountdownDuration(preAlert: nil, postAlert: 9 * 60)`
  instead.
- **No widget extension was built.** The ticket only calls for the system's
  own alert UI (no custom Live Activity/Dynamic Island content), so a plain
  `alert`-only `AlarmPresentation` was used. Revisit only if a future ticket
  needs custom countdown/paused presentation content.
- **Snooze/stop are wired through two `LiveActivityIntent`s
  (`SnoozeAlarmIntent`, `StopAlarmIntent`) that carry only the alarm's UUID
  as a string** (`AlarmIntents.swift`), since these run out-of-process and
  can't hold a reference to any live app object.
- **A `refreshActiveAlarms()` call was added to `AlarmActivityTracking`** and
  is invoked synchronously at the start of every `AlarmSyncCoordinator.sync`,
  ahead of the background `alarmUpdates`-stream-fed cache, to close a
  cold-launch race where a sync could run before that stream had delivered
  its first value — the exact "never touch a ringing alarm" invariant this
  architecture exists to protect (ADR-0003).

## Bugs found and fixed after initial implementation

1. **`countdownDuration: nil`** meant no snooze length was actually
   configured despite ADR-0003 requiring one. Found by the spec-axis
   `/code-review`. Fixed by setting the fixed 9-minute duration above.
2. **Cold-launch activity-tracking race** (see Decisions). Found by the
   spec-axis `/code-review`. Fixed by `refreshActiveAlarms()`.
3. **`AlarmListViewModel.isBusy` was tracked but never read by the view**,
   so buttons stayed enabled during a save/delete. Found by the
   standards-axis `/code-review`. Fixed in `AlarmListView.swift`.
4. **Release build failed to compile**: `static var title` / `static var
   openAppWhenRun` on both intents in `AlarmIntents.swift` tripped Swift's
   concurrency-safety check ("nonisolated global shared mutable state").
   Caught by the `ios-release.yml` GitHub Actions pipeline, not locally
   (no Mac in this environment). Neither property is ever mutated, so both
   were changed to `static let`.
5. **Custom alarm tone never played — the system's own default "Radar" tone
   played instead**, confirmed on a real device already on iOS 26.6.1 (well
   past the known iOS 26.0 `.named(_:)` bug, which was ruled out as the
   cause). Root cause: `AlertConfiguration.AlertSound.named(_:)` requires the
   file extension in the name it's given (unlike `UNNotificationSoundName`)
   — the code passed `"default_alarm_tone"` instead of
   `"default_alarm_tone.wav"`, so the file silently wasn't found. Fixed in
   `AlarmKitScheduler.swift`; not yet re-confirmed on-device.

## Still open

- Re-verify the custom tone plays (fix above) and that dismiss/stop behaves
  correctly, on-device.
- Force-quit and silent-mode/Focus/DND firing haven't been separately
  exercised on-device (only a normal foreground-scheduled fire-and-snooze
  has).
- Two facts noted as unconfirmed-from-an-official-source in
  `.scratch/wake-mate/research/alarmkit-api.md` remain unconfirmed: whether
  tapping the alert's `.countdown`-behavior secondary button alone already
  re-arms the ring (making `SnoozeAlarmIntent`'s explicit `countdown(id:)`
  call redundant-but-harmless), and the exact case names on
  `AlarmKit.Alarm.State`.
