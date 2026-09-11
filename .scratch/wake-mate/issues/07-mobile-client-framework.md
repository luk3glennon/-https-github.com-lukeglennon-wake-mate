Status: resolved
Type: grilling
Blocked by: 06

## Question

Native SwiftUI vs. a cross-platform framework (React Native, Flutter, etc.) for the iOS prototype, given the destination is iOS-only for now but Android is a known future target. Weigh against the findings of ticket 06 (iOS alarm-reliability research) — some background-execution approaches may only be practical natively.

## Answer

**Native SwiftUI.** Decided via grilling, grounded in dedicated research into AlarmKit cross-platform bridging feasibility.

**Grilling inputs:**
- Team has zero prior experience in Swift/SwiftUI, React Native, or Flutter — no existing skill to leverage on either side, so "team familiarity" doesn't favor cross-platform here.
- The 4-week timeline is a soft target, not a hard deadline, but still shapes risk tolerance: a path with open-ended technical risk isn't worth it when a safer path exists.
- Android is explicitly deferred until after the iOS MVP is fully built, working end-to-end, and UI-polished — so cross-platform's main draw (shared codebase across iOS/Android) isn't a live concern yet.

**Research inputs (AlarmKit cross-platform bridging feasibility):**
- No mature or official RN/Flutter plugin wraps AlarmKit. Best candidate (`flutter_alarmkit`) is pre-1.0, ~2 months old, under 1,000 downloads. RN options are thinner and explicitly self-labeled "not yet production-ready."
- Bridging isn't just native-module glue: AlarmKit's Live Activity/countdown presentation requires a WidgetKit extension target + App Group, which doesn't fit RN's or Flutter's normal single-main-target module structure — `flutter_alarmkit` has to auto-patch the Xcode project to scaffold this.
- No entitlement gate (contrary to a common misconception) — but the extension-target requirement is a real structural mismatch with cross-platform tooling, not just a nice-to-have workaround.
- Effort assessment (reasoned, not sourced): core CRUD glue is plausibly days of work, but validating force-quit survival and the queue-head reschedule operation through an unproven third-party bridge, with zero mature reference implementations, is genuine open-ended risk — realistically 1-2 weeks with no guarantee of landing cleanly, against a 4-week target.

**Why native wins:** cross-platform's usual payoff (shared code, faster path to Android) isn't available yet (Android deferred) and isn't free even for iOS alone (bridging risk, no reuse advantage given zero existing skill in either stack). Native SwiftUI is what AlarmKit's own target-structure requirements are designed around, so it sidesteps the bridging risk category entirely rather than budgeting for it.

Full cross-platform bridging research: [alarmkit-cross-platform-bridging-findings.md](../research/alarmkit-cross-platform-bridging-findings.md).
