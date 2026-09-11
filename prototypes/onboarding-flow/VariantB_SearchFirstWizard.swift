// PROTOTYPE — throwaway. See README.md.
//
// Variant B: "Search-First Wizard" — the invite screen leads with handle
// search; the Invite Link is secondary, tucked into a disclosure group.
// Skip is deliberately de-emphasized. The pending-request interaction is a
// full-screen takeover rather than a sheet, with large stacked buttons.

import SwiftUI

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
