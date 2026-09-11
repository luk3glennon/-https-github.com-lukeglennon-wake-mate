# iOS 26 Adoption Research — Findings for Wake Mate Min-iOS-Version Decision

Research date: 2026-09-09. All web research performed via search/fetch on this date; underlying source dates are noted individually below since Apple's adoption page and press coverage lag the "today" date.

**Important caveat up front:** Apple's official adoption page is updated only periodically (roughly: shortly after a new major ships, again in Jan/Feb, and a final pre-WWDC snapshot in June). There is **no** Apple-published data point dated September 2026 (i.e., exactly at the iOS 26 1-year mark) — by that date iOS 27 has already shipped (see below) and would be cannibalizing iOS 26's "current version" share, the same pattern seen for iOS 17→18 and iOS 18→26. The most recent *verifiable* Apple data point is from **June 7, 2026** (per Apple's own adoption page and press coverage of it), i.e. about 9 months post-launch — this is treated as the effective adoption *ceiling* for iOS 26 before the next major OS began eroding "current" share. Numbers reported by tech press for later dates (e.g. TelemetryDeck's August 2026 figures) come from a third-party analytics panel, not Apple.

---

## 1. Current iOS 26 adoption share among active iPhones

### Apple's official data (developer.apple.com/support/app-store/)
The App Store adoption page is **still published** as of this research (checked 2026-09-09) and currently shows only the **most recent** snapshot (it does not keep a historical table — older data points are known only via press coverage/archives at the time they were captured).

