# Backend / Auth / Storage Stack Survey — Wake Mate

**Research date:** 2026-09-05
**Scope:** Compare Firebase, Supabase, AWS Amplify, and a custom Node/Express + Postgres + S3-compatible backend for Wake Mate — an iOS-first social-alarm app where the core mechanic is: record locally → upload "Alarm Call" audio to temporary cloud storage → send recipient a time-limited download link → recipient downloads and stores locally → cloud copy auto-deletes after a short window (minutes to a day). Solo/small-team, ~4-week prototype timeline.

**Verification note:** All pricing and capability claims below were checked against live official docs/pricing pages fetched during this research session (September 2026) unless explicitly marked otherwise. Where a live fetch returned incomplete data (e.g., pricing tables rendered as non-text widgets), that is flagged inline and training-knowledge figures are marked as **not independently verified against live docs as of this research**.

---

## 1. Firebase (Auth + Firestore/Storage + Cloud Functions + FCM)

### Cost at small scale
Firebase's free **Spark** plan and pay-as-you-go **Blaze** plan, per the [official pricing page](https://firebase.google.com/pricing):

- **Firestore (Spark/free):** 1 GiB total storage, 50K reads/day, 20K writes/day, 20K deletes/day, 10 GiB/month network egress.
- **Cloud Storage for Firebase (Spark/free):** modern (`*.firebasestorage.app`) buckets get 5 GB‑months storage and 100 GB/month downloads free (legacy `*.appspot.com` buckets: 5 GB storage, 1 GB/day downloads).
- **Cloud Functions (Blaze):** first 2,000,000 invocations/month free, then $0.40/million; first 5 GB/month outbound networking free, then $0.12/GB. (Spark plan cannot use most Functions triggers — Blaze, i.e. a billing account, is required for anything beyond simple HTTPS callable stubs.)
- **Firebase Auth:** 50,000 MAU free for email/social sign-in (including Sign in with Apple), 50 MAU free for SAML/OIDC federation.
- **Cloud Messaging (FCM):** free, unlimited, on both plans.
- **Blaze storage overage:** ~$0.026/GB stored, ~$0.12–0.15/GB downloaded beyond free tier (legacy-bucket rate; modern buckets bill at standard Google Cloud Storage regional rates).

**Estimated monthly cost at 100–1,000 users, light audio sharing:** effectively **$0**. At this scale (a few thousand short audio uploads/downloads a month, well under a few MB each), you stay inside the Spark/Blaze free quotas for Storage, Firestore, Functions invocations, and Auth MAU. You must be on Blaze (billing enabled) to use scheduled Cloud Functions for cleanup, but usage will sit inside the free allowances, so the bill should still round to $0–a few dollars. Real cost risk only appears past ~50K MAU or high per-user daily send volume.

