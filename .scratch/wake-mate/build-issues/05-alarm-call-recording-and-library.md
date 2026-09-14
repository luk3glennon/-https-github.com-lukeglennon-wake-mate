# 05: Alarm Call recording & Library

**What to build:** A user can record a short voice clip, see it saved to their Library, and set one of their Alarms to play it directly (Library-override mode) — independent of any Sharing/Queue mechanics.

**Blocked by:** 04 (Alarm scheduling core (AlarmKit))

- [ ] `alarm_calls` table (`owner_id`, `storage_path`, `duration_seconds`, `created_at`)
- [ ] `library_entries` table (`user_id`, `alarm_call_id`, `source` = `created`/`received`), unique per user/clip
- [ ] Recording via `AVAudioRecorder`: AAC-HE, mono, 44.1kHz, `.m4a`, 32kbps, max 30 seconds
- [ ] Recorded clip uploaded to Supabase Storage via presigned upload
- [ ] Mic-recording consent captured in-app alongside the OS mic prompt, logged to `consent_log`
- [ ] Library screen listing a user's own recorded clips
- [ ] User can set an Alarm to `library_override` mode pointing at a chosen Library clip, and it plays correctly when that Alarm fires
- [x] Receiving a new Alarm Call resets the Alarm back to `auto_play` mode (verify the mode-reset rule even though real Shares land in ticket 07 — cover it at minimum via a direct data-level test) — confirmed 2026-09-14: `supabase/tests/reset_alarm_to_auto_play_test.sql` run by hand via the Supabase Dashboard SQL Editor against the real project, ran clean (no error raised), i.e. PASS.
