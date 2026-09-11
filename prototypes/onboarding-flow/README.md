# Onboarding flow prototype — THROWAWAY, do not ship

Resolves ticket [Onboarding flow screens prototype](../../.scratch/wake-mate/issues/19-onboarding-flow-screens-prototype.md)
on the Wake Mate MVP map.

## Plan

Three structurally different variants of the full onboarding flow (account
creation → skippable invite/add-friend screen → pending-request
accept/decline), switchable via a floating bottom bar, so the layout, copy,
and the accept/decline interaction can be reacted to side by side.

## How to run

This machine has no Xcode/Swift toolchain (Windows), so this hasn't been
compiled — treat it as reviewable SwiftUI, not a verified build. To actually
run it on a Mac:

1. Create a new Xcode App project (SwiftUI lifecycle, iOS 26 minimum, no
   Core Data/tests).
2. Delete the generated `ContentView.swift`.
3. Drag all `.swift` files from this folder into the project.
4. Run on an iOS 26+ simulator. `PrototypeApp` is the `@main` entry point.

## Files

- `PrototypeApp.swift` — app entry point, mounts the switcher.
- `PrototypeSwitcher.swift` — the floating variant switcher (A/B/C, cycles
  with the arrows) and the shared mock data every variant reacts to.
- `VariantA_CardStack.swift` — invite screen as two stacked cards
  (Invite Link card, Add-by-Handle card); pending request shown as a modal
  sheet with side-by-side Accept/Decline.
- `VariantB_SearchFirstWizard.swift` — invite screen leads with a prominent
  handle search bar, Invite Link tucked into a collapsible section, Skip
  de-emphasized; pending request is a full-screen takeover with large
  stacked buttons.
- `VariantC_InlineMinimal.swift` — invite screen is a single compact column
  (handle + share icon, inline search-as-you-type with an inline Add chip),
  Skip lives in the nav bar; pending requests render as a list screen
  (supports several at once) with inline accept/decline icon buttons and
  swipe actions.

## Adaptations from the standard prototype pattern

- No URL search param exists in SwiftUI, so the switcher uses `@State`
  instead; the variant view is force-reset via `.id(variant)` so each
  variant starts its flow fresh (account creation screen) on every switch.
- No keyboard-arrow cycling (not a meaningful iOS interaction) — the
  floating bar's own left/right buttons are the only way to cycle.
- "Sign in with Apple" is a plain styled button, not the real
  `AuthenticationServices` flow — auth itself isn't the question here, and
  wiring real entitlements would be premature for a rough prototype.
- All data (own Handle, search results, pending requests) is in-memory mock
  state seeded in `PrototypeSwitcher.swift`. Nothing hits a network or a
  database.

## Capturing the answer

Once a variant (or a specific mix) is picked: append the answer to the
ticket's `## Answer` section, add a context pointer to the map's
"Decisions so far", then fold only the winning structure into the real app
target when it exists. This whole `prototypes/onboarding-flow/` folder
moves to a throwaway branch rather than main once that's done.
