// PROTOTYPE — throwaway. See README.md.
//
// Shared mock data + the floating switcher that cycles between the three
// onboarding flow variants. Nothing here is real: no auth, no network, no
// persistence — this exists only so the flow itself can be reacted to.

import SwiftUI

// MARK: - Shared mock data

/// The signed-in prototype user, seeded once account creation "completes".
struct MockUser {
    var handle: String
    var inviteLinkURL: URL
}

/// Someone who has requested (or been requested for) a Friend Connection.
struct MockFriendRequest: Identifiable {
    let id = UUID()
    let handle: String
    let displayName: String
}

enum PrototypeMockData {
    static let currentUser = MockUser(
        handle: "jamie_w",
        inviteLinkURL: URL(string: "https://wakemate.app/i/jamie_w")!
    )

    /// Someone the "add by handle" search will exact-match against.
    static let searchableHandle = "morgan_k"

    /// What's already sitting in the pending-requests inbox when onboarding
    /// reaches that step. Per ticket 19's resolution: the *only* way a
    /// brand-new account can have an incoming request before anyone could
    /// have found their Handle via search is by resolving the inviter from
    /// an Invite Link tap (ticket 16) — so at most one entry belongs here.
    /// Empty this array to simulate an organic signup (no link tap), which
    /// should skip the pending-request step entirely.
    static let incomingRequests = [
        MockFriendRequest(handle: "morgan_k", displayName: "Morgan K."),
    ]
}

// MARK: - Switcher

enum PrototypeVariant: Int, CaseIterable {
    case a, b, c

    var label: String {
        switch self {
        case .a: return "A — Card Stack"
        case .b: return "B — Search-First Wizard"
        case .c: return "C — Inline Minimal"
        }
    }

    var next: PrototypeVariant { PrototypeVariant(rawValue: (rawValue + 1) % Self.allCases.count)! }
    var previous: PrototypeVariant { PrototypeVariant(rawValue: (rawValue - 1 + Self.allCases.count) % Self.allCases.count)! }
}

struct PrototypeSwitcher: View {
    @State private var variant: PrototypeVariant = .a

    var body: some View {
        ZStack(alignment: .bottom) {
            currentFlow
                // Force each variant to remount so its own flow always
                // restarts at account creation when you switch into it.
                .id(variant)

            #if DEBUG
            switcherBar
                .padding(.bottom, 12)
            #endif
        }
    }

    @ViewBuilder
    private var currentFlow: some View {
        switch variant {
        case .a: VariantA_CardStackFlow()
        case .b: VariantB_SearchFirstWizardFlow()
        case .c: VariantC_InlineMinimalFlow()
        }
    }

    private var switcherBar: some View {
        HStack(spacing: 16) {
            Button {
                variant = variant.previous
            } label: {
                Image(systemName: "chevron.left")
            }

            Text(variant.label)
                .font(.caption.weight(.semibold))
                .fixedSize()

            Button {
                variant = variant.next
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: Capsule())
        .shadow(radius: 6, y: 2)
    }
}

#Preview {
    PrototypeSwitcher()
}
