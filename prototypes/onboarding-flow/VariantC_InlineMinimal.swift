// PROTOTYPE — throwaway. See README.md.
//
// Variant C: "Inline Minimal" — the invite screen is a single compact
// column with search-as-you-type, and Skip lives in the nav bar instead of
// being its own button. The pending-request interaction is a list screen
// (handles several requests at once) with inline accept/decline icons and
// swipe actions, rather than a one-at-a-time modal.
//
// Updated per ticket 19's resolution:
//   - The pending-request step is conditional: it only appears if account
//     creation resolved an inviter from an Invite Link tap (ticket 16) —
//     otherwise there's nothing that could plausibly be waiting yet, and
//     the step is skipped entirely rather than shown empty.
//   - The Invite Link on the invite screen is now a labeled inline row
//     (still a single row, not a separate card/section) instead of a bare
//     share icon — more noticeable without breaking from this variant's
//     compact, list-first layout.

import SwiftUI

struct VariantC_InlineMinimalFlow: View {
    private enum Step {
        case accountCreation, invite, requests, home
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
                    // Skip the pending-request step entirely when nothing
                    // could plausibly be waiting (organic signup, no
                    // Invite Link tap to resolve an inviter from).
                    step = PrototypeMockData.incomingRequests.isEmpty ? .home : .requests
                }
            case .requests:
                FriendRequestsScreenC {
                    step = .home
                }
            case .home:
                HomeScreenC()
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
            // Your Invite Link — a labeled inline row, one step up from a
            // bare icon, but still a single row rather than its own card.
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Invite Link")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack {
                    Text(PrototypeMockData.currentUser.inviteLinkURL.absoluteString)
                        .font(.subheadline.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    ShareLink(item: PrototypeMockData.currentUser.inviteLinkURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(12)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))

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

// MARK: - 3. Pending requests (only shown when an inviter resolved)

private struct FriendRequestsScreenC: View {
    let onDone: () -> Void

    @State private var requests = PrototypeMockData.incomingRequests

    var body: some View {
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
                // Invite-Link-resolved at signup, so onboarding will only
                // ever seed one row here — this List shape is what carries
                // over for the general Friend Requests screen, once more
                // requests accumulate later via handle search.
                Text("Friend requests")
            }
        }
        .navigationTitle("Requests")
    }

    private func resolve(_ request: MockFriendRequest) {
        requests.removeAll { $0.id == request.id }
        if requests.isEmpty {
            onDone()
        }
    }
}

// MARK: - 4. Home

private struct HomeScreenC: View {
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
