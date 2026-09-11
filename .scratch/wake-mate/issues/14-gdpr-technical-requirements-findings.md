# GDPR Technical/Architectural Requirements — Wake Mate

**Purpose:** Facts-gathering for engineering design decisions. This is not policy or legal-text drafting — no Privacy Policy or ToS language is proposed here. Verify with counsel before shipping.

**Scope:** iOS-first MVP, EU/GDPR-covered users among others. Data flow under review: local audio recording → temporary cloud upload → recipient download → cloud copy deletion; phone/email auth + contact-matching; mutual friend graph; per-alarm FIFO queue; saved Library.

---

## Summary & Recommendations

| Area | Recommendation |
|---|---|
| Data classification | Treat audio recordings, phone number/email, friend graph, and usage logs as personal data (GDPR Art. 4(1)). Raw voice audio is **not automatically** "special category" biometric data under Art. 9 — it only becomes so if Wake Mate *processes* it to uniquely identify someone (e.g., voiceprint matching). Plain playback/storage of a voice clip does not trigger Art. 9, but design should still avoid adding any voice-identification feature without re-assessing this. |
| Consent capture | At minimum 4 distinct consent/lawful-basis moments: (1) account creation/processing (contract necessity, not consent, for core service), (2) contacts/address-book access for friend-finding (consent required — this is device-permission-gated and involves third-party data), (3) microphone access/recording (device permission + a distinct notice about capturing other people's voices), (4) any marketing comms (separate opt-in consent, unbundled from service consent). |
| Encryption | TLS 1.2 minimum (prefer 1.3) in transit; provider-managed AES-256 at rest for both the object store (S3 SSE-S3/SSE-KMS or GCS default encryption) and the database. This is industry-standard security practice that supports GDPR Art. 32 "appropriate technical measures," not a GDPR-mandated algorithm. |
| **Deletion window (recommended: 48 hours)** | **48 hours after upload** for the temporary cloud copy of a shared Alarm Call, deleted automatically once the recipient's device confirms download (whichever is sooner). **Reason:** it sits between WeTransfer's free-tier norm (3 days) and Signal's 45-day retry window scaled down for a same-app, presumably-online use case, giving a recipient a full weekend/overnight cycle to come online while still satisfying GDPR's storage-limitation (Art. 5(1)(e)) and data-minimisation (Art. 5(1)(c)) principles by not holding a full copy of someone's voice on third-party cloud infrastructure any longer than needed for delivery. |
| Erasure | Right to erasure (Art. 17) can only reach data Wake Mate controls (account, cloud copies, friend-graph edges, logs). Alarm Call files already downloaded to a friend's device are **outside** Wake Mate's control once local-only — this is a real limitation to document and design around (e.g., revoke re-download, not remote wipe). |
| Cross-border transfer | If a non-EU (e.g., US) cloud provider is used, rely on the EU-US Data Privacy Framework adequacy decision (if the vendor is certified) or Standard Contractual Clauses as fallback; an EU-region deployment removes the issue entirely and should be the default choice given backend is still TBD. |

---

## 1. Personal Data Inventory & GDPR Classification

### 1.1 What Wake Mate processes, mapped to Art. 4(1)

GDPR Art. 4(1) defines personal data as "any information relating to an identified or identifiable natural person" ([gdpr-info.eu/art-4-gdpr](https://gdpr-info.eu/art-4-gdpr/)). Under that definition, all of the following are personal data:

- **Audio recordings (Alarm Calls)** — the sender's voice is directly identifying; the file itself, plus any transcript/metadata Wake Mate might derive, is personal data of the sender.
- **Phone number / email** — account identifier, also used as the input for contact-matching (friend-finding).
- **Friend Connection graph** — relational personal data about who is connected to whom; personal data of *both* parties in an edge.
- **Timestamps, device metadata, usage/queue-state logs** — personal data when linked to an account (delivery times, queue position, playback events, etc.).

### 1.2 Is voice audio "special category data" under Art. 9?

This is the key nuance and the answer is **usually no, but it's a processing-purpose question, not a content question**.

- Art. 9(1) prohibits processing of, among other categories, **"biometric data for the purpose of uniquely identifying a natural person"** — the special-category trigger is explicitly scoped to that *purpose* ([gdpr-info.eu/art-9-gdpr](https://gdpr-info.eu/art-9-gdpr/)).
- Art. 4(14) defines biometric data as "personal data resulting from **specific technical processing** relating to the physical, physiological or behavioural characteristics of a natural person, **which allow or confirm the unique identification** of that natural person, such as facial images or dactyloscopic data" ([gdpr-info.eu/art-4-gdpr](https://gdpr-info.eu/art-4-gdpr/)).
- The UK ICO's guidance on special category data draws the same line: biometric data is special-category data **if it is processed for the purpose of uniquely identifying an individual** — not all biometric-*capable* data is automatically special category; the processing purpose is what determines it, and once that purpose is established the data is treated as special category from the point of collection ([ico.org.uk — What is special category data?](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/special-category-data/what-is-special-category-data/); ICO biometric recognition guidance, [ico.org.uk/.../biometric-recognition](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/biometric-data-guidance-biometric-recognition/biometric-recognition/)).
- The EDPB has stated more strongly, in the context of voice assistants, that "voice data is inherently biometric personal data" and that processing a voiceprint to identify a user constitutes special-category biometric data processing (EDPB Guidelines 02/2021 on Virtual Voice Assistants, [edpb.europa.eu/our-work-tools/our-documents/guidelines/guidelines-022021-virtual-voice-assistants_en](https://www.edpb.europa.eu/our-work-tools/our-documents/guidelines/guidelines-022021-virtual-voice-assistants_en)). This EDPB framing is more aggressive than the ICO's "purpose-dependent" framing, and is worth flagging: **the EDPB's position is specifically about voice *assistant* processing that extracts a voiceprint for recognition** — it is not a blanket claim that every stored voice clip is special-category data.

**Practical read for Wake Mate:** Storing and replaying a raw voice recording (the current MVP design — no speaker recognition, no voiceprint extraction, no biometric authentication) does **not** put Wake Mate's audio pipeline into Art. 9 special-category territory under the ICO's purpose test. It would cross that line the moment any feature does technical processing to *identify* a speaker (e.g., "verify this is really your friend's voice," anti-impersonation detection, voice-based login). Any such feature should trigger a fresh Art. 9 legal-basis analysis (explicit consent under Art. 9(2)(a) is the most likely applicable condition) before it ships.

### 1.3 Third-party data in recordings

An Alarm Call may capture:
- **A friend imitating a third party's voice** — the recording is personal data of the *sender* (their voice/performance), not the imitated person, unless it's genuinely mistakable/identifying.
- **Ambient background voices/conversations** (someone else's voice caught incidentally) — this is personal data of that third party, collected by the sender (not Wake Mate) without that third party's knowledge, and then uploaded to Wake Mate's platform.

GDPR does not exempt incidental capture of bystanders from being "personal data," but there is no EDPB/ICO guidance specific to this exact scenario (consumer voice-note apps). The closest applicable analogy is the EDPB's Guidelines 3/2019 on video devices, which addresses incidental capture of third parties by recording devices generally ([edpb.europa.eu — Guidelines 3/2019 on processing through video devices](https://www.edpb.europa.eu/sites/default/files/files/file1/edpb_guidelines_201903_video_devices_en_0.pdf)) — the recording user, not the app, is typically the "controller" for household/personal use, but Wake Mate becomes a processor/joint controller the moment it stores and transmits the file on its infrastructure. This is a real gap the product should address at the UX layer (e.g., a recording-time reminder that only the sender's own voice/consenting participants should be recorded) rather than a purely legal one — see Section 2.4.

---

## 2. Required Consent-Capture Points

GDPR Art. 6(1) lists six lawful bases; only one requires "consent" in the strict Art. 6(1)(a)/Art. 7 sense ([gdpr-info.eu/art-6-gdpr](https://gdpr-info.eu/art-6-gdpr/)):
- **(a) Consent** — data subject has given consent for specific purpose(s)
- **(b) Contract** — necessary for performance of a contract / pre-contractual steps
- **(f) Legitimate interests** — necessary for controller's or a third party's legitimate interests, unless overridden by the data subject's rights (with heightened caution for children)

### 2.1 Account creation / core processing → **Contract necessity, Art. 6(1)(b)**, not consent
Creating and operating the account (storing phone/email, authenticating, running the alarm/queue mechanics) is "necessary for performance of the contract" the user asked for by signing up. This should **not** be gated behind a bundled "I consent" checkbox — that's a common GDPR compliance mistake (forcing consent for something that's actually contract-necessary makes the "consent" invalid because it isn't freely given). Cite: Art. 6(1)(b) text above.

### 2.2 Contact-list / address-book access for friend-finding → **Explicit consent, Art. 6(1)(a)**
This is the clearest "must be consent" point in the whole data model, for two reasons: (i) iOS itself requires an OS-level permission prompt for contacts access (a UX consent gate independent of GDPR), and (ii) uploading a user's address book means processing **third parties' data** (their contacts' phone numbers/names) who never interacted with Wake Mate and have not agreed to anything. The EDPB's Guidelines 1/2024 on Art. 6(1)(f) (legitimate interest) explicitly discusses the balancing test required whenever a controller's or third party's interest is weighed against data subjects' rights, and stresses that non-users (people who haven't opted into the service) need especially careful treatment ([edpb.europa.eu_guidelines_202401_legitimateinterest_en.pdf](https://www.edpb.europa.eu/system/files/2024-10/edpb_guidelines_202401_legitimateinterest_en.pdf)). Legitimate interest is a weaker fit here than explicit user consent for the *uploading* user's own address book; but processing of the *contacts'* (non-user) data for matching purposes is best minimized by design (see 2.4) rather than solved by consent, since Wake Mate cannot obtain consent from someone who isn't a user.

### 2.3 Microphone access & recording → **Device permission + explicit in-app consent, Art. 6(1)(a)**
Recording is the core sensitive action in the product. iOS requires its own microphone-permission consent dialog; GDPR-wise, given the potential to capture third-party voices, this is a natural point for an additional in-app acknowledgment (distinct from the OS permission) that the user understands they may be capturing others' voices and is responsible for that. This is a UX/consent-flow design point, not a lawful-basis change — the underlying processing of the *sender's own* voice for the *sender's own* Alarm Call is still Art. 6(1)(b) contract necessity (it's the core function the user asked for); it is the third-party-capture risk that argues for an extra explicit acknowledgment step.

### 2.4 Third-party voices captured incidentally → no clean consent mechanism exists
There is no practical way for Wake Mate to obtain consent from a bystander recorded in the background of someone else's Alarm Call. The standard mitigation used across the industry is a **point-of-recording notice** ("Only record yourself, or people who've agreed to be recorded") shifting responsibility to the recording user as a data controller for that specific act, similar to how the EDPB frames personal/household-use video recording as generally outside GDPR's direct controllership until the platform stores/transmits it (EDPB Guidelines 3/2019 on video devices, cited above). This does not eliminate Wake Mate's own processor/controller obligations once the file is uploaded to Wake Mate's servers — it only addresses the consent gap for the *content* itself.

### 2.5 Marketing communications → **Separate opt-in consent, Art. 6(1)(a)**
If Wake Mate ever sends marketing (as opposed to transactional/service) notifications, that requires its own unbundled, freely-given consent, separate from the account-creation flow — standard Art. 6(1)(a)/Art. 7(4) practice (Art. 7(4) is the "freely given" test referenced across ICO/EDPB consent guidance).

### 2.6 Friend Connection acceptance (mutual accept)
Not itself a GDPR consent artifact — it's a product/social-graph feature — but note that **both parties' mutual acceptance is itself processing of a relationship data point about each of them**, which falls under the account's Art. 6(1)(b) contract-necessity basis (the friend graph is core functionality), not a separate consent event.

---

## 3. Encryption Expectations

GDPR Art. 32(1) requires "appropriate technical and organisational measures" and explicitly lists **"the pseudonymisation and encryption of personal data"** as an example measure, calibrated to "the state of the art, the costs of implementation and the nature, scope, context and purposes of processing" ([gdpr-info.eu/art-32-gdpr](https://gdpr-info.eu/art-32-gdpr/)). GDPR does not mandate a specific algorithm or key length — the following are industry-standard practices used to satisfy Art. 32's "state of the art" test, not GDPR-specified requirements.

### 3.1 In transit — TLS
- Cloudflare's own SSL/TLS documentation recommends **TLS 1.3** generally, describes **TLS 1.2** as the current baseline required for PCI compliance since June 2018, and treats TLS 1.0/1.1 as legacy/only for narrow compatibility cases ([developers.cloudflare.com/ssl/reference/protocols](https://developers.cloudflare.com/ssl/reference/protocols/)).
- **Recommendation for Wake Mate:** enforce TLS 1.2 minimum on all API/upload/download endpoints, prefer TLS 1.3 where the backend/CDN supports it.

### 3.2 At rest — object storage & database
- **AWS S3**: since January 5, 2023, S3 applies **server-side encryption with Amazon S3-managed keys (SSE-S3)** automatically to all new object uploads by default, with no extra cost or configuration; **SSE-KMS** is available for more controlled key management ([docs.aws.amazon.com/AmazonS3/.../UsingKMSEncryption.html](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html)).
- **Google Cloud Storage**: encrypts all data at rest by default using **AES-256** (Galois/Counter Mode in most cases), with no setup required, plus optional customer-managed (CMEK) or customer-supplied (CSEK) keys for additional control ([docs.cloud.google.com/storage/docs/encryption/default-keys](https://docs.cloud.google.com/storage/docs/encryption/default-keys)).
- **AES algorithm standard**: AES-128/192/256 is specified by **NIST FIPS 197**, the US federal standard for the Advanced Encryption Standard, most recently updated in 2023 (editorial-only changes; the algorithm itself is unchanged since 2001) ([csrc.nist.gov/pubs/fips/197/final](https://csrc.nist.gov/pubs/fips/197/final); [nist.gov news on the 2023 update](https://www.nist.gov/news-events/news/2023/05/nist-updates-fips-197-advanced-encryption-standard-aes)).
- **Recommendation for Wake Mate:** whichever cloud provider is chosen (backend is TBD), default provider-managed AES-256 at-rest encryption for both the audio-file object store and the application database is sufficient to meet Art. 32 expectations at MVP scale; customer-managed keys (SSE-KMS/CMEK) are a reasonable upgrade once handling data at larger scale or under enterprise contractual requirements, not an MVP blocker.

---

## 4. Deletion Window Recommendation for the Temporary Cloud Copy

### 4.1 The governing principles
- **Art. 5(1)(c) — data minimisation**: personal data must be "adequate, relevant and limited to what is necessary" ([gdpr-info.eu/art-5-gdpr](https://gdpr-info.eu/art-5-gdpr/)).
- **Art. 5(1)(e) — storage limitation**: personal data must be "kept ... for no longer than is necessary for the purposes for which [it is] processed" (same source).

Applied to Wake Mate: the cloud copy of an Alarm Call exists **solely** to bridge sender-device → recipient-device transfer. Once the recipient has downloaded it, the cloud copy has no further purpose and Art. 5(1)(e) argues for prompt deletion. The only reason to keep it *at all* after download-confirmation is defensive (retry on a failed/partial download), and the only reason to keep it before download is to give the recipient's device a real-world chance to come online.

### 4.2 Comparable services' retention windows
| Service | Window | Source |
|---|---|---|
| WeTransfer (free/Starter tier) | **3 days** from the moment the transfer is sent; files permanently removed after expiry | [wetransfer.com/help-center/how-to/transfer-availability](https://wetransfer.com/help-center/how-to/transfer-availability) |
| WeTransfer (via someone's branded page) | 30 days | same source |
| Firefox Send (discontinued 2020) | Default: **1 download or 24 hours**, whichever first; configurable up to 100 downloads / 7 days; minimum as low as 5 minutes | [Wikipedia: Firefox Send](https://en.wikipedia.org/wiki/Firefox_Send) (secondary summary of Mozilla's now-removed product documentation, included per task allowance for comparable-service retention practices — Mozilla's own docs are no longer live since discontinuation) |
| Signal | Attachments are deleted from Signal's servers as soon as the recipient device confirms retrieval; if never retrieved, **servers auto-delete after 45 days** | search-aggregated technical summaries of Signal's architecture (no single official Signal doc page was retrievable at fetch time; treat the 45-day figure as directionally correct but re-verify against Signal's current server source/docs before quoting externally) |

### 4.3 Recommendation: **48 hours**
Reasoning:
- Wake Mate's use case (a friend downloading an alarm clip meant to wake them up the next morning) is time-sensitive by design — unlike WeTransfer/Firefox Send's general-purpose "any file, whenever," a Wake Mate recipient has a strong practical incentive to open the app and download before the *next* time their alarm needs to fire, which is a same-day or next-day event by definition.
- 48 hours covers a full day-night cycle even if the recipient doesn't open the app the same day they receive it (e.g., they're asleep, traveling, or the alarm isn't due to fire for another day), while still being meaningfully shorter than WeTransfer's 3-day free-tier default — appropriate given Wake Mate is handling a **voice recording**, which is more clearly personal/identifying than an arbitrary file transfer, so a *tighter* minimisation posture than a generic file-sharing tool is justified under Art. 5(1)(c)/(e).
- **Implementation detail worth specifying regardless of the exact number chosen:** delete on the earlier of (a) confirmed successful download by the recipient device, or (b) the fixed expiry window — this satisfies storage limitation more precisely than a flat timer alone, and mirrors Signal's "delete on confirmed retrieval, else timeout" pattern.

---

## 5. Other Relevant GDPR Concepts

### 5.1 Right to erasure (Art. 17)
Full text and conditions: [gdpr-info.eu/art-17-gdpr](https://gdpr-info.eu/art-17-gdpr/). Grounds include withdrawal of consent, data no longer necessary for its original purpose, and unlawful processing; exceptions include legal obligations and defence of legal claims.

**Friend graph:** Erasure of an account should cascade to remove that user's edges in the friend graph — but the *other* party's own account/data is not erased; only the relational link (and the erased user's own visible presence) needs to go. This is a data-model design point (cascading delete on the edge, not a shared/joint record) rather than a legal ambiguity.

**Alarm Calls already downloaded to a friend's device:** This is the genuinely hard case. GDPR's erasure right binds a **controller's own systems** — the ICO's right-to-erasure guidance confirms that where personal data has been *disclosed to third parties*, the controller's obligation is to take reasonable steps to **inform** those recipients of the erasure request (and, per Art. 17(2), where data was made public, take reasonable steps to inform other controllers) — not to reach into and delete data that now lives on a third party's own device outside the controller's infrastructure ([ico.org.uk — right to erasure](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/individual-rights/individual-rights/right-to-erasure/), corroborated via search-indexed ICO guidance text; direct fetch of this page returned HTTP 403 at research time, so re-verify by visiting the page directly before citing externally). **Practical implication for Wake Mate:** "erasure" of an Alarm Call can only reliably mean: delete the sender's local copy (already exists, no server dependency), delete the temporary cloud copy (already the plan), and remove it from the recipient's in-app Library/Queue *the next time their client syncs* — Wake Mate has no mechanism (and GDPR does not require one) to force-delete a file already resident on a friend's phone if that friend's device is offline or the app is deleted. This should be documented plainly in-product ("removing this alarm call removes it from your account; anyone who already downloaded it may still have their own copy") rather than implied to be a full remote wipe.

### 5.2 Right to data portability (Art. 20)
Full text: [gdpr-info.eu/art-20-gdpr](https://gdpr-info.eu/art-20-gdpr/). Applies only where processing (a) is based on consent (Art. 6(1)(a)/9(2)(a)) or contract (Art. 6(1)(b)), **and** (b) is carried out by automated means; the right covers data the subject "has provided" to the controller, in a "structured, commonly used and machine-readable format," transmittable to another controller. For Wake Mate this would cover: account profile data, the user's own uploaded/recorded Alarm Calls (audio files export cleanly as a portable format already), and their friend-list contents — but not data Wake Mate has derived/inferred (e.g., internal queue-ordering logic), since portability applies to data "provided," not derived data.

### 5.3 Cross-border data transfer (Chapter V, Art. 44–49)
If a US-based cloud provider is used and data leaves the EU/EEA, GDPR Chapter V applies. Its mechanisms, per the article list itself ([gdpr-info.eu/chapter-5](https://gdpr-info.eu/chapter-5/)):
- **Art. 45 — adequacy decision**: transfers to a country the European Commission has formally deemed "adequate" need no further safeguard.
- **Art. 46 — appropriate safeguards** (this is where **Standard Contractual Clauses**, SCCs, live): used when no adequacy decision covers the destination.
- **Art. 49 — derogations**: narrow, situational exceptions (not a scalable basis for routine transfers).

**Current adequacy status for the US:** The European Commission adopted the **EU-US Data Privacy Framework (DPF)** adequacy decision on 10 July 2023 (Decision (EU) 2023/1795), covering data transfers to US companies that have self-certified participation in the DPF ([ec.europa.eu press release — new adequacy decision for safe and trusted EU-US data flows](https://ec.europa.eu/commission/presscorner/detail/en/ip_23_3721)). This adequacy decision was legally challenged; on **3 September 2025** the EU General Court dismissed the annulment action and upheld the adequacy decision as currently valid, though the ruling remains open to appeal to the CJEU within two months and ten days of the judgment (per multiple law-firm summaries of the judgment — no single official Commission or Court press release URL was fetched directly during this research; recommend checking curia.europa.eu for the judgment text before relying on this for legal argument). **Practical implication:** a US cloud provider certified under the DPF (e.g., AWS, GCP, Azure all maintain DPF certification for relevant services) currently has a valid adequacy basis for EU-to-US transfers, but this is an area of ongoing litigation risk (this is the third framework in this lineage after Safe Harbor and Privacy Shield were both struck down by the CJEU in Schrems I and Schrems II) — SCCs remain the fallback safeguard (Art. 46) if DPF adequacy is ever invalidated again, and choosing **EU-region hosting** (both AWS and GCP offer EU regions with in-region data residency) sidesteps the Chapter V analysis entirely. Given the backend is still TBD, defaulting to an EU region for any EU-user data is the simplest way to avoid this dependency on DPF's continued survival.

---

## Sources index (primary/high-trust only)

- GDPR article text: gdpr-info.eu (Art. 4, 5, 6, 9, 17, 20, Chapter V) — unofficial but verbatim mirror of the official Regulation (EU) 2016/679 text
- EDPB: Guidelines 02/2021 on Virtual Voice Assistants; Guidelines 3/2019 on video devices; Guidelines 1/2024 on Art. 6(1)(f) legitimate interest — edpb.europa.eu
- ICO: What is special category data?; Biometric recognition guidance; Right to erasure guidance — ico.org.uk
- European Commission: EU-US Data Privacy Framework adequacy decision press release — ec.europa.eu
- AWS: S3 server-side encryption documentation — docs.aws.amazon.com
- Google Cloud: default encryption at rest documentation — docs.cloud.google.com
- NIST: FIPS 197 (AES) — csrc.nist.gov, nist.gov
- Cloudflare: TLS protocol documentation — developers.cloudflare.com
- WeTransfer: transfer availability help page — wetransfer.com

**Caveats to re-verify before external use:** (1) ICO right-to-erasure page and EDPB VVA PDF could not be directly fetched during this research (403/binary-parse errors) — content above is corroborated via search-index summaries of those exact pages, not a direct read; re-fetch before quoting in a legal document. (2) The Signal 45-day server retention figure and the September 2025 General Court DPF ruling details are sourced from aggregated secondary summaries, not a single official primary document read in full — treat as directionally reliable, re-verify against Signal's own docs and the Court's judgment text (curia.europa.eu) respectively before relying on them in anything client-facing.