### iOS SDK maturity/quality
Firebase ships an official, actively maintained **Swift-native SDK** ([firebase-ios-sdk](https://firebase.google.com/docs/auth/ios/start), distributed via SPM/CocoaPods), one of the most mature third-party iOS SDKs in the industry (in production since ~2016). Documentation is extensive with iOS-specific guides for Auth, Firestore, Storage, Functions, and FCM, plus first-party FirebaseUI for the sign-in flow (see [Get Started with Firebase Authentication on Apple Platforms](https://firebase.google.com/docs/auth/ios/start)).

### Auto-expiring object storage
No built-in short-TTL/lifecycle feature suitable for "minutes to a day" expiration:
- Cloud Storage for Firebase buckets are backed by Google Cloud Storage, whose **Object Lifecycle Management** only supports **day-granularity** conditions — "age" is measured in whole days, midnight-UTC boundaries, and lifecycle changes can take up to 24 hours to take effect ([Cloud Storage lifecycle docs](https://docs.cloud.google.com/storage/docs/lifecycle)). This is too coarse for a "minutes to a day" expiry window.
- Client-SDK `getDownloadURL()` produces a **permanent**, non-expiring public URL (revocable only by rotating a token) — not a temporary link by itself.
- To get true temporary links, you must use the **Admin SDK's signed URL** capability (GCS `getSignedUrl`, expiry set programmatically) at upload time, and to auto-delete you must write your own **scheduled Cloud Function** (`onSchedule`, backed by Cloud Scheduler — $0.10/month per job past 3 free jobs) that queries for expired objects and deletes them ([Firebase scheduled functions docs](https://firebase.google.com/docs/functions/schedule-functions)).
- **Verdict:** fully achievable, but it's a roll-your-own cleanup job on top of signed URLs — no native short-TTL primitive.

### Sign in with Apple support
First-class: Firebase Authentication has a dedicated Apple provider in the console, and native iOS integration uses Apple's own `AuthenticationServices`/`SignInWithAppleButton` to get an ID token which is then handed to the Firebase Auth SDK to mint a Firebase user session ([Firebase iOS Auth start guide](https://firebase.google.com/docs/auth/ios/start)). Well-trodden, heavily documented pattern.

### Push notification support
Native, first-party: **FCM is Google's own bridge to APNs** for Apple platforms — you upload an APNs auth key (.p8) once, and FCM handles token exchange and delivery to APNs on your behalf; the app registers for remote notifications and passes its APNs token to the Messaging SDK ([FCM iOS get-started docs](https://firebase.google.com/docs/cloud-messaging/ios/get-started)). This is the least amount of custom plumbing of any option here.

---

## 2. Supabase (Auth + Postgres + Storage + Edge Functions)

### Cost at small scale
Per the [official pricing page](https://supabase.com/pricing):

- **Free tier:** 500 MB Postgres database, 1 GB file storage, 5 GB egress + 5 GB cached egress, 50,000 MAU, 500,000 Edge Function invocations/month, 2 active projects, 200 concurrent Realtime connections. **Free projects pause after a week of inactivity** — a real risk for an intermittently-used prototype/demo.
- **Pro plan ($25/month base):** 8 GB database (then $0.125/GB), 100 GB file storage (then $0.0213/GB), 250 GB egress (then $0.09/GB) + 250 GB cached egress (then $0.03/GB), 100,000 MAU (then $0.00325/MAU), 2,000,000 Edge Function invocations (then $2/million). Includes $10/month compute credit covering one Micro compute instance; more compute costs extra.

**Estimated monthly cost at 100–1,000 users, light audio sharing:** Free tier likely holds for the low end of this range if the auto-delete job is working (files don't accumulate) and daily active use is light — 1 GB storage and 5 GB egress are the tightest constraints, but since files are meant to be deleted quickly, standing storage stays small. The **pause-after-a-week-of-inactivity** behavior on the free tier is the main practical gotcha for a demo/prototype that isn't used continuously. For a "real" always-on prototype serving up to ~1,000 users you would likely want the **$25/month Pro plan** to avoid pausing and get headroom on egress/compute — still cheap.

### iOS SDK maturity/quality
Official, first-party **Swift SDK** — [`supabase/supabase-swift`](https://github.com/supabase/supabase-swift) — covering Postgres queries, Realtime, Storage upload/download, Auth, and Edge Function invocation, explicitly "officially supported by Supabase" and packaged for SPM across iOS/macOS/watchOS/tvOS/visionOS ([Supabase iOS/SwiftUI quickstart](https://supabase.com/docs/guides/getting-started/quickstarts/ios-swiftui)). Newer than Firebase's SDK (Supabase itself launched 2020, general availability of native mobile/Apple auth flows landed later, per [Supabase's native mobile auth announcement](https://supabase.com/blog/native-mobile-auth)) — actively developed, but with a shorter production track record than Firebase's.

### Auto-expiring object storage
No built-in object-level TTL/lifecycle rule either — this is a DIY pattern similar to Firebase, but Postgres-native and arguably easier to reason about for a solo dev:
- **Signed URLs** are first-class and simple: `createSignedUrl(path, expiresIn)` takes an expiry in **seconds** (e.g., `60` for a 1-minute link) ([Supabase Storage API reference](https://supabase.com/docs/reference/javascript/storage-from-createsignedurl)) — directly matches the "minutes to a day" requirement with fine granularity, unlike GCS/S3 lifecycle rules.
- **Auto-delete** requires a scheduled job: Supabase enables **pg_cron** by default on all plans (free, Pro, Team), so a cron job (e.g., every few minutes) can call a SQL function or Edge Function that finds and deletes expired rows/objects from `storage.objects` based on an `expires_at` timestamp you store in object metadata. This pattern is documented informally in Supabase's own community discussions ("Expiring objects (Storage)" and "A day auto storage delete" GitHub Discussions threads) rather than a single canonical how-to page, but the building blocks (pg_cron + storage.objects metadata + delete API) are all first-party and well understood.
- **Verdict:** same "roll your own cleanup job" story as Firebase, but the signed-URL expiry granularity is finer out of the box, and pg_cron is arguably a more natural fit for a dev already comfortable with SQL/Postgres than standing up a separate serverless scheduled function.

### Sign in with Apple support
First-class and, for native iOS specifically, notably clean: per [Supabase's Login with Apple docs](https://supabase.com/docs/guides/auth/social-login/auth-apple), native apps (iOS/macOS/watchOS/tvOS) use Apple's `AuthenticationServices` to get an ID token directly and hand it to Supabase Auth, **bypassing the OAuth web-redirect flow entirely** — simpler than the OAuth-based web flow, and native-only setups don't require the twice-yearly `.p8` secret-key rotation that OAuth-flow configs need. This is arguably the most native-feeling Sign in with Apple implementation of the three managed platforms.

### Push notification support
**No built-in push/APNs bridge.** Supabase does not offer an FCM- or Pinpoint-style managed push service; push notifications must be wired up manually — typically via a Supabase Edge Function (Deno-based) that calls Apple's APNs HTTP/2 API directly with your own `.p8` auth key, triggered by a Postgres trigger/webhook or pg_cron job when a new Alarm Call row is inserted. This is the same amount of DIY work as the custom-backend option for this specific feature — Supabase gives you no shortcut here, only better plumbing (triggers, Edge Functions, cron) to build it with.

---

## 3. AWS Amplify (Cognito + DynamoDB/S3 + Lambda + SNS/Pinpoint)

### Cost at small scale
AWS Amplify is a thin hosting/build-tooling + client-library layer; the backend primitives (Cognito, S3, Lambda, DynamoDB, SNS/Pinpoint) are billed separately at standard AWS rates ([Amplify pricing page](https://aws.amazon.com/amplify/pricing/)):

- **Amplify Hosting/build:** 1,000 free build minutes/month, 5 GB free CDN storage, 15 GB free data transfer/month; beyond that $0.01/build-minute (standard), $0.023/GB storage, $0.15/GB data transfer out.
- **Cognito (User Pools), current tiers** per [Cognito pricing](https://aws.amazon.com/cognito/pricing/): the **Essentials** tier gives 10,000 free MAU/month for direct or social sign-in (e.g., Sign in with Apple), then $0.015/MAU; a **Lite** tier (grandfathered for accounts created before Nov 22, 2024) gives 50,000 free MAU. SAML/OIDC federation is a much smaller 50 free MAU regardless of tier, then $0.015/MAU.
- **S3:** Standard storage $0.023/GB/month (first 50 TB, us-east-1) — [S3 pricing](https://aws.amazon.com/s3/pricing/); first 100 GB/month of data transfer out is free across all AWS services combined.
- **SNS mobile push (APNs):** first 1,000,000 mobile push notifications/month free, then ~$0.50/million ([SNS pricing](https://aws.amazon.com/sns/pricing/) — the pricing page itself doesn't break out the mobile-push free-tier figure in fetchable text; this specific number is corroborated by secondary sources and AWS's general Always-Free-Tier messaging, so treat it as **not independently verified against live docs as of this research** for the exact mobile-push figure, though the general SNS request/delivery pricing model is confirmed live).
- Lambda has its own generous perpetual free tier (1M requests + 400,000 GB-seconds/month) not itemized here but standard across AWS accounts.

**Estimated monthly cost at 100–1,000 users, light audio sharing:** Should be very close to **$0/month**, comfortably inside Cognito's 10K MAU Essentials free tier, S3's storage/transfer free tier for the small file volumes described, and SNS's push free tier. The main new cost vs. Firebase/Supabase is that you're assembling several separate AWS services (Cognito + S3 + Lambda + SNS/Pinpoint + possibly DynamoDB) rather than one bundled product, each with its own billing line — cost stays low, but line-item bookkeeping/complexity is higher.

### iOS SDK maturity/quality
Official **Amplify Library for Swift** ([amplify-swift](https://github.com/aws-amplify/amplify-swift), docs at [docs.amplify.aws](https://docs.amplify.aws/gen1/swift/sdk/)) is AWS's recommended path for native iOS, GA status, supports iOS 13+/macOS 10.15+, uses Swift Concurrency (async/await). However, the **older AWS Mobile SDK for iOS** (`aws-sdk-ios`) reaches **end of support August 1, 2026** — meaning any tutorial/example still referencing the legacy SDK is now a dead end, and you must build specifically on Amplify Swift v2 / AWS SDK for Swift. AWS SDK for Swift itself is still noted as in "developer preview" underneath Amplify v2 in some docs, which is a maturity yellow flag relative to Firebase's and Supabase's SDKs. Overall: functional and officially maintained, but historically the most churn-prone of the three managed platforms on iOS (multiple generations: classic SDK → Amplify Gen 1 → Amplify Gen 2 / Swift v2), and the ecosystem is generally considered more web/React-oriented than iOS-first.

### Auto-expiring object storage
Two complementary native building blocks, but combining them for **sub-day** TTLs still needs custom work:
- **S3 Lifecycle configuration** natively supports **expiration actions** that auto-delete objects on Amazon's own schedule with no code required ([S3 Object Lifecycle Management docs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html)) — this is a genuine built-in TTL feature, unlike Firebase/Supabase. However, like GCS, S3 Lifecycle rules operate at **day granularity** (age in days) — fine for a "1 day" expiry, not fine enough for "a few minutes."
- **Presigned URLs** (via the S3 SDK) give you time-limited download links with fine-grained expiry (seconds up to 7 days for SigV4), covering the "minutes" case for the *link*, but that only controls link validity — the underlying object still needs the day-granularity Lifecycle rule (or a custom Lambda cron via EventBridge Scheduler) to actually get deleted quickly.
- **Verdict:** for exactly "1 day" expiry, S3 Lifecycle is a genuine no-code fit — the strongest native TTL story of the four options. For "a few minutes to an hour," you still need a scheduled Lambda (EventBridge Schedule → Lambda → `DeleteObject`), i.e., the same DIY cleanup job pattern as Firebase/Supabase.

### Sign in with Apple support
Native, first-class as a Cognito **federated identity provider**: Cognito User Pools supports "Sign in with Apple" as a built-in social/OIDC provider — you configure the Apple Services ID, Team ID, Key ID, and private key in the Cognito console, and Cognito's Hosted UI / token flow handles the rest, normalizing Apple's tokens into standard Cognito user-pool tokens ([Cognito federation docs](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-identity-federation.html); see also AWS's own walkthrough, ["How to set up Sign in with Apple for Amazon Cognito"](https://aws.amazon.com/blogs/security/how-to-set-up-sign-in-with-apple-for-amazon-cognito/)). Solid, but historically leans on Cognito's Hosted UI (web-view-based) more than a fully native on-device Apple `AuthenticationServices` flow — native flows are achievable but require more manual wiring (custom Lambda triggers/token exchange) than Firebase's or Supabase's direct native-ID-token handoff.

### Push notification support
Native, first-class, **no bridge needed**: both **SNS Mobile Push** and **Amazon Pinpoint** talk to APNs directly — you configure an APNs channel with your `.p8` signing key (Team ID/Key ID), and AWS handles token-based HTTP/2 authentication to Apple on every send ([Pinpoint APNs channel docs](https://docs.aws.amazon.com/pinpoint/latest/apireference/apps-application-id-channels-apns.html); [Pinpoint push settings guide](https://docs.aws.amazon.com/pinpoint/latest/userguide/settings-push.html)). Equivalent in directness to Firebase's FCM→APNs bridge, though AWS splits this across two overlapping services (SNS vs. Pinpoint/"AWS End User Messaging"), which adds a small "which one do I use" decision cost that Firebase doesn't have.

---

## 4. Custom backend (Node/Express + Postgres + S3-compatible storage)

### Cost at small scale
No platform pricing page applies — cost is whatever infrastructure you choose, e.g.:
- Compute: a small managed Postgres + a Node/Express host (Render/Fly.io/Railway/a $5–20/month VPS) — realistically **$10–40/month** minimum just to keep something always-on for auth/API/push-trigger logic, even at near-zero traffic, because there's no serverless-style "free tier that scales to zero" the way Firebase/Supabase/Amplify give you by default.
- Storage: S3 (or R2/B2) billed the same as the AWS Amplify section above ([S3 pricing](https://aws.amazon.com/s3/pricing/)) — negligible at this scale given files are deleted quickly.
- **Estimated monthly cost at 100–1,000 users:** roughly **$15–50/month** — higher *floor* than the managed platforms (which can run near $0 at this scale), because you're paying for always-on compute rather than consumption-based serverless billing, even though marginal usage-based costs (storage, transfer) are comparably small.

### iOS SDK maturity/quality
There is no SDK — the client talks to your own REST/GraphQL API over `URLSession` (or a thin wrapper like Alamofire). This means: no vendor SDK bugs/versioning/churn to track, but also **zero built-in functionality** — you write and maintain the networking layer, token storage/refresh, retry/offline handling, and pagination yourself. Quality and "maturity" here is entirely a function of your own code, not a third party's.

### Auto-expiring object storage
Same S3 (or S3-compatible: Cloudflare R2, Backblaze B2) primitives as the Amplify option — **S3 Lifecycle expiration rules** are available natively if the storage backend is genuine S3 ([S3 lifecycle docs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html)), giving day-granularity auto-delete for free with zero cleanup-job code. For finer (sub-day/minutes) expiry, or if using a non-S3 object store without lifecycle rules, you write your own scheduled job (cron, a queue consumer, or a simple `setTimeout`/delayed-job pattern backed by Postgres) that deletes both the object and any DB pointer row once `expires_at` passes, and generate presigned GET URLs at share-time with your own TTL (seconds-level control via the AWS SDK). This is the most "manual" of the four but also the most flexible/fully-understood — nothing hidden behind a managed product's cleanup semantics.

### Sign in with Apple support
Fully manual OIDC wiring against Apple's own APIs. Per [Apple's Sign in with Apple developer docs](https://developer.apple.com/documentation/sign_in_with_apple), the native iOS side uses `AuthenticationServices` (`ASAuthorizationAppleIDProvider`) to obtain an identity token client-side (same as every other option) — but your **server** must independently: verify the JWT signature against Apple's published public keys, validate `iss`/`aud`/`exp`/`iat` claims, extract and persist the stable `sub` (user identifier), and handle Apple's refresh-token/token-revocation endpoints yourself. Well-documented, but genuinely the most backend work of the four options — every other platform (Firebase, Supabase, Cognito) does this verification for you.

### Push notification support
Fully DIY APNs integration: your server needs to talk to Apple's APNs HTTP/2 API directly (typically via a library like `node-apn` or a raw HTTP/2 client), using a `.p8` auth key (Team ID/Key ID) to sign JWT auth tokens per Apple's APNs provider API. No managed bridge — you own certificate/key rotation, per-device-token bookkeeping, retry/backoff on APNs error codes (e.g., `BadDeviceToken`), and sandbox-vs-production endpoint routing. Doable in a few hours with a mature library, but it's real work in a 4-week timeline that every managed alternative gives you for free or near-free.

---

## Comparison Summary

| | Firebase | Supabase | AWS Amplify | Custom (Node+Postgres+S3) |
|---|---|---|---|---|
| **Cost @ 100–1,000 users, light usage** | ~$0 (Spark/Blaze free tiers) | ~$0 free tier; $25/mo Pro to avoid week-of-inactivity pause | ~$0 (Cognito 10K MAU free, S3/SNS free tiers) | ~$15–50/mo floor (always-on compute; no scale-to-zero) |
| **iOS SDK** | Native Swift SDK, very mature, SPM/CocoaPods, excellent docs | Native Swift SDK, official, newer but active, good docs | Native Swift SDK (Amplify v2), GA but built on a still-preview AWS SDK for Swift; legacy SDK EOL Aug 2026 | None — raw `URLSession`, you own everything |
| **Auto-expiring storage** | No native short TTL; day-granularity GCS lifecycle only; needs signed URLs (Admin SDK) + custom scheduled Cloud Function for cleanup | No native TTL; fine-grained signed-URL expiry (seconds) is built in; needs pg_cron job for cleanup — SQL-native, arguably simplest DIY | **S3 Lifecycle gives native day-granularity auto-delete for free**; sub-day TTL still needs a scheduled Lambda | Same S3 Lifecycle option as Amplify if using real S3; otherwise fully custom cron/queue job |
| **Sign in with Apple** | First-class, native ID-token handoff to Firebase Auth | First-class; native flow bypasses OAuth entirely, no periodic secret rotation needed — cleanest native story | First-class as a Cognito federated IdP; more console/Lambda-trigger wiring, leans on Hosted UI | Fully manual: verify JWT, claims, `sub`, refresh/revocation yourself |
| **Push (APNs)** | Native FCM→APNs bridge, upload one `.p8`, done | **No managed push at all** — same DIY APNs work as custom backend, just triggered via Edge Functions/pg_cron | Native SNS/Pinpoint→APNs bridge, upload one `.p8`, done (two overlapping AWS services to choose between) | Fully manual APNs HTTP/2 integration (e.g., `node-apn`), own key/token/retry handling |
| **Time-to-first-prototype (4-week lens)** | Fastest — one console, one SDK, batteries included | Fast — one SDK, SQL you already know, but push is a gap | Moderate — most capable but most services to wire together, more AWS console surface area | Slowest — you build auth verification and push from scratch on top of everything else |

---

## Recommendation

**Firebase is the best fit for a 4-week solo/small-team iOS prototype of Wake Mate.** It is the only option of the four that gives you native Sign in with Apple, a native Swift SDK, and a zero-setup APNs push bridge (FCM) simultaneously, at effectively $0/month at this user scale, with the single most mature and widely-documented SDK of the four. Supabase is the strongest runner-up — its native Sign in with Apple flow is arguably even cleaner than Firebase's, and its Postgres/SQL foundation may suit a dev who prefers relational data — but it has **no managed push notification service at all**, meaning you'd have to hand-roll APNs integration under a 4-week deadline anyway, which is the one place Firebase saves you the most time. AWS Amplify has all the pieces (Cognito, S3 lifecycle, SNS/Pinpoint) but spreads them across more separate services with more console configuration and a Swift SDK story that is GA but sits on a still-"developer preview" underlying AWS SDK for Swift — more moving parts than a 4-week solo build should take on. A custom backend is the wrong choice for a prototype timeline specifically because it makes you build, from scratch, the two things every managed platform gives away for free: Apple ID-token verification and APNs delivery.

Key tradeoffs/risks of choosing Firebase:

- **No native short-TTL storage primitive.** Firebase Storage (GCS) lifecycle rules only operate at day granularity — Wake Mate's "minutes to a day" expiry window still requires you to write and test your own scheduled Cloud Function that finds and deletes expired files (and revokes their signed URLs), plus switch to Admin-SDK signed URLs instead of the client SDK's permanent `getDownloadURL()`. Budget real prototype time for this — it is not a checkbox in the console.
- **Vendor lock-in / migration cost.** Firestore's data model, Firebase Auth's user-identifier format, and Cloud Functions' trigger model are all Google-proprietary; migrating off Firebase later (e.g., if the product needs Postgres-grade relational queries, or hits cost/scale walls) means rewriting the data layer and auth-linking logic, not just swapping a config value.
- **Cost at real scale is non-trivial and less predictable than a flat-rate plan.** Firestore/Storage/Functions billing is metered per-operation; a viral spike in Alarm Call sharing (more reads/writes/egress than the free quotas) can produce a bill that's harder to forecast than Supabase's flatter $25/month Pro tier or a fixed-price VPS.
- **Requires enabling Blaze (a billing account) almost immediately**, since most Cloud Functions triggers (including the scheduled cleanup function this feature needs) are unavailable on the free Spark plan alone — "free" in practice means "free usage on a plan that requires a card on file," which is a minor but real setup/ops step to plan for in week 1.
- **GDPR/data-residency posture needs explicit configuration.** Firebase project data location (Firestore/Storage region) must be deliberately chosen at project-creation time to keep EU user data in-region; it's supported, but it's a decision you must make early and correctly, not a default you get for free.
