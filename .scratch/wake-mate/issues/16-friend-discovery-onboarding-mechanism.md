Status: resolved
Type: grilling

## Question

Decide how users find and add friends given the mutual-acceptance Friend Connection model (ticket 01): phone-contacts sync, username/handle search, invite links, or a mix. Note: if contacts syncing is chosen, revisit against ticket 14/15's consent findings.

## Answer

MVP builds two mechanisms: a personal, permanent, reusable Invite Link per user, and exact-handle-only search. Phone-contacts sync is deferred to post-MVP — the GDPR consent UX (ticket 14) plus server-side contact-hashing/matching isn't worth the engineering cost for a solo 4-week build.

- **Invite Link**: one per user, not per-invite/single-use. Supports invite-to-install (Universal Link → App Store → resolves the pending inviter on first launch if the recipient doesn't have the app yet).
- **Mutual acceptance preserved**: tapping an Invite Link never auto-creates the connection — it surfaces the same explicit accept screen as any other pending request, regardless of entry path. Consistent with ticket 01's abuse-avoidance rationale (no content moderation in MVP).
- **Handle**: every user gets a unique, auto-generated Handle at signup (lowercase alphanumeric + underscore, 3–20 chars), editable later in settings. Used for exact-match search and to attribute pending requests/Invite Links. See CONTEXT.md.
- **Search is exact-handle-only**: no directory, no partial/browsable search — prevents enumeration and unsolicited requests given no MVP moderation.
- **Onboarding placement**: "invite a friend" is the first screen after account creation, but skippable — not a gate on completing onboarding, since accepting a request depends on another person acting.

New vocabulary (Handle, Invite Link) folded into CONTEXT.md.
