Status: resolved
Type: research

## Question

Survey backend/storage/auth options suited to Wake Mate's needs: local-first audio storage on-device, a temporary expiring cloud transfer for sharing (upload → download link → delete after a short window), user auth, push notifications, and a small team building a 4-week prototype. Compare BaaS options (Firebase, Supabase, AWS Amplify) against a custom backend (e.g. Node/Postgres + S3), covering cost, iOS SDK maturity, ease of implementing expiring-object storage, auth options (including Sign in with Apple), and push notification support.

## Answer

Full findings, cost breakdowns, and citations: [`research/08-backend-storage-auth-stack-survey-findings.md`](../research/08-backend-storage-auth-stack-survey-findings.md).

**Recommendation: Firebase** (Auth + Firestore/Storage + Cloud Functions + FCM) is the best fit for a 4-week solo/small-team iOS prototype. It's the only option combining a mature native Swift SDK, first-class Sign in with Apple (native ID-token handoff), and a zero-setup FCM→APNs push bridge — and it's effectively $0/month at 100–1,000 users.

Runner-up: **Supabase** has an arguably even cleaner native Sign in with Apple flow and a Postgres/SQL foundation, but has **no managed push notification service at all** — APNs would have to be hand-built, which is exactly where Firebase saves the most time under this deadline. **AWS Amplify** has all the right pieces (Cognito, S3 lifecycle rules, SNS/Pinpoint) but spreads them across more services with more setup surface, and its Swift SDK sits on a still-"developer preview" underlying AWS SDK for Swift. A **custom backend** is the weakest fit for a 4-week timeline specifically because it requires building, from scratch, the two things every managed platform gives away for free: Apple ID-token verification and APNs delivery.

Key tradeoffs/risks of the Firebase pick:
- No native short-TTL storage primitive — GCS lifecycle rules are day-granularity only, so the "minutes to a day" expiry window still needs a custom scheduled Cloud Function (using Admin-SDK signed URLs, not the client SDK's permanent `getDownloadURL()`).
- Real vendor lock-in: Firestore's data model and Firebase Auth's user-identifier format are Google-proprietary; migrating off later means rewriting the data layer, not swapping a config value.
- Metered billing (Firestore/Storage/Functions) is less predictable at scale than Supabase's flat $25/month Pro tier or a fixed-price VPS.
- Must enable Blaze (billing account) almost immediately, since scheduled Cloud Functions (needed for the cleanup job) aren't available on the free Spark plan.
- GDPR data residency (Firestore/Storage region) must be deliberately chosen at project-creation time.

This is a survey only — the final stack choice is locked in ticket 09 with the human.
