-- Ticket 01 (foundation): profiles table wired to Supabase Auth, plus the
-- signup-time trigger that creates a profile row for every new auth.users
-- row so the client never has to coordinate a separate "create my profile"
-- call (and can't leave auth.users/profiles out of sync).
--
-- Handle generation here is a placeholder (random suffix) satisfying ticket
-- 16's format (lowercase alphanumeric + underscore, 3-20 chars) so the
-- not-null unique constraint can be satisfied at signup; ticket 16's actual
-- handle UX (user-chosen, editable) is out of scope for this ticket.
--
-- tos_accepted_at is deliberately its own column, not a consent_log row:
-- ticket 15 scopes consent_log to revocable Art. 6(1)(a) consents
-- (contacts/mic). ToS acceptance is Art. 6(1)(b) contract necessity and is
-- never revoked, so it doesn't fit consent_log's granted_at/revoked_at
-- shape.

create table profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  handle text not null unique check (handle ~ '^[a-z0-9_]{3,20}$'),
  tos_accepted_at timestamptz not null,
  created_at timestamptz not null default now()
);

alter table profiles enable row level security;

create policy "Users can view their own profile"
  on profiles for select
  using (auth.uid() = user_id);

create policy "Users can update their own profile"
  on profiles for update
  using (auth.uid() = user_id);

-- No insert/delete policies: rows are created only by the security-definer
-- trigger below and never deleted directly (cascades from auth.users).

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  candidate_handle text;
  tos_accepted_at_claim text;
  parsed_tos_accepted_at timestamptz;
begin
  -- The client passes { tos_accepted_at: <ISO8601> } in signUp's `data`
  -- option, which Supabase Auth stores as raw_user_meta_data. Falling back
  -- to now() only guards against a malformed/missing claim; the client is
  -- responsible for not calling signUp before the user has actually
  -- clicked accept.
  -- Casting NULL::text to timestamptz yields NULL, not an exception, so a
  -- missing claim must be coalesced explicitly — relying on the exception
  -- handler alone only catches a present-but-unparseable string.
  tos_accepted_at_claim := new.raw_user_meta_data ->> 'tos_accepted_at';
  begin
    parsed_tos_accepted_at := coalesce(tos_accepted_at_claim::timestamptz, now());
  exception when others then
    parsed_tos_accepted_at := now();
  end;

  loop
    candidate_handle := 'user_' || substr(md5(random()::text || clock_timestamp()::text), 1, 12);
    begin
      insert into public.profiles (user_id, handle, tos_accepted_at)
      values (new.id, candidate_handle, parsed_tos_accepted_at);
      exit;
    exception when unique_violation then
      -- handle collision: loop and try another candidate
    end;
  end loop;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
