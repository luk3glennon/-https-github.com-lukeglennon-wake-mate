-- Ticket 05 follow-up: consent_log.consent_type was left as `text not null`
-- with no `check` constraint when the table was created (in
-- 20260914090000_alarm_calls_and_library.sql), unlike library_entries.source
-- and alarms.mode, which both constrain their enum-like text columns the
-- same way. The only current value is 'mic_recording' (ConsentType in
-- ios/WakeMate/ConsentService.swift) — a closed set, same as those two
-- columns, so it gets the same treatment here as a follow-up migration
-- rather than editing the already-applied one above.
alter table consent_log
  add constraint consent_log_consent_type_check
  check (consent_type in ('mic_recording'));
