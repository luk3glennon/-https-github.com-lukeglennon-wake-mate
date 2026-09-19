-- Ticket 05 follow-up: let a user optionally title an Alarm Call recording
-- at save time, so the Library and the wake-sound picker can show something
-- more useful than a raw timestamp once one's been given. Nullable so
-- existing rows (and clips saved without a title) are unaffected.
alter table alarm_calls add column title text;
