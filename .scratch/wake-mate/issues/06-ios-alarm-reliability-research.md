Status: resolved
Type: research

## Question

Can the decided Alarm mechanic (per-Alarm locked Queue, audio chosen and played automatically at the exact scheduled wake time, even if the app is backgrounded or force-quit) actually be built reliably on iOS? Research:

- iOS background execution limits for apps that need to play a specific, previously-unknown-at-schedule-time local audio file at an exact moment.
- Apple's Critical Alerts entitlement (requirements, approval process, whether it fits an alarm-clock app).
- Time-Sensitive / interruption-level notifications as an alternative or supplement.
- How existing alarm-clock apps (e.g. Alarmy, Sleep Cycle) solve this in practice (background audio session keep-alive, local notification scheduling, etc.).
- Whether any approach requires the audio file to be finalized/known before the Alarm is scheduled (which would conflict with "locked Queue, chosen at fire time" if the head of the Queue can change after scheduling).

Findings should flag if any part of the decided mechanic (see ticket 03) is infeasible or needs redesign.

## Answer

**Feasible — via Apple's `AlarmKit` framework (iOS 26+), not via Critical Alerts or plain local notifications.** AlarmKit is Apple's WWDC 2025 framework giving third-party apps the same system-level alarm privileges as the built-in Clock app: fires through silent mode/Focus/DND, survives force-quit, presents full-screen/Lock Screen UI — gated only by a normal `NSAlarmKitUsageDescription` + runtime authorization, **not** a restricted Apple-approved entitlement. Critical Alerts were ruled out: they require a restricted entitlement Apple approves mainly for health/safety/security apps (poor fit here), and even if granted, the sound is still a bundled file capped at ~30 seconds — no better than plain notifications for this purpose.

**The hard constraint (applies to local notifications, Critical Alerts, and AlarmKit alike):** the OS/daemon — not live app code — plays the alert sound when the app isn't foregrounded, so any custom sound must be a named file already in the bundle, capped at ~30 seconds, baked in at *schedule time*. Recommended architecture: AlarmKit fires a short (≤30s) teaser/cue sound reflecting the current queue head, and tapping through launches the app to play the *full* Alarm Call (no duration limit) via `AVAudioPlayer` once foregrounded. The legacy "silent background-audio keep-alive" trick (Alarmy-style) was evaluated and rejected as the primary mechanism — it carries App Store Guideline 2.5.4 review risk and, per Alarmy's own disclosed limitation, does not survive force-quit anyway; it's the workaround AlarmKit was built to retire.

**Queue/schedule-time conflict: real but manageable — no redesign of ticket 03 needed.** Since the alert sound is baked in at schedule time, not decided live at fire time, Wake Mate must treat "schedule the wake trigger" as an idempotent operation re-run on every queue-head mutation (cancel + reschedule pointing at the new head's file), run opportunistically whenever the app gets any execution window. Fallback: if no reschedule opportunity arises before fire time (e.g. an overnight arrival), the previously-scheduled head — still a valid, already-locked Alarm Call — simply plays as-is, a benign degradation rather than a broken state. Ticket 03's locked-queue/FIFO/auto-play model is unaffected; the only addition needed is an explicit "resync wake trigger on queue mutation" hook in the implementation.

Full findings, with citations to Apple Developer Documentation, WWDC25, Apple Developer Forums, and engineering write-ups: `.scratch/wake-mate/research/06-ios-alarm-reliability-findings.md`
