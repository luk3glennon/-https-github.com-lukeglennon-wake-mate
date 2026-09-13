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

## Sign-in

- [x] A sign-in screen exists (`SignInView.swift`), reachable from the sign-up
      screen and vice versa via `AuthGateView.swift`, which toggles between them
- [x] `AuthServicing` gains `signIn(email:password:)`, implemented on
      `SupabaseAuthService` via `client.auth.signIn(email:password:)`
- [x] `RootView` grows a third state (`AppState.Flow`: `authGate` /
      `friendOnboarding` / `home`) — the "nothing in between" gap is now the
      friend-onboarding step below, not a second auth screen
- [x] Wrong email/password surfaces a readable error (`SignInViewModel.errorMessage`,
      rendered in `SignInView`) rather than failing silently
- [x] Unit tests alongside `WakeMateTests/SignInViewModelTests.swift`
- [ ] **Password reset — deferred, not built.** `resetPasswordForEmail` needs a
      redirect target, and `supabase/config.toml`'s `site_url` is still
      `http://127.0.0.1:3000` with no real deep-link handling in the iOS app to
      catch that redirect. Building this now would mean standing up URL-scheme
      or universal-link handling just for this one flow. A forgotten password
      is still a dead end until this is picked up — flagging as a real gap,
      not silently dropped.

## Friend discovery & connection

- [x] `friend_connections` table with `requester_id`/`addressee_id`/`status`
      (`pending`/`accepted`/`declined`) and the normalized-pair unique index
      preventing duplicate/reverse requests (`supabase/migrations/20260912120000_friend_connections.sql`)
- [x] Exact-handle-only search — `search_profile_by_handle` RPC, single exact
      match only, no partial match or listing surface
- [x] Personal, reusable invite code per user (`profiles.invite_code`,
      generated at signup same as `handle`); resolving one
      (`resolve_invite_code` RPC) is a pure read and never creates a
      connection — only the explicit Accept tap (`accept_invite` RPC) does,
      and it lands the connection already `accepted` in one step. Decline
      makes no network call at all.
- [x] Onboarding sequence implemented: account creation → invite/search screen
      (`FriendOnboardingView`, Inline Minimal layout: compact single column,
      Skip always available, invite code row prominent) → pending
      accept/decline screen (shown only once a pasted code actually resolves)
      → home
- [x] `HomeView` gains a permanent "Add a Friend" button that reopens
      `FriendOnboardingView` as a sheet. Without it, that screen was only
      ever reachable once, automatically, right after a brand-new sign-up
      (`RootView`'s `Flow.friendOnboarding`) — a returning user signing back
      into an existing account had no way back into it at all, which is
      exactly the case the Testing note below describes ("sign out of A,
      sign in as B"). Found 2026-09-12 during real-device end-to-end
      testing: signing in landed on a bare "You're all set" / Sign Out
      screen with no way to add a friend.
- [x] Three real-device UX fixes found in the same test pass (2026-09-13):
      the invite code had no visible way to copy it (added a Copy button
      with a "Copied" confirmation); the search screen only showed *your*
      invite code, not your handle, even though a friend can search you by
      handle too (now shown above the search field); and the resolved-invite
      screen read "X wants to connect" with Accept/Decline, backwards from
      what's actually happening — the person pasting in someone else's code
      is the one proposing the connection, not the other way around. Now
      reads "Connect with X?" with Cancel/Connect.
- [x] Two test accounts can become mutual friends via an Invite Link —
      confirmed working end-to-end on a real device, 2026-09-13.
- [ ] Two test accounts can become mutual friends via handle search — hit a
      real bug during the same test pass: sending a request to someone you're
      already connected with (the two test accounts had just connected via
      invite code) surfaced the raw Postgres error text ("duplicate key value
      violates unique constraint...") instead of a readable message. The
      underlying rule is correct — `friend_connections_unique_pair` is
      supposed to block a second request between the same two people — the
      app just wasn't translating it. Fixed 2026-09-13
      (`FriendServiceError.alreadyConnectedOrPending` in `FriendService.swift`).
      Still needs a real end-to-end run against two accounts that *aren't*
      already connected, to confirm the happy path (search → request →
      other side accepts in `HomeView`) works start to finish.

## Scope decision: invite "link" is a pasted code, not a tappable link (2026-09-12)

What's built is a short invite **code** each user can read off their own
screen and hand to a friend, who pastes it into a field to resolve it. A real
tappable link (`https://wakemate.app/invite/abc123` opening the app directly)
needs Associated Domains + a hosted `apple-app-site-association` file, which
needs a real domain — none of which exists yet. Wiring that is a reasonable
follow-up once a domain exists, but the underlying accept/decline mechanics
(the actual hard part) are already in place and don't change when that lands
— only how the code gets from A's screen into B's hands changes.

## Held / deferred (2026-09-12)

- **Password reset** — see above; not built.
- **Real tappable Invite Links** — see scope decision above; code-paste only for now.
- **End-to-end verification** (two real accounts actually befriending each
  other via both paths, sign-in actually working) — not run this session,
  same gap ticket 01 and 02 flagged: needs either a Mac/simulator session or
  a real TestFlight build via ticket 02's pipeline once that's unblocked.

## Testing note

Two accounts means two devices or one device and a simulator — and with
sign-in built, one device is enough: sign out of A, sign in as B. That is the
second reason sign-in was done first.
