# 03: Friend discovery & connection

**What to build:** The full onboarding sequence and the ability for two users to become mutual friends, either by exact-handle search or by a personal Invite Link — no partial/directory search, no auto-created connections.

**Blocked by:** 01 (Foundation: account creation + deploy pipeline)

- [ ] `friend_connections` table with `requester_id`/`addressee_id`/`status` (`pending`/`accepted`/`declined`) and the normalized-pair unique index preventing duplicate/reverse requests
- [ ] Exact-handle-only search (no partial match, no directory/enumeration surface)
- [ ] Personal, reusable Invite Link per user; resolving one never auto-creates the connection — same explicit accept step as search
- [ ] Onboarding sequence implemented: account creation → invite/search screen (Inline Minimal layout: compact single column, Skip always available, Invite Link as a prominent inline row) → pending-request accept/decline (shown only when arriving via a resolved Invite Link) → home
- [ ] Two test accounts can become mutual friends via handle search
- [ ] Two test accounts can become mutual friends via an Invite Link, including the organic-signup path correctly skipping the accept/decline step
