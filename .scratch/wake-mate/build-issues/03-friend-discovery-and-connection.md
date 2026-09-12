# 03: Returning-user sign-in, friend discovery & connection

**What to build:** Everything between "I have an account" and "I have a friend":
a returning user can get back into the app, and two users can become mutual
friends, either by exact-handle search or by a personal Invite Link — no
partial/directory search, no auto-created connections.

**Blocked by:** nothing — 01 (Foundation) closed 2026-09-12.

> Sign-in was folded in here on 2026-09-12 at the dev's request; it had been
> tracked separately as ticket 09, which is now a pointer to this file. The
> filename still says `03-friend-discovery-and-connection.md` — left alone
> deliberately, since renaming it breaks the references in tickets 01 and 02
> for no gain.

## Sign-in (do this first)

It gates everything else in this ticket: you cannot test two accounts
befriending each other if you cannot get back into either of them.

- [ ] A sign-in screen exists, reachable from the sign-up screen and vice versa
- [ ] `AuthServicing` gains `signIn(email:password:)`, implemented on `SupabaseAuthService` via `client.auth.signIn(email:password:)`
- [ ] `RootView` grows a third state — it currently renders `SignUpView` when there's no session and `HomeView` when there is, with nothing in between
- [ ] Wrong email/password surfaces a readable error rather than failing silently
- [ ] Password reset — decide whether it's in scope here or deferred; without it a forgotten password is still a dead end. Supabase Auth has `resetPasswordForEmail`, but it needs a redirect target and `site_url` is still `http://127.0.0.1:3000` in `supabase/config.toml`
- [ ] Unit tests alongside `WakeMateTests/SignUpViewModelTests.swift`

### Why this is urgent rather than merely missing

Found 2026-09-12 while filling in Apple's Beta App Review details for ticket
02 — Apple asks for a working username/password so its reviewer can sign in,
which surfaced that there is nowhere to sign *in*.

`HomeView` has a sign-out button, and pressing it strands the user
permanently. Their only route back is a second account under a different
email, which also orphans the `profiles` row from the first. Reinstalling the
app, or anything that clears the stored session, does the same.

It was missed because ticket 01's checklist only ever asked that a user can
*sign up* and land on the home stub, which is genuinely all that was built.

The first external TestFlight build ships without this. That should still pass
review — the reviewer notes tell Apple's reviewer to create an account rather
than sign in, sign-up is open, and the hosted Supabase project has
`mailer_autoconfirm` on so accounts activate immediately. But the first real
external tester will hit the sign-out trap, which is why this sits at the top
of the ticket.

## Friend discovery & connection

- [ ] `friend_connections` table with `requester_id`/`addressee_id`/`status` (`pending`/`accepted`/`declined`) and the normalized-pair unique index preventing duplicate/reverse requests
- [ ] Exact-handle-only search (no partial match, no directory/enumeration surface)
- [ ] Personal, reusable Invite Link per user; resolving one never auto-creates the connection — same explicit accept step as search
- [ ] Onboarding sequence implemented: account creation → invite/search screen (Inline Minimal layout: compact single column, Skip always available, Invite Link as a prominent inline row) → pending-request accept/decline (shown only when arriving via a resolved Invite Link) → home
- [ ] Two test accounts can become mutual friends via handle search
- [ ] Two test accounts can become mutual friends via an Invite Link, including the organic-signup path correctly skipping the accept/decline step

## Testing note

Two accounts means two devices or one device and a simulator — and with
sign-in built, one device is enough: sign out of A, sign in as B. That is the
second reason to do sign-in first.
