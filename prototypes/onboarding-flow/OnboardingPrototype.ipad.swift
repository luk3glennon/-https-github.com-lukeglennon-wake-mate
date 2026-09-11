// PROTOTYPE — throwaway. Single-file merge of the 5 files in this
// folder, for easy copy/paste into one Swift file in Swift Playgrounds
// on iPad. See README.md and the individual files for the real,
// separated source (used for Xcode).
//
// Resolves ticket "Onboarding flow screens prototype" on the Wake Mate
// MVP map.

import SwiftUI


@main
struct PrototypeApp: App {
    var body: some Scene {
        WindowGroup {
            PrototypeSwitcher()
        }
    }
}

//
// Shared mock data + the floating switcher that cycles between the three
// onboarding flow variants. Nothing here is real: no auth, no network, no
// persistence — this exists only so the flow itself can be reacted to.


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
    /// reaches that screen — Variant C needs more than one to show its list
    /// shape properly, A and B only render/consume the first.
    static let incomingRequests = [
        MockFriendRequest(handle: "morgan_k", displayName: "Morgan K."),
        MockFriendRequest(handle: "sam_r", displayName: "Sam R."),
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

//
// Variant A: "Card Stack" — the invite screen is two distinct cards (your
// Invite Link, add-by-Handle search). The pending-request accept/decline
// interaction is a modal sheet with side-by-side buttons.


struct VariantA_CardStackFlow: View {
    private enum Step {
        case accountCreation, invite, home
    }

    @State private var step: Step = .accountCreation

    var body: some View {
        NavigationStack {
            switch step {
            case .accountCreation:
                AccountCreationScreenA {
                    step = .invite
                }
            case .invite:
                InviteFriendsScreenA(onDone: { step = .home })
            case .home:
                HomeScreenA()
            }
        }
    }
}

// MARK: - 1. Account creation

private struct AccountCreationScreenA: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "alarm.waves.left.and.right.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("Wake Mate")
                    .font(.largeTitle.bold())
                Text("Wake up to the people you care about.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button(action: onContinue) {
                HStack {
                    Image(systemName: "apple.logo")
                    Text("Continue with Apple")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .clipShape(Capsule())
            .padding(.horizontal, 32)

            Text("By continuing you agree to the Terms and Privacy Policy.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)
        }
        .padding()
    }
}

// MARK: - 2. Invite friends (skippable)

private struct InviteFriendsScreenA: View {
    let onDone: () -> Void

    @State private var searchText = ""
    @State private var requestSentTo: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("Add your first friend")
                        .font(.title2.bold())
                    Text("You can always do this later from Settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)

                // Card 1 — your own Invite Link
                VStack(alignment: .leading, spacing: 12) {
                    Label("Your Invite Link", systemImage: "link")
                        .font(.headline)

                    Text("Anyone can use this to send you a friend request — even if they don't have Wake Mate yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text(PrototypeMockData.currentUser.inviteLinkURL.absoluteString)
                            .font(.footnote.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        ShareLink(item: PrototypeMockData.currentUser.inviteLinkURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .padding(10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                }
                .padding()
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.separator))

                // Card 2 — add by handle
                VStack(alignment: .leading, spacing: 12) {
                    Label("Add by Handle", systemImage: "person.fill.badge.plus")
                        .font(.headline)

                    Text("Know their exact @handle? Send them a request directly.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("@")
                            .foregroundStyle(.secondary)
                        TextField("handle", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

                    if let requestSentTo {
                        Label("Request sent to @\(requestSentTo)", systemImage: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.green)
                    } else {
                        Button("Send Request") {
                            requestSentTo = searchText
                        }
                        .buttonStyle(.bordered)
                        .disabled(searchText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding()
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.separator))
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Skip", action: onDone)
                    .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - 3. Home + pending-request accept (modal sheet)

private struct HomeScreenA: View {
    @State private var showPendingRequest = true

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            Text("You're all set")
                .font(.title2.bold())
            Text("(Home screen placeholder)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showPendingRequest) {
            if let request = PrototypeMockData.incomingRequests.first {
                PendingRequestSheetA(request: request) {
                    showPendingRequest = false
                }
                .presentationDetents([.height(320)])
            }
        }
    }
}

private struct PendingRequestSheetA: View {
    let request: MockFriendRequest
    let onResolved: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Circle()
                .fill(.tint.opacity(0.15))
                .frame(width: 72, height: 72)
                .overlay(
                    Text(request.displayName.prefix(1))
                        .font(.title.bold())
                        .foregroundStyle(.tint)
                )
                .padding(.top, 24)

            VStack(spacing: 4) {
                Text("@\(request.handle)")
                    .font(.headline)
                Text("wants to connect with you")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button("Decline", role: .destructive, action: onResolved)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                Button("Accept", action: onResolved)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)

            Spacer()
        }
    }
}

//
// Variant B: "Search-First Wizard" — the invite screen leads with handle
// search; the Invite Link is secondary, tucked into a disclosure group.
// Skip is deliberately de-emphasized. The pending-request interaction is a
// full-screen takeover rather than a sheet, with large stacked buttons.


struct VariantB_SearchFirstWizardFlow: View {
    private enum Step {
        case accountCreation, invite, pendingRequest, home
    }

    @State private var step: Step = .accountCreation

    var body: some View {
        NavigationStack {
            switch step {
            case .accountCreation:
                AccountCreationScreenB {
                    step = .invite
                }
            case .invite:
                InviteFriendsScreenB {
                    step = PrototypeMockData.incomingRequests.isEmpty ? .home : .pendingRequest
                }
            case .pendingRequest:
                if let request = PrototypeMockData.incomingRequests.first {
                    PendingRequestScreenB(request: request) {
                        step = .home
                    }
                }
            case .home:
                HomeScreenB()
            }
        }
    }
}

// MARK: - 1. Account creation

private struct AccountCreationScreenB: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.indigo, .purple.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()

                Text("Wake Mate")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text("A voice you love, right when you wake up.")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                Button(action: onContinue) {
                    HStack {
                        Image(systemName: "apple.logo")
                        Text("Sign in with Apple")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - 2. Invite friends (skippable)

private struct InviteFriendsScreenB: View {
    let onDone: () -> Void

    @State private var searchText = ""
    @State private var showInviteLinkSection = false
    @State private var requestSent = false

    private var exactMatch: Bool {
        searchText.lowercased() == PrototypeMockData.searchableHandle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Find your first friend")
                    .font(.title.bold())
                Text("Search by their exact @handle.")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 12)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("@handle", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.title3)
            }
            .padding(14)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

            if !searchText.isEmpty {
                Group {
                    if exactMatch {
                        HStack {
                            Circle()
                                .fill(.tint.opacity(0.15))
                                .frame(width: 36, height: 36)
                                .overlay(Text("M").font(.headline).foregroundStyle(.tint))
                            Text("@\(PrototypeMockData.searchableHandle)")
                                .fontWeight(.medium)
                            Spacer()
                            Button(requestSent ? "Sent" : "Add") {
                                requestSent = true
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(requestSent)
                        }
                        .padding(12)
                        .background(.background, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
                    } else {
                        Text("No exact match for \"\(searchText)\".")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            DisclosureGroup("Or invite someone new", isExpanded: $showInviteLinkSection) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Share your personal link — it works even if they don't have Wake Mate yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ShareLink(item: PrototypeMockData.currentUser.inviteLinkURL) {
                        Label("Share Invite Link", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 8)
            }
            .font(.subheadline.weight(.medium))

            Spacer()

            Button("Skip for now", action: onDone)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
        }
        .padding()
    }
}

// MARK: - 3. Pending request (full-screen takeover)

private struct PendingRequestScreenB: View {
    let request: MockFriendRequest
    let onResolved: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Circle()
                .fill(.tint.opacity(0.15))
                .frame(width: 120, height: 120)
                .overlay(
                    Text(request.displayName.prefix(1))
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.tint)
                )

            VStack(spacing: 6) {
                Text(request.displayName)
                    .font(.title.bold())
                Text("@\(request.handle) wants to be your Wake Mate friend")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            VStack(spacing: 12) {
                Button("Accept", action: onResolved)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                Button("Decline", role: .destructive, action: onResolved)
                    .font(.subheadline)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)

            // Swipe-down-to-dismiss on a real takeover would mean "decide
            // later", not decline — noted here since this prototype has no
            // dismiss gesture wired up.
        }
    }
}

// MARK: - 4. Home

private struct HomeScreenB: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            Text("You're all set")
                .font(.title2.bold())
            Text("(Home screen placeholder)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

//
// Variant C: "Inline Minimal" — the invite screen is a single compact
// column with search-as-you-type, and Skip lives in the nav bar instead of
// being its own button. The pending-request interaction is a list screen
// (handles several requests at once) with inline accept/decline icons and
// swipe actions, rather than a one-at-a-time modal.


struct VariantC_InlineMinimalFlow: View {
    private enum Step {
        case accountCreation, invite, requests
    }

    @State private var step: Step = .accountCreation

    var body: some View {
        NavigationStack {
            switch step {
            case .accountCreation:
                AccountCreationScreenC {
                    step = .invite
                }
            case .invite:
                InviteFriendsScreenC {
                    step = .requests
                }
            case .requests:
                FriendRequestsScreenC()
            }
        }
    }
}

// MARK: - 1. Account creation

private struct AccountCreationScreenC: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Wake Mate")
                .font(.title.bold())

            Text("Wake up to a friend's voice.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: onContinue) {
                Label("Continue with Apple", systemImage: "apple.logo")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 60)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - 2. Invite friends (skippable via nav bar)

private struct InviteFriendsScreenC: View {
    let onDone: () -> Void

    @State private var searchText = ""
    @State private var addedHandle: String?

    private var exactMatch: Bool {
        !searchText.isEmpty && searchText.lowercased() == PrototypeMockData.searchableHandle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Your handle, inline, with a share icon — no card, no section.
            HStack {
                Text("Your handle:")
                    .foregroundStyle(.secondary)
                Text("@\(PrototypeMockData.currentUser.handle)")
                    .fontWeight(.semibold)
                Spacer()
                ShareLink(item: PrototypeMockData.currentUser.inviteLinkURL) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            .font(.subheadline)

            Divider()

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search a handle to add", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if exactMatch {
                    Button(addedHandle == searchText ? "Added" : "Add") {
                        addedHandle = searchText
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(addedHandle == searchText)
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Add a friend")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Skip", action: onDone)
            }
        }
    }
}

// MARK: - 3. Pending requests (list, inline accept/decline)

private struct FriendRequestsScreenC: View {
    @State private var requests = PrototypeMockData.incomingRequests

    var body: some View {
        Group {
            if requests.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.green)
                    Text("No pending requests")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        ForEach(requests) { request in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(.tint.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                    .overlay(Text(request.displayName.prefix(1)).font(.subheadline.bold()).foregroundStyle(.tint))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(request.displayName)
                                        .fontWeight(.medium)
                                    Text("@\(request.handle)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button {
                                    resolve(request)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    resolve(request)
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                                .buttonStyle(.plain)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Decline", role: .destructive) { resolve(request) }
                                Button("Accept") { resolve(request) }
                                    .tint(.green)
                            }
                        }
                    } header: {
                        Text("Friend requests")
                    }
                }
            }
        }
        .navigationTitle("Requests")
    }

    private func resolve(_ request: MockFriendRequest) {
        requests.removeAll { $0.id == request.id }
    }
}

