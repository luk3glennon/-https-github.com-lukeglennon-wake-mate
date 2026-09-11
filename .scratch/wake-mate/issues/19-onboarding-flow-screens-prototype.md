Status: resolved
Type: prototype

## Question

Now that the friend discovery mechanism (ticket 16: Invite Link + exact-handle search, skippable "invite a friend" screen right after signup) and the client framework (ticket 07: native SwiftUI) are both locked, build a rough SwiftUI prototype of the onboarding flow's actual screens (account creation → skippable invite/add-friend screen → pending-request accept screen) to react to: layout, copy, and the accept/decline interaction.

## Answer

Three structurally different SwiftUI variants were built (`prototypes/onboarding-flow/`) and reacted to via a browser mockup. **Variant C ("Inline Minimal") wins**, with two amendments surfaced during review:

- **Invite screen**: keep C's single compact column (handle search, inline add-on-exact-match, Skip in the nav bar) but make the Invite Link *more prominent* than C's original bare icon-only treatment — without going as far as Variant B's separate card/disclosure-group, which read as too blocky/inconsistent with C's inline style. Target: a labeled inline row (link text + share affordance) that sits at the same visual weight as the search field, not its own section.
- **Pending-request step is conditional, not unconditional**: per ticket 16, opening an Invite Link "resolves the pending inviter on first launch" — that's the *only* way a brand-new account can have an incoming request before anyone could have found their Handle via search. So:
  - If the new user arrived via someone's Invite Link, show exactly **one** resolved pending request (accept/decline) as part of onboarding.
  - If they arrived organically (no link tap), **skip the pending-request step entirely** — there's nothing to show, and it shouldn't be a stop on the happy path.
  - The prototype's two-request mock seed (Morgan K. *and* Sam R.) was a mistake, not a deliberate case — a fresh install can resolve at most one inviter. Sam R. should be dropped from the onboarding-time scenario. Variant C's List/swipe-actions shape for *multiple* requests remains the right design for the general "Friend Requests" screen accessed later (post-onboarding, once more requests accumulate via handle search) — just not something onboarding itself needs to render.

Net onboarding sequence: account creation → invite/search screen (Skip always available) → pending-request accept/decline (only if a link-resolved inviter exists, otherwise skipped) → home.
