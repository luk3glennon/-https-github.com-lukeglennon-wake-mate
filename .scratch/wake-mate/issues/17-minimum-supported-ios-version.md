Status: resolved
Type: grilling
Blocked by: 06, 07

## Question

What minimum iOS version should Wake Mate target? Ticket 06 (iOS alarm reliability research, resolved) found AlarmKit — the recommended mechanism for reliable wake-alarm delivery through force-quit/silent mode — requires iOS 26+. Ticket 07 (mobile client framework, resolved) confirmed native SwiftUI, which removes any cross-platform-tooling floor as a competing constraint. Decide: does Wake Mate simply require iOS 26+ as its minimum (accepting the adoption-curve cost of a brand-new OS version), or is there a fallback/degraded experience worth building for pre-26 devices — and if so, what does that degraded experience look like given ticket 06 found no equally reliable non-AlarmKit wake mechanism?

## Answer

**iOS 26+ hard minimum. No degraded fallback tier for pre-26 devices.** Decided via grilling: the only pre-26 wake mechanism (plain local notifications) doesn't survive force-quit or override silent mode/DND — a materially worse experience that undermines Wake Mate's core "wakes you up reliably" promise rather than degrading it gracefully. Building and maintaining a second, unreliable code path isn't worth the cost for a solo-dev MVP. Grounded in adoption research: iOS 26 sits at ~79-87% of active iPhones (as of mid-2026), in line with where past major iOS versions (17, 18) plateaued at a comparable post-launch age — so 26+ isn't an unusually aggressive floor. Full adoption research: `.scratch/wake-mate/research/17-ios-26-adoption-findings.md`. Recorded as [ADR-0001](../../../docs/adr/0001-minimum-ios-26.md).
