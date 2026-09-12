# 09: Returning user sign-in

**What to build:** Someone who already has an account can get back into the app.

**Blocked by:** None (01's auth seam already exists; this is additive)

- [ ] A sign-in screen exists, reachable from the sign-up screen and vice versa
- [ ] `AuthServicing` gains a `signIn(email:password:)` method, implemented on `SupabaseAuthService` via `client.auth.signIn(email:password:)`
- [ ] Wrong email/password surfaces a readable error rather than failing silently
- [ ] Password reset — decide whether it's in scope here or deferred; without it, a forgotten password is still a dead end (Supabase Auth has `resetPasswordForEmail`, but it needs a redirect target and `site_url` is still `http://127.0.0.1:3000` in `supabase/config.toml`)
- [ ] Unit tests alongside `WakeMateTests/SignUpViewModelTests.swift`

## Why this exists (found 2026-09-12)

Spotted while filling in Apple's Beta App Review details for ticket 02 —
Apple asks for a working username/password so its reviewer can sign in,
which surfaced that there is nowhere to sign *in*.

`RootView` renders `SignUpView` whenever there's no session and `HomeView`
when there is. There is no third state and no sign-in view anywhere in
`ios/WakeMate/`. `AuthServicing` exposes `signUp`, `signOut`, `session`,
and `observeAuthState` — no `signIn`.

The practical consequence: `HomeView` has a sign-out button, and pressing
it strands the user permanently. Their only route back into the app is to
create a second account under a different email address, which also
orphans the `profiles` row from the first one. Reinstalling the app, or
any event that clears the stored session, has the same effect.

This was not caught earlier because the ticket-01 checklist only ever
asked that a user can *sign up* and land on the home stub, which is
genuinely all that was built, and because the app has never been run
end-to-end on a real device (no Mac in this project — see ticket 01's
Held section).

## Note for whoever picks this up

Ticket 02's first external TestFlight build ships without this. The
Beta App Review notes tell Apple's reviewer to create an account rather
than sign in, which is accurate and should pass review — sign-up is
open, and the hosted Supabase project has `mailer_autoconfirm` on, so
accounts activate immediately with no confirmation email. But the first
real external tester will hit the sign-out trap, so this wants fixing
before the tester group grows beyond one or two people.
