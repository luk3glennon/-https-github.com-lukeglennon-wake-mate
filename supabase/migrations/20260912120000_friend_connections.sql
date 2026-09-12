-- Ticket 03: friend discovery & connection.
--
-- Two ways to become friends, both landing in the same friend_connections
-- table:
--   1. Exact-handle search -> sender inserts a 'pending' row directly
--      (RLS-checked), receiver later updates it to 'accepted'/'declined'.
--   2. Invite link -> resolving the code is a pure read (no row created);
--      only the explicit "Accept" tap calls accept_invite(), which inserts
--      the row already 'accepted'. "Decline" creates nothing at all. This
--      is what "resolving one never auto-creates the connection" means:
--      viewing/parsing the link is side-effect-free, only the tap acts.

-- invite_code rides on profiles rather than a separate table: it's a
-- 1:1, permanent, never-rotated attribute of a profile, same shape as
-- handle. Same placeholder-generation approach as handle (ticket 01) —
-- a real "let the user see/share their code" UI is this ticket's job, but
-- the code itself doesn't need to be human-chosen.
alter table profiles
  add column invite_code text unique;

create or replace function public.generate_invite_code()
returns text
language sql
as $$
  select lower(substr(md5(random()::text || clock_timestamp()::text), 1, 10));
$$;

update profiles
  set invite_code = public.generate_invite_code()
  where invite_code is null;

alter table profiles
  alter column invite_code set not null;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  candidate_handle text;
  candidate_invite_code text;
  tos_accepted_at_claim text;
  parsed_tos_accepted_at timestamptz;
begin
  tos_accepted_at_claim := new.raw_user_meta_data ->> 'tos_accepted_at';
  begin
    parsed_tos_accepted_at := coalesce(tos_accepted_at_claim::timestamptz, now());
  exception when others then
    parsed_tos_accepted_at := now();
  end;

  loop
    candidate_handle := 'user_' || substr(md5(random()::text || clock_timestamp()::text), 1, 12);
    candidate_invite_code := public.generate_invite_code();
    begin
      insert into public.profiles (user_id, handle, tos_accepted_at, invite_code)
      values (new.id, candidate_handle, parsed_tos_accepted_at, candidate_invite_code);
      exit;
    exception when unique_violation then
      -- handle or invite_code collision: loop and try another candidate pair
    end;
  end loop;

  return new;
end;
$$;

create table friend_connections (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users (id) on delete cascade,
  addressee_id uuid not null references auth.users (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  constraint friend_connections_not_self check (requester_id <> addressee_id)
);

-- Normalized-pair unique index: (A, B) and (B, A) collide regardless of
-- who's requester vs addressee, so a second request in either direction
-- hits this constraint instead of creating a duplicate/reverse row.
create unique index friend_connections_unique_pair
  on friend_connections (least(requester_id, addressee_id), greatest(requester_id, addressee_id));

create index friend_connections_addressee_idx on friend_connections (addressee_id, status);
create index friend_connections_requester_idx on friend_connections (requester_id, status);

alter table friend_connections enable row level security;

create policy "Users can view their own connections"
  on friend_connections for select
  using (auth.uid() = requester_id or auth.uid() = addressee_id);

create policy "Users can send a request as themselves"
  on friend_connections for insert
  with check (auth.uid() = requester_id);

create policy "Addressee can respond to a pending request"
  on friend_connections for update
  using (auth.uid() = addressee_id and status = 'pending')
  with check (status in ('accepted', 'declined'));

-- Exact-handle search only: security definer so it can see other users'
-- profiles despite profiles' own RLS (owner-only select), but it only ever
-- returns a single exact match — no partial match, no listing, so it
-- can't be used as a directory/enumeration surface.
create or replace function public.search_profile_by_handle(p_handle text)
returns table (user_id uuid, handle text)
language sql
security definer
set search_path = public
stable
as $$
  select p.user_id, p.handle
  from profiles p
  where p.handle = lower(p_handle)
    and p.user_id <> auth.uid();
$$;

-- Read-only lookup for a scanned/entered invite code. Deliberately does
-- not touch friend_connections — see header note.
create or replace function public.resolve_invite_code(p_code text)
returns table (user_id uuid, handle text)
language sql
security definer
set search_path = public
stable
as $$
  select p.user_id, p.handle
  from profiles p
  where p.invite_code = lower(p_code)
    and p.user_id <> auth.uid();
$$;

-- The only write path for the invite-link flow. Idempotent: tapping
-- Accept twice (or on a code already resolved by both sides) settles on
-- 'accepted' rather than erroring, since the unique pair index would
-- otherwise raise on a second call.
create or replace function public.accept_invite(p_code text)
returns friend_connections
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid;
  result friend_connections;
begin
  select p.user_id into owner_id
  from profiles p
  where p.invite_code = lower(p_code)
    and p.user_id <> auth.uid();

  if owner_id is null then
    raise exception 'invite code not found';
  end if;

  insert into friend_connections (requester_id, addressee_id, status, responded_at)
  values (owner_id, auth.uid(), 'accepted', now())
  on conflict (least(requester_id, addressee_id), greatest(requester_id, addressee_id))
  do update set status = 'accepted', responded_at = now()
  where friend_connections.status <> 'declined'
  returning * into result;

  if result.id is null then
    select * into result from friend_connections
    where least(requester_id, addressee_id) = least(owner_id, auth.uid())
      and greatest(requester_id, addressee_id) = greatest(owner_id, auth.uid());
  end if;

  return result;
end;
$$;

-- Joins in the requester's handle so the client doesn't need a second,
-- RLS-blocked lookup against profiles just to render the list.
create or replace function public.pending_incoming_requests()
returns table (request_id uuid, requester_handle text, created_at timestamptz)
language sql
security definer
set search_path = public
stable
as $$
  select fc.id, p.handle, fc.created_at
  from friend_connections fc
  join profiles p on p.user_id = fc.requester_id
  where fc.addressee_id = auth.uid()
    and fc.status = 'pending'
  order by fc.created_at desc;
$$;

grant execute on function public.search_profile_by_handle(text) to authenticated;
grant execute on function public.resolve_invite_code(text) to authenticated;
grant execute on function public.accept_invite(text) to authenticated;
grant execute on function public.pending_incoming_requests() to authenticated;
