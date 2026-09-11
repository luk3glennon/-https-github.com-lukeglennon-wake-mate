# Push Notifications: Direct APNs (Supabase Edge Function) vs. Third-Party Push Service

Research date: all sources checked 2026-09-09 unless otherwise noted.

## Executive summary

For a solo-dev iOS app on Supabase, **hand-rolling APNs from a Supabase Edge Function is technically viable and reasonably low-risk**, but it is not the path Supabase's own docs demonstrate, and it requires bypassing the popular Node APNs libraries (`node-apn`, `apns2`) because they depend on Node's `node:tls`/`node:http2` modules, which throw under the Supabase/Deno edge runtime. The realistic implementation is a hand-rolled ES256 JWT (via Deno's Web Crypto or a Deno-compatible JWT lib like `djwt`) plus a plain `fetch()` POST to `https://api.push.apple.com` — Deno's `fetch` natively negotiates HTTP/2 over HTTPS, and Supabase only documents blocking outbound SMTP ports (25/587), not port 443, so there's no documented network blocker. On the third-party side, OneSignal is no longer a clearly "free" option for this use case: as of Sept/Oct 2026 its Free plan caps mobile push at 1,000 MAU org-wide, after which mobile push simply stops sending — a real ceiling a growing app could hit — though OneSignal does have a native Supabase integration pattern (sample Edge Function + REST API, not a Postgres-trigger-native product) and supports the modern `.p8` key. Pusher Beams, contrary to the pre-2026 general impression, still appears live and sold as of today (no sunset notice found on pusher.com or its docs), so it remains a candidate too, though its docs/roadmap content is stale (last major roadmap post from 2020) which is itself a signal worth weighing. Courier and Novu offer more generous/flexible free tiers (10,000 sends/month and 10,000 workflow runs/month respectively) than OneSignal's new 1,000-MAU cap, and Novu can also be self-hosted. Given Supabase's Database Webhooks (pg_net-based, well documented, first-class) can trigger an Edge Function on INSERT regardless of which path is chosen, the webhook plumbing is identical either way — the decision reduces to: accept OneSignal's new MAU ceiling, pay for/adopt Courier or Novu, or invest the (moderate but real) engineering effort of a hand-rolled Deno-native APNs client. For a small app expecting to stay under ~1,000 MAU for a while, OneSignal's free tier is still simplest; if growth past 1,000 MAU is likely, direct APNs or Courier/Novu look more durable.

---

## 1. Pusher Beams: active or sunset?

- **Status found: still an active, sold product as of 2026-09-09.** No deprecation, sunset, or end-of-life notice was found on Pusher's own marketing page, docs, or pricing page.
  - `https://pusher.com/beams/` — active marketing page, "Sign up for free" CTA present, SDK docs linked for Android/iOS/Web/Flutter. Checked 2026-09-09.
  - `https://pusher.com/docs/beams/` — docs still live, copyright footer reads "Copyright © 2026 Pusher Ltd. All rights reserved," no deprecation banner. Checked 2026-09-09.
  - `https://pusher.com/beams/pricing/` — pricing page live with 5 tiers (Sandbox, Startup, Pro, Business, Premium) and an active "Sign up for free" flow; no notice restricting new signups. Checked 2026-09-09.
  - Pusher's own deprecation policy (found via search of pusher.com) states Pusher issues an announcement before deprecating a service, followed by a 3-year sunset window — no such announcement was located for Beams specifically.
- **Caveat**: Pusher's own "product roadmap" blog post about Beams (`https://pusher.com/blog/our-product-roadmap-taking-channels-and-beams-to-even-greater-success/`) is dated **March 30, 2020** — i.e., the most recent Beams-specific strategy communication from Pusher that surfaced in search is over 6 years old. Combined with the fact that Pusher was acquired into MessageBird in Nov 2020, this suggests Beams is a legacy/maintenance-mode product even though it has not been formally sunset. No direct evidence either way on release cadence/active development was found — this would need a support ticket or changelog check to confirm investment level.
- Net: Beams should NOT be ruled out as "dead" — it appears purchasable and documented today — but its lack of recent public roadmap activity is a soft signal worth weighing against more actively-marketed alternatives (Courier, Novu, Knock) if comparing product momentum.

## 2. OneSignal: free tier, APNs setup, Supabase integration

**Free tier limits (mobile push):**
- Starting **September 1, 2026 for new customers** and **October 1, 2026 for existing customers**, OneSignal's Free plan caps mobile push + in-app messaging at **1,000 monthly active users (MAU) per organization**. Source: `https://documentation.onesignal.com/docs/en/billing-faq`, checked 2026-09-09.
- MAU counting rules (same source): any mobile subscription active in the last 30 days counts toward the 1,000 cap whether or not the user has opted into push; one person on 2 devices counts as 2; the limit is **org-wide**, aggregated across every app under the org, not per-app.
- Within the 1,000-MAU envelope, **sends are unlimited** (no per-notification cap) — confirmed via `https://onesignal.com/pricing`, checked 2026-09-09: "Free plan provides unlimited mobile push notifications for organizations with up to 1,000 monthly active users." Once MAU is exceeded, "mobile push and in-app messages stop sending until you upgrade" (per billing FAQ).
- Beyond 1,000 MAU, the next tier (Growth) is **$19/month + $0.012 per MAU** (per `onesignal.com/pricing`, checked 2026-09-09).
- Other channels (web push, email up to 10,000 sends/month, SMS trial) remain free/separate from the mobile MAU cap.

**APNs setup requirements:**
- OneSignal's recommended and documented method is the modern **.p8 Authentication Key** (token-based, ES256 JWT under the hood), configured at Settings > Push & In-App > Apple iOS (APNs) Settings, requiring the .p8 file plus Key ID, Team ID, and Bundle ID. Source: `https://documentation.onesignal.com/docs/en/ios-p8-token-based-connection-to-apns`, referenced via search, checked 2026-09-09.
- The .p8 key is Apple-account-wide (not per-app) and does not expire, vs. the older certificate-based (.p12) method which is app-specific and must be renewed. OneSignal's dashboard offers ".p8 Auth Key (Recommended)" as the primary path, implying **legacy .p12 certificate upload is still an available option** in their dashboard even though .p8 is pushed as the recommended default (standard OneSignal UI pattern; this specific detail should be double-checked directly in the OneSignal dashboard/docs if precision matters, as the search snippet did not quote an explicit "we still support .p12" statement).

**Supabase integration:**
- OneSignal is listed on Supabase's own partner integrations page: `https://supabase.com/partners/integrations/onesignal`, checked 2026-09-09 (page title confirmed: "OneSignal | Works With Supabase"; full page body content did not load for a detailed content quote, but its existence as an official Supabase partner listing is confirmed).
- The actual implementation pattern is **not a native Postgres trigger/managed integration** — it is a **sample project pattern**: Supabase Database Webhooks fire on INSERT, calling an Edge Function, which then calls OneSignal's **generic REST API**. Confirmed via OneSignal's own reference sample repo: `https://github.com/OneSignalDevelopers/onesignal-supabase-sample-integration-supabase` ("Sample integration to send a push notification using OneSignal from a Supabase edge function"), checked 2026-09-09.
- Conclusion: OneSignal does **not** have a first-class/managed Postgres-trigger integration comparable to, say, a native Supabase extension — it's the same Database-Webhook-to-Edge-Function-to-REST-API pattern you'd need for direct APNs, just swapping the final REST call target from `api.push.apple.com` to OneSignal's API. This significantly narrows the "convenience" gap between OneSignal and hand-rolled APNs, since both need essentially the same Supabase-side plumbing.

## 3. Other comparable push-only / notification-infra services (free tier facts)

**Courier** (`https://www.courier.com/pricing`, checked 2026-09-09):
- Free "Developer" tier: **10,000 sends/month** across email, push, SMS, in-app, and chat combined (not push-specific).
- Business tier: pay-as-you-go at **$0.005/send** after the free allocation.
- Enterprise: custom/volume pricing.
- The pricing page does not explicitly break out push/APNs availability by tier in the fetched content; broader marketing copy states the platform supports "email, push, SMS, in-app, and chat" generally. This should be verified against Courier's channel-specific docs before relying on it, since the pricing page itself was not fully explicit about push inclusion per tier.

**Novu** (pricing details via `https://www.g2.com/products/novu/pricing` and related listings, checked 2026-09-09 — not Novu's own pricing page directly, so treat as secondary-sourced and verify on novu.co before deciding):
- Free tier: **10,000 workflow runs/month**, all channels (including push), up to 20 workflows, 2 environments, 24-hour activity log retention, up to 3 team members, US/EU data residency.
- Paid: Pro from $30/month (30,000+ runs/month, 7-day retention, no branding); Team from $250/month; custom Enterprise.
- Notable: Novu supports **self-hosting for free**, which is an option not available with OneSignal/Courier/Knock/Pusher Beams (all SaaS-only). This matters for a solo dev wanting to avoid any per-MAU/per-send ceiling long-term.

**Knock** (`https://knock.app/pricing`, checked 2026-09-09):
- Free "Developer" tier: **10,000 messages/month** ("messages sent from workflows and broadcasts"), "500 guide active users," "unlimited notification channels" per the page — but the fetched page content did not explicitly confirm APNs/push availability on the free tier specifically (it lists channels generically). This should be verified directly against Knock's channel-support docs before treating push as confirmed-free.
- Paid Starter tier starts at **$250/month** with 50,000 notifications/month and removes branding — notably steep relative to Courier/Novu/OneSignal for a solo-dev budget.

Given the above, **Courier and Novu are the more solo-dev-friendly comparisons to OneSignal** than Knock, whose paid tier jumps straight to $250/month. Novu's self-host option is the strongest long-term hedge against future free-tier changes (which is exactly what just happened with OneSignal's new 1,000-MAU cap).

## 4. Supabase's mechanism for triggering an Edge Function on Postgres INSERT

- **Confirmed mechanism: Database Webhooks**, documented at `https://supabase.com/docs/guides/database/webhooks`, checked 2026-09-09.
- How it works, per Supabase's own docs:
  1. Database Webhooks are "a convenience wrapper around triggers using the `pg_net` extension" — creating a webhook creates a **Postgres trigger** on the target table.
  2. "All events are fired *after* a database row is changed" — i.e., the trigger fires **after** the INSERT (or UPDATE/DELETE) commits, not before.
  3. The trigger invokes the `http_request` function (from `pg_net`), which performs the actual HTTP call to the configured webhook URL — which can be a Supabase Edge Function URL or any external HTTP endpoint.
  4. `pg_net` is explicitly described as "an asynchronous networking extension for Postgres" — the request is fired off async and **does not block** the triggering database transaction/write while waiting for the webhook's response.
  5. The webhook payload is an automatically generated JSON body containing event type (INSERT/UPDATE/DELETE), table/schema, and the record data (new row for INSERT).
  6. Webhooks can also be created directly via SQL (`CREATE TRIGGER ...`) rather than only through the dashboard UI, and delivery logs are queryable under the `net` schema for debugging.
- This mechanism is identical regardless of which push path (direct APNs vs. third-party) is chosen — the Edge Function invoked by the webhook is simply where the APNs call or the third-party REST call gets made.

## 5. Can Supabase Edge Functions make outbound HTTP/2 calls to APNs, and is there a Deno-friendly APNs JWT library?

**HTTP/2 outbound capability:**
- Deno's `fetch()` is a browser-compatible implementation that **automatically negotiates HTTP/2 over HTTPS** with no special configuration needed — confirmed via general Deno documentation/community sources (`https://medium.com/deno-the-complete-reference/http-2-in-deno-f825251a5ab2` and related search results), checked 2026-09-09. Apple's APNs provider API requires HTTP/2 and is reachable at `https://api.push.apple.com/3/device/{deviceToken}` (production) / `https://api.sandbox.push.apple.com/3/device/{deviceToken}` (sandbox), per Apple's own developer docs (`https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns`), checked 2026-09-09. Because this is a standard HTTPS POST (not a raw persistent TCP/TLS socket managed manually), a plain `fetch()` call from a Deno-based Edge Function should transparently use HTTP/2 against `api.push.apple.com`.
- **No documented blocker for port 443 / general HTTPS egress.** Supabase's own Edge Functions limits doc (`https://supabase.com/docs/guides/functions/limits`, checked 2026-09-09) states only: "Outgoing connections to ports `25` and `587` are not allowed" (SMTP-related ports). No restriction on port 443 or on HTTP/2 specifically is documented. (A community GitHub issue — `https://github.com/supabase/supabase/issues/21977`, checked 2026-09-09 — separately notes some inconsistency around whether port 465 is blocked in practice vs. docs, but this is unrelated to port 443/APNs.)
- Supabase also documents that Edge Functions **do not have a stable/static egress IP** (`https://supabase.com/docs/guides/troubleshooting/why-supabase-edge-functions-cannot-provide-static-egress-ips-for-whitelisting-3d78b0`, found via search, checked 2026-09-09) — not a blocker for calling APNs (which doesn't require IP allowlisting), but worth noting if any future third-party service required IP allowlisting.
- **Notable: Supabase's own official example guide for push notifications does NOT demonstrate direct APNs.** `https://supabase.com/docs/guides/functions/examples/push-notifications`, checked 2026-09-09, shows two paths — Expo Push Notifications (which itself abstracts APNs/FCM) and direct Firebase Cloud Messaging (FCM) using `google-auth-library` — but no direct-to-APNs example. This means direct APNs is a supported-but-undocumented-by-Supabase path, not a first-class blessed pattern.

**Deno/npm-compatible APNs library situation:**
- **`node-apn` fails under Supabase Edge Functions.** A Supabase community discussion (`https://github.com/orgs/supabase/discussions/21200`, "Supabase Edge Functions giving `node:tls` is not supported in browser environment", checked 2026-09-09) documents that importing the standard `apn` npm package into a Supabase Edge Function throws because it depends on Node's `node:tls` module, which is not supported in the Deno/edge-runtime's browser-like sandbox.
- **`apns2` (npm, by AndrewBarba) is also a Node-native client** (`https://www.npmjs.com/package/apns2` / `https://github.com/AndrewBarba/apns2`, checked 2026-09-09) built around Node's HTTP/2 and TLS internals — the same category of incompatibility should be expected, though it was not explicitly tested against Supabase in the sources found.
- **A relevant edge-runtime-compatible fork exists but targets Cloudflare Workers, not Deno specifically**: `@fivesheepco/cloudflare-apns2` (`https://github.com/FiveSheepCo/cloudflare-apns2`, checked 2026-09-09) is "a fork of the original apns2 package with support for Cloudflare Workers" that removes Node-only dependencies and replaces them with native Workers APIs (fetch + Web Crypto). Its README explicitly states "This package is not compatible with Node.js, and does not depend on the `nodejs_compat` flag." No explicit Deno compatibility claim was found for this fork — it would need direct testing under Supabase's Deno runtime, but its design principle (fetch + Web Crypto instead of Node http2/tls) is exactly the shape of library Deno needs, making it a plausible starting point or reference implementation to adapt.
- **The practical, confirmed-viable path is a hand-rolled client**: generate an ES256-signed JWT using Deno's Web Crypto API (or the Deno-native `djwt` library) with the .p8 key, Key ID, and Team ID, then POST it via `fetch()` to `api.push.apple.com` with the required headers (`authorization: bearer {token}`, `apns-topic`, etc.). This pattern was found demonstrated in community troubleshooting content referencing `djwt` + Web Crypto as a Deno-compatible substitute for `node-apn`'s JWT generation (surfaced via search of Supabase discussions around ES256 JWT signing in Edge Functions), checked 2026-09-09. No single polished, actively-maintained "Deno-native APNs client" package (analogous to `node-apn` for Node) was found in this research — this appears to be a build-it-yourself situation, of low-to-moderate complexity (JWT signing + one HTTP call), not a high-complexity one.
- Supabase does support npm specifiers generally in Edge Functions (`https://supabase.com/blog/edge-functions-node-npm`, checked 2026-09-09 — Supabase added Node/native-npm compatibility for Edge Functions), so in principle an npm APNs package *could* be imported, but the `node-apn` case above shows that npm compatibility does not guarantee the package's underlying Node-core-module dependencies (`node:tls`, `node:http2`) will actually work in the sandboxed edge runtime.

---

## Sources index (all checked 2026-09-09)

- https://pusher.com/beams/
- https://pusher.com/docs/beams/
- https://pusher.com/beams/pricing/
- https://pusher.com/blog/our-product-roadmap-taking-channels-and-beams-to-even-greater-success/
- https://documentation.onesignal.com/docs/en/billing-faq
- https://onesignal.com/pricing
- https://documentation.onesignal.com/docs/en/ios-p8-token-based-connection-to-apns
- https://supabase.com/partners/integrations/onesignal
- https://github.com/OneSignalDevelopers/onesignal-supabase-sample-integration-supabase
- https://www.courier.com/pricing
- https://knock.app/pricing
- https://www.g2.com/products/novu/pricing (secondary — verify against novu.co pricing directly)
- https://supabase.com/docs/guides/database/webhooks
- https://supabase.com/docs/guides/functions/limits
- https://supabase.com/docs/guides/functions/examples/push-notifications
- https://supabase.com/docs/guides/troubleshooting/why-supabase-edge-functions-cannot-provide-static-egress-ips-for-whitelisting-3d78b0
- https://github.com/supabase/supabase/issues/21977
- https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns
- https://github.com/orgs/supabase/discussions/21200
- https://www.npmjs.com/package/apns2
- https://github.com/AndrewBarba/apns2
- https://github.com/FiveSheepCo/cloudflare-apns2
- https://supabase.com/blog/edge-functions-node-npm

## Gaps / things to double-check before finalizing the decision

- OneSignal's explicit statement on whether legacy `.p12` certificate upload is still supported alongside `.p8` was not directly quoted from their docs — the dashboard almost certainly still offers it, but confirm directly in-app.
- Courier's and Knock's push/APNs channel availability on their free tiers was not explicitly confirmed in the fetched pricing page text (only implied by general marketing copy) — verify against each vendor's channel-support docs.
- Novu's free-tier figures were sourced from a secondary aggregator (G2), not novu.co directly — the pricing page failed to load cleanly in this pass; re-verify on Novu's own site.
- No live test was performed of a `fetch()` HTTP/2 call from an actual Supabase Edge Function to `api.push.apple.com` — this research confirms no documented blocker, but a real end-to-end smoke test is recommended before committing to the direct-APNs path.
