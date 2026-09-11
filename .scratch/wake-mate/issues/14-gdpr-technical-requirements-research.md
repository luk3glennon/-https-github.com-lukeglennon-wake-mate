Status: resolved
Type: research

## Question

Research the technical (not legal-drafting) requirements GDPR imposes on Wake Mate's architecture: what personal data is collected (audio recordings, phone number/email, friend graph, timestamps), required consent-capture points, encryption-at-rest and in-transit expectations, and what a defensible deletion window looks like for the temporary cloud copy of shared Alarm Calls (the brief specifies "a short expiration window" but not a number).

## Answer

Full findings, with citations: [14-gdpr-technical-requirements-findings.md](./14-gdpr-technical-requirements-findings.md).

**Data classification** — Audio recordings, phone/email, the friend graph, and usage logs/timestamps are all "personal data" under Art. 4(1). Raw voice audio is **not automatically special-category data** under Art. 9 — that classification hinges on whether the data is *processed to uniquely identify* someone (voiceprint matching), not on the mere fact that a voice was recorded. It only becomes relevant if Wake Mate later adds a voice-ID/matching feature. Third-party voices captured incidentally (background noise, impressions) are still that third party's personal data, effectively collected by the sender rather than Wake Mate directly — a UX-level gap worth addressing (e.g. a recording-time notice), not a solvable consent problem.

**Consent points** — Account creation should rest on contract necessity (Art. 6(1)(b)), not a consent checkbox. Contacts/address-book access for friend-finding and microphone/recording both need explicit consent (Art. 6(1)(a)) given third-party data exposure. Marketing comms need separate, unbundled opt-in consent.

**Encryption** — TLS 1.2 minimum (prefer 1.3) in transit; provider-managed AES-256 at rest (S3 SSE-S3 default, GCS default encryption) satisfies Art. 32's "appropriate technical measures" — GDPR mandates no specific algorithm, this is industry baseline.

**Recommended deletion window: 48 hours.** Delete the temporary cloud copy of a shared Alarm Call on the earlier of (a) confirmed recipient download or (b) a fixed 48-hour timeout. This sits between WeTransfer's ~3-day free-tier norm and a tighter posture, justified because Wake Mate is handling voice recordings (more clearly personal/identifying than an arbitrary file) — Art. 5(1)(c) data minimisation and Art. 5(1)(e) storage limitation both favor not leaving audio on third-party cloud infrastructure longer than needed, while still giving the recipient's device a realistic day/night cycle to come online.

**Other concepts** — Right to erasure (Art. 17) only reaches Wake Mate's own systems: cascade-delete the departing user's friend-graph edges and cloud copies, but an Alarm Call already downloaded to a friend's device can't be remotely wiped (ICO guidance: obligation is to inform, not force-delete on-device) — document this limitation in-product. Data portability (Art. 20) covers account profile data, self-recorded Alarm Calls, and friend-list contents, not derived/inferred data. Cross-border transfer: if using a non-EU cloud provider, the EU-US Data Privacy Framework adequacy decision currently covers DPF-certified US vendors (survived its first General Court challenge, Sept 2025, but remains litigation-exposed as the third framework after Safe Harbor/Privacy Shield were struck down) — SCCs are the fallback, and defaulting to EU-region hosting sidesteps the issue entirely, worth deciding now since backend is still TBD.

Two sources (an ICO erasure page, an EDPB voice-assistant PDF) could only be corroborated via search-index summaries, not a direct fetch — flagged in the findings file for re-verification before any legal/external use.