- **Latest snapshot on the live page, as measured by devices that transacted on the App Store on June 7, 2026:**
  - iOS 26 on devices introduced in the last four years: **86%**
  - iOS 26 on all active iPhones: **79%**
  - iPadOS 26 on iPads introduced in the last four years: **79%**
  - iPadOS 26 on all active iPads: **68%**
  - Source: [App Store - Support - Apple Developer](https://developer.apple.com/support/app-store/) (page checked 2026-09-09; data dated June 7, 2026); corroborated by [MacRumors, "Apple Reveals How Many iPhones Were Running iOS 26 Before WWDC" (2026-06-09)](https://www.macrumors.com/2026/06/09/ios-26-adoption-stats-wwdc/).

- **Earlier 2026 snapshot (superseded on the live page, known via press archive), as measured February 12, 2026 (~150 days post-launch):**
  - iOS 26 on devices introduced in the last four years: **74%**; iOS 18: 20%; earlier: 6%
  - iOS 26 on all active iPhones: **66%**; iOS 18: 24%; earlier: 10%
  - Source: [9to5Mac, "Are people updating to iOS 26? Here's Apple's official data" (2026-02-13)](https://9to5mac.com/2026/02/13/apple-announces-ios-26-usage-numbers-heres-how-they-compare/); [iClarified, "iOS 26 Adoption Reaches 74% on Recent iPhones, 66% Overall" (2026-02-2026)](https://www.iclarified.com/99920/ios-26-adoption-reaches-74-on-recent-iphones-66-overall-chart); also referenced in [Daring Fireball (2026-02)](https://daringfireball.net/2026/02/apple_releases_ios_26_adoption_rates).

### Independent tracker (TelemetryDeck — a Mixpanel-style panel; Mixpanel's own public "iOS Version Market Share" page could not be located/confirmed live during this research — see note below)
- **End of August 2026** (most recent data found, closest to the September 2026 "1-year" mark):
  - iOS 26: **86.57%**
  - iOS 18: **7.87%** (down from >53% in November 2025)
  - iOS 27: **3.29%** (already shipping/beta — see release-date finding below)
  - Source: [TelemetryDeck, "iOS Versions Market Share in 2026"](https://telemetrydeck.com/survey/apple/iOS/majorSystemVersions/) (data through end of August 2026, page checked 2026-09-09).
  - Methodology note stated on the page: TelemetryDeck aggregates usage from apps integrated with its SDK; the panel "is mostly American and European apps and skews towards small and independent developers" — i.e., not a full-market panel and may not match Apple's own (much larger) telemetry exactly. It also groups iOS 26 together with "iOS 19" (an internal/dev-environment version-numbering quirk), and covers iOS+iPadOS combined, excluding tvOS/watchOS.
- **No September 2026 data point was found** from TelemetryDeck or any other tracker as of this research (2026-09-09) — August 2026 (86.57%) is the most recent verifiable figure from this source.

### Mixpanel specifically
I could not verify that Mixpanel's public "iOS Version Market Share" trends page is still live/publicly accessible with current 2026 data during this research session — searches returned only tangential Mixpanel company/market-share-of-analytics-tools pages, not the iOS-version-share trend page itself. **This should be treated as "not found," not "confirmed discontinued."** TelemetryDeck's public page (functionally the same kind of independent tracker) was used instead and is cited above.

### Bottom line for Q1
- Best Apple-sourced figure: **79% of all active iPhones, 86% of iPhones from the last 4 years**, on iOS 26, as of June 7, 2026 (~9 months post-launch) — this is very likely close to the effective ceiling for "current major" share before iOS 27 cannibalizes it.
- Best independent-tracker figure closer to September 2026: **~86.6% (of the panel's tracked devices)** as of end of August 2026 (TelemetryDeck) — but this panel is not directly comparable to Apple's methodology (different denominator: "devices in the panel" vs. "devices that transacted on the App Store").
- **No confirmed data exists dated exactly September 2026.** Extrapolating, adoption by September 9, 2026 is very likely in the same 79–87% range as the June/August data points, possibly beginning to erode slightly as iOS 27 (released September 14, 2026, see below) starts drawing share away — this is an inference, not a verified figure.

---

## 2. Which iPhone models support iOS 26 / hardware-eligibility vs. lagging-adoption

### Official supported-device list
Per Apple's own support page, iOS 26 is compatible with:

> iPhone 11, iPhone 11 Pro, iPhone 11 Pro Max, iPhone SE (2nd generation), iPhone 12 mini, iPhone 12, iPhone 12 Pro, iPhone 12 Pro Max, iPhone 13 mini, iPhone 13, iPhone 13 Pro, iPhone 13 Pro Max, iPhone SE (3rd generation), iPhone 14, iPhone 14 Plus, iPhone 14 Pro, iPhone 14 Pro Max, iPhone 15, iPhone 15 Plus, iPhone 15 Pro, iPhone 15 Pro Max, iPhone 16, iPhone 16 Plus, iPhone 16 Pro, iPhone 16 Pro Max, iPhone 16e, iPhone 17, iPhone 17 Pro, iPhone 17 Pro Max, iPhone Air, iPhone 17e

Source: [Apple Support, "iPhone models compatible with iOS 26"](https://support.apple.com/guide/iphone/iphone-models-compatible-with-ios-26-iphe3fa5df43/ios) (fetched 2026-09-09).

**Oldest/lowest-end device still supported: iPhone 11 (standard/Pro/Pro Max), and iPhone SE (2nd generation).** The first-generation iPhone SE and anything older (iPhone X, iPhone 8/8 Plus, iPhone 7/7 Plus, 6s/6s Plus) is **not** on the list and cannot run iOS 26 regardless of update behavior.

### AlarmKit's own minimum version
- Apple's AlarmKit framework documentation (developer.apple.com/documentation/AlarmKit) is described in WWDC25 session materials and framework docs as shipping with **iOS 26 and iPadOS 26** (confirmed via WWDC25 "Wake up to the AlarmKit API" session and multiple secondary sources: [MacRumors, "iOS 26 Makes Third-Party Alarm and Timer Apps Better" (2025-06-11)](https://www.macrumors.com/2025/06/11/ios-26-third-party-alarm-apps/); [Michael Tsai's blog on AlarmKit (2025-06-20)](https://mjtsai.com/blog/2025/06/20/ios-26-alarmkit/)). Search results for the live API reference page returned "iOS 26.0+" as the availability badge for AlarmKit APIs, consistent with a hard floor of **iOS 26.0** — i.e., AlarmKit has no lower deployment target than iOS 26 itself; it inherits iOS 26's device-support list above (no separate, more restrictive device list is documented for AlarmKit specifically). **Caveat:** I was not able to fetch the full rendered Apple Developer Documentation page content directly (WebFetch returned only the page title, not the body, likely due to the page being JS-rendered) — the "iOS 26.0+" badge is corroborated by search-result summaries rather than a direct page read, so treat this as high-confidence but not a verbatim-quoted primary-source excerpt.

### Non-adoption: hardware-ineligible vs. just lagging
- iOS 26 **dropped support for three iPhone models** that iOS 18 had supported (iPhone XR, iPhone XS, iPhone XS Max are the models that fell off the compatibility list moving from iOS 18 → iOS 26, raising the floor to iPhone 11/SE 2nd-gen). This is stated by 9to5Mac (2026-02-13) as the explanation for iOS 26 adopting slightly slower than iOS 18 did at a comparable point: "iOS 26 dropped three iPhone models this year," unlike iOS 18, which supported the same devices as iOS 17. Source: [9to5Mac (2026-02-13)](https://9to5mac.com/2026/02/13/apple-announces-ios-26-usage-numbers-heres-how-they-compare/).
- **I could not find a hard, sourced percentage for "what fraction of the active/installed iPhone base is permanently hardware-ineligible for iOS 26"** (e.g., a stat like "X% of active iPhones are iPhone XS or older"). Multiple searches (Statcounter, Mixpanel, general market-share aggregators) did not surface this specific breakdown. This should be treated as **unverified / not found**, not zero.
- What the data does support: Apple's own adoption chart splits into "current major," "previous major," and an "earlier" bucket. In the June 2026 data, iOS 26 = 79% and iOS 18 = (implied residual, not explicitly re-stated in the June snapshot as fetched) with a further "earlier" bucket — but **Apple's own chart does not distinguish, within that "earlier" bucket, between (a) hardware-eligible devices whose owners simply haven't updated and (b) devices that are hardware-incapable of ever running iOS 26.** This is an inherent limitation of the source: Apple's methodology conflates laggards and hardware-ineligible devices into the same residual percentage.
- Secondary reporting (e.g., [TechTimes on iOS 26 compatible devices (2025-12-15)](https://www.techtimes.com/articles/313375/20251215/ios-26-compatible-devices-supported-iphones-which-models-miss-apple-update.htm), [Geek Fix, "Which iPhones Lose Apple Updates in 2026"](https://geekfix.ca/iphone-updates-2026/)) confirms the iPhone 7/6s/8/8 Plus/X/original-SE families are locked out of iOS 26 (and also iOS 27) permanently due to Apple's hardware cutoff (commonly described as an A12-Bionic-and-later boundary for iOS 26/27), but none of these sources gave a quantified "% of active install base" figure.
- **Practical inference (labeled as inference, not a sourced figure):** Given Apple's own iOS 26 adoption ceiling reached ~79% of *all* active iPhones by June 2026, and independent trackers show iOS 26 near ~86-87% of *panel* devices by August 2026, the non-iOS-26 remainder (13–24% depending on source/date) is a mix of (a) hardware-ineligible legacy devices (iPhone X and older) and (b) eligible iPhone 11+ devices whose owners simply haven't updated. Without a sourced device-age breakdown of the active install base, it is not possible to split this remainder precisely between "ineligible" and "lagging" — flagging this as an open data gap.

---

## 3. Historical adoption trend at ~1-year post-launch (iOS 17, iOS 18, and comparison to iOS 26)

Apple does not publish data on the exact anniversary date of a release; the closest recurring, comparable snapshot each cycle is Apple's **pre-WWDC (early June) data point**, roughly 8.5–9 months after each September launch — treated here as the best available proxy for "near the 1-year mark, at its practical ceiling before the next major OS starts eroding current-version share."

| iOS version | Launch date | Snapshot date (~9 mo. mark) | % of iPhones from last 4 years | % of all active iPhones | Source |
|---|---|---|---|---|---|
| iOS 17 | Sept 2023 | June 9, 2024 (~9 months) | **86%** | **77%** | [MacRumors (2024-06-11)](https://www.macrumors.com/2024/06/11/apple-shares-final-ios-17-adoption-stats/); [9to5Mac (2024-06-11)](https://9to5mac.com/2024/06/11/ios-17-adoption-rate/); [iClarified](https://www.iclarified.com/93919/ios-17-adoption-reaches-77-chart) |
| iOS 18 | Sept 2024 | June 5, 2025 (~9 months) | **88%** | **82%** | Cited via [MacRumors' iOS 26 vs iOS 18 comparison table (2026-06-09)](https://www.macrumors.com/2026/06/09/ios-26-adoption-stats-wwdc/), which directly compares against Apple's iOS 18 figures from June 5, 2025; also [AppleInsider, "iOS 18 saw below average adoption despite Apple Intelligence" (2025-06-05)](https://appleinsider.com/articles/25/06/05/ios-18-saw-below-average-adoption-despite-apple-intelligence) |
| iOS 26 | Sept 2025 | June 7, 2026 (~9 months) | **86%** | **79%** | [Apple Developer Support page](https://developer.apple.com/support/app-store/) (checked 2026-09-09, data dated 2026-06-07); [MacRumors (2026-06-09)](https://www.macrumors.com/2026/06/09/ios-26-adoption-stats-wwdc/) |

Additional earlier-cycle mid-year checkpoints found (~4-5 months post-launch, for pattern context):
- iOS 17 at ~139 days (~Feb 4, 2024): 76% of newer devices — [MacRumors (2024-02-05)](https://www.macrumors.com/2024/02/05/apple-shares-ios-17-adoption-numbers/)
- iOS 18 at ~127 days (~Jan 21, 2025): 76% of newer devices, 68% all devices — [TechCrunch (2025-01-24)](https://techcrunch.com/2025/01/24/ios-18-hits-68-adoption-across-iphones-per-new-apple-figures); [iDownloadBlog (2025-01-24)](https://www.idownloadblog.com/2025/01/24/apple-app-store-statistics-ios-18-adoption-rate-january-2025/)
- iOS 26 at ~150 days (Feb 12, 2026): 74% of newer devices, 66% all devices — [9to5Mac (2026-02-13)](https://9to5mac.com/2026/02/13/apple-announces-ios-26-usage-numbers-heres-how-they-compare/)

### Does adoption plateau or keep climbing after ~1 year?
- The data shows each version reaches a **practical ceiling around 8-9 months post-launch, in the high-70s to high-80s percent range** (77–88% depending on "all devices" vs. "recent devices" cut, and depending on the specific cycle), and that this ceiling is essentially the **maximum share the version ever reaches**, because:
  - Apple's own reporting cadence stops shortly after this point (next data point is typically tied to the next major OS's WWDC announcement, i.e. ~12 months later), and
  - once the next major OS ships (~12 months after the prior one), that ceiling begins actively eroding as users update to the new major — confirmed directly by the TelemetryDeck data: iOS 18 share fell from >53% (Nov 2025) to 7.87% (Aug 2026) as iOS 26 took over, and the same "jump from <5% to 29% in three weeks" pattern was observed for iOS 26 itself in the three weeks after its September 2025 launch (per TelemetryDeck's page, [telemetrydeck.com](https://telemetrydeck.com/survey/apple/iOS/majorSystemVersions/)).
  - So: **adoption is still climbing, meaningfully, for the first several months, then plateaus close to its ceiling by ~8-9 months, and that plateau (not "still climbing") is what's in effect at the true 1-year mark** — because the next OS's launch (which happens right around the 1-year mark) immediately starts cannibalizing "current version" share rather than letting it climb further.
- Year-over-year, this ceiling has been remarkably stable across three consecutive cycles: **~86-88% of recent (last-4-years) devices, ~77-82% of all active devices**, with iOS 26 sitting at the lower end of that historical band (86% / 79%) — consistent with 9to5Mac/Daring Fireball's framing that iOS 26's slightly slower pace vs. iOS 18 is attributable to iOS 26 dropping 3 older iPhone models from its compatibility list (shrinking the eligible pool at the margin) rather than unusual user resistance.
- No iOS 16 or older-cycle 1-year data point was found/verified in this research session (searches focused on 17/18/26 as requested); if needed for further comparison, iOS 16's June 2023 data point (cited in passing by a 9to5Mac/MacRumors comparison as "81% of newer devices as of May 30, 2023") suggests the same ~80-86% recent-device ceiling band extends back at least one more cycle, but this single data point was not independently cross-checked against a primary Apple source in this research pass and should be treated as low-confidence.

---

## Additional relevant finding: iOS 27 already exists and is imminent/released

Not explicitly asked for, but directly relevant to interpreting "1 year after iOS 26" data: iOS 27 was announced at WWDC 2026 (June 8, 2026), has been in public beta since, and — per tech press — **its Release Candidate shipped September 9, 2026 (today, per search results), with general release on September 14, 2026.** Source: [Macworld, "iOS 27: Release date, Beta, compatible iPhones and all new features"](https://www.macworld.com/article/2986799/ios-27-new-iphone-features-release-date-beta-compatiblity-apple-intelligence-siri.html); [Geeky Gadgets, "iOS 27 Release Date Revealed"](https://www.geeky-gadgets.com/ios-27-final-release-date/). iOS 27's minimum supported device is reported as the same floor as iOS 26 (iPhone 11 / iPhone SE 2nd gen and later), per the same sources plus [PhoneArena's iOS 27 overview](https://www.phonearena.com/ios-27-release-date-features-news-compatible-iphones). **This was not independently verified against Apple's own official iOS 27 compatibility page in this research pass** — flagging as press-sourced, not primary-sourced, and worth confirming with Apple's support page directly if the min-iOS decision needs to account for iOS 27 specifically.

**Implication for the min-iOS decision:** by the time Wake Mate could ship, iOS 26 will already be the *second-most-current* major version (iOS 27 having just launched), and — per the historical pattern above — its "current version" share will already be past its ceiling and beginning to erode in favor of iOS 27, even though the underlying *hardware* floor (iPhone 11+/SE 2nd gen+) is unchanged between iOS 26 and iOS 27.

---

## Sources

1. [App Store - Support - Apple Developer](https://developer.apple.com/support/app-store/) — Apple's official adoption page; checked 2026-09-09, live data dated 2026-06-07.
2. [Apple Support — iPhone models compatible with iOS 26](https://support.apple.com/guide/iphone/iphone-models-compatible-with-ios-26-iphe3fa5df43/ios) — fetched 2026-09-09.
3. [Apple Developer Documentation — AlarmKit](https://developer.apple.com/documentation/AlarmKit) — framework overview (full body not directly retrievable via fetch; title/metadata only).
4. [Apple Developer Documentation — Scheduling an alarm with AlarmKit](https://developer.apple.com/documentation/AlarmKit/scheduling-an-alarm-with-alarmkit) — same retrieval limitation.
5. [Apple Developer — Wake up to the AlarmKit API (WWDC25 session video page)](https://developer.apple.com/videos/play/wwdc2025/230/) — primary source for AlarmKit's iOS 26 introduction.
6. [MacRumors — "iOS 26 Makes Third-Party Alarm and Timer Apps Better" (2025-06-11)](https://www.macrumors.com/2025/06/11/ios-26-third-party-alarm-apps/)
7. [Michael Tsai's Blog — "iOS 26: AlarmKit" (2025-06-20)](https://mjtsai.com/blog/2025/06/20/ios-26-alarmkit/)
8. [MacRumors — "Apple Reveals How Many iPhones Are Running iOS 26" (2026-02-13)](https://www.macrumors.com/2026/02/13/apple-shares-ios-26-adoption-stats.html) *(February 2026 snapshot)*
9. [MacRumors — "Apple Reveals How Many iPhones Were Running iOS 26 Before WWDC" (2026-06-09)](https://www.macrumors.com/2026/06/09/ios-26-adoption-stats-wwdc/) *(June 2026 snapshot; primary comparison table vs iOS 18)*
10. [9to5Mac — "Are people updating to iOS 26? Here's Apple's official data" (2026-02-13)](https://9to5mac.com/2026/02/13/apple-announces-ios-26-usage-numbers-heres-how-they-compare/)
11. [iClarified — "iOS 26 Adoption Reaches 74% on Recent iPhones, 66% Overall [Chart]" (2026-02)](https://www.iclarified.com/99920/ios-26-adoption-reaches-74-on-recent-iphones-66-overall-chart)
12. [Daring Fireball — "Apple Releases iOS 26 Adoption Rates..." (2026-02)](https://daringfireball.net/2026/02/apple_releases_ios_26_adoption_rates)
13. [TelemetryDeck — "iOS Versions Market Share in 2026"](https://telemetrydeck.com/survey/apple/iOS/majorSystemVersions/) — independent analytics-panel tracker; data through end of August 2026, page checked 2026-09-09.
14. [TelemetryDeck — "iOS Minor Versions Market Share in 2026"](https://telemetrydeck.com/survey/apple/iOS/minorSystemVersions/)
15. [MacRumors — "iOS 17 Adoption is Slower Than iOS 16 Adoption" (2024-02-05)](https://www.macrumors.com/2024/02/05/apple-shares-ios-17-adoption-numbers/)
16. [MacRumors — "Apple Reveals How Many iPhones Were Running iOS 17 Before WWDC" (2024-06-11)](https://www.macrumors.com/2024/06/11/apple-shares-final-ios-17-adoption-stats/)
17. [9to5Mac — "iOS 17 adoption rate reaches 77% – but still slower than iOS 16" (2024-06-11)](https://9to5mac.com/2024/06/11/ios-17-adoption-rate/)
18. [iClarified — "iOS 17 Adoption Reaches 77% [Chart]"](https://www.iclarified.com/93919/ios-17-adoption-reaches-77-chart)
19. [TechCrunch — "iOS 18 hits 68% adoption across iPhones per new Apple figures" (2025-01-24)](https://techcrunch.com/2025/01/24/ios-18-hits-68-adoption-across-iphones-per-new-apple-figures)
20. [iDownloadBlog — "iOS 18 adoption on pace with comparable iOS 17 statistics last year" (2025-01-24)](https://www.idownloadblog.com/2025/01/24/apple-app-store-statistics-ios-18-adoption-rate-january-2025/)
21. [AppleInsider — "iOS 18 saw below average adoption despite Apple Intelligence" (2025-06-05)](https://appleinsider.com/articles/25/06/05/ios-18-saw-below-average-adoption-despite-apple-intelligence)
22. [Apple World Today — "iOS 18 is on 88% of recent iPhones; iPadOS is on 81% of recent iPads" (2025-06)](https://appleworld.today/2025/06/ios-18-is-on-88-of-recent-iphones-ipados-is-on-81-of-recent-ipads/)
23. [TechTimes — "iOS 26 Compatible Devices and Supported iPhones: Which Models Miss the Apple Update?" (2025-12-15)](https://www.techtimes.com/articles/313375/20251215/ios-26-compatible-devices-supported-iphones-which-models-miss-apple-update.htm)
24. [Geek Fix — "Which iPhones Lose Apple Updates in 2026?"](https://geekfix.ca/iphone-updates-2026/)
25. [Macworld — "iOS 27: Release date, Beta, compatible iPhones and all new features"](https://www.macworld.com/article/2986799/ios-27-new-iphone-features-release-date-beta-compatiblity-apple-intelligence-siri.html)
26. [Geeky Gadgets — "iOS 27 Release Date Revealed: When the Final Update Goes Live"](https://www.geeky-gadgets.com/ios-27-final-release-date/)
27. [PhoneArena — "iOS 27: Release date expectations, new features, and compatible iPhones"](https://www.phonearena.com/ios-27-release-date-features-news-compatible-iphones)

### Sources searched but not usefully confirmed / explicitly flagged as unverified
- **Mixpanel's public "iOS Version Market Share" trends page** — could not confirm it is still live with current data during this research session; not cited above beyond this note. Do not assume it is discontinued — only that this research pass did not surface/confirm it.
- **A quantified "% of active install base that is hardware-ineligible for iOS 26"** — not found in any source searched (Statcounter, Mixpanel, general market-share aggregator sites, Apple's own adoption page). Flagged as an open data gap in Section 2 above.
- **Apple's own official iOS 27 compatibility page** — not directly fetched/verified; iOS 27 device-support claims above are press-sourced only.
