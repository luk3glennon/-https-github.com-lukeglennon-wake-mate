# 04: Alarm scheduling core (AlarmKit)

**What to build:** A user can create, edit, and delete Alarms that reliably fire via AlarmKit — surviving force-quit and silent mode — and can snooze or dismiss them, all playing the bundled default tone (no Queue/Sharing yet).

**Blocked by:** 01 (Foundation: account creation + deploy pipeline)

- [ ] `alarms` table (`owner_id`, `label`, `wake_time`, `repeat_days`, `mode`, `library_override_alarm_call_id`, `snooze_enabled`, `snooze_duration_minutes`, timestamps)
- [ ] Create/edit/delete Alarm UI
- [ ] AlarmKit runtime authorization (`NSAlarmKitUsageDescription`) requested and handled
- [ ] Alarm scheduled via AlarmKit fires through silent mode/Focus/DND and survives force-quit, presenting full-screen/Lock Screen UI
- [ ] Empty Queue + empty Library falls back to the bundled default alarm tone
- [ ] Snooze uses AlarmKit's native snooze `AppIntent`, replaying the same tone on every re-ring; duration/count fixed/global for MVP
- [ ] Dismiss stops playback and cancels any pending snooze, with no other side effects
- [ ] A new Alarm Call arriving mid-Wake-Event never interrupts an active ring/snooze (verify with the default-tone path — no real Shares exist yet, but the ring/snooze state machine must already respect this)
