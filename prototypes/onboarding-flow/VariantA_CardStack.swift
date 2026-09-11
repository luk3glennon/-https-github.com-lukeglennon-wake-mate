// PROTOTYPE — throwaway. See README.md.
//
// Variant A: "Card Stack" — the invite screen is two distinct cards (your
// Invite Link, add-by-Handle search). The pending-request accept/decline
// interaction is a modal sheet with side-by-side buttons.

import SwiftUI

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
