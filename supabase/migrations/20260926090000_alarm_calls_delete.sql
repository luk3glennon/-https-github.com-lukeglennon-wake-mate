-- Ticket 05 follow-up: let a user delete a recording from their Library.
--
-- alarm_calls had no delete policy yet (only select/insert from the
-- original ticket 05 migration). library_entries needs no matching policy:
-- its FK to alarm_calls is `on delete cascade`, so removing the alarm_calls
-- row already takes the library_entries row with it at the DB level.
create policy "Users can delete their own alarm calls"
  on alarm_calls for delete
  using (auth.uid() = owner_id);

create policy "Users can delete their own alarm call audio"
  on storage.objects for delete
  using (
    bucket_id = 'alarm-calls'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- alarms.library_override_alarm_call_id's FK is `on delete set null` (see
-- the ticket 05 migration), which alone would leave an Alarm with
-- mode = 'library_override' and a null clip - silent at fire time, since
-- LibraryOverrideSoundPreparer/LibraryOverridePlaybackCoordinator both
-- treat "no clip" as "do nothing" rather than falling back to auto_play.
-- This trigger resets mode too, so deleting a clip that's in use falls
-- that Alarm back to the default sound instead of going silent.
create or replace function public.handle_alarm_call_deleted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update alarms
  set mode = 'auto_play', library_override_alarm_call_id = null, updated_at = now()
  where library_override_alarm_call_id = old.id;
  return old;
end;
$$;

create trigger alarm_calls_before_delete
  before delete on alarm_calls
  for each row
  execute function public.handle_alarm_call_deleted();
