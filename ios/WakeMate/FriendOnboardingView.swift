import SwiftUI
import UIKit

/// Inline Minimal layout: compact single column, Skip always available,
/// Invite Link as a prominent inline row. Shown automatically once, right
/// after a fresh sign-up (see AppState.flow), and reopenable any time after
/// via HomeView's "Add a Friend" button.
struct FriendOnboardingView: View {
    @StateObject private var viewModel: FriendOnboardingViewModel
    let onFinish: () -> Void
    @State private var didCopyInviteCode = false

    init(friendService: FriendServicing, onFinish: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: FriendOnboardingViewModel(friendService: friendService))
        self.onFinish = onFinish
    }

    var body: some View {
        Group {
            if let resolvedInvite = viewModel.resolvedInvite {
                pendingAcceptView(for: resolvedInvite)
            } else {
                inviteSearchView
            }
        }
        .task { await viewModel.loadMyProfile() }
        .onChange(of: viewModel.inviteAccepted) { _, accepted in
            if accepted { onFinish() }
        }
    }

    private var inviteSearchView: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Find a friend")
                .font(.title2.bold())
            Text("Search their exact handle, or share your invite link.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let myHandle = viewModel.myHandle {
                VStack(spacing: 2) {
                    Text("Your handle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(myHandle)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("Their handle", text: $viewModel.handleQuery)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                    Button("Search") { Task { await viewModel.searchByHandle() } }
                        .disabled(viewModel.handleQuery.isEmpty || viewModel.isBusy)
                }

                switch viewModel.searchState {
                case .idle:
                    EmptyView()
                case .notFound:
                    Text("No one has that handle.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                case .found(let profile):
                    HStack {
                        Text(profile.handle)
                        Spacer()
                        Button("Send Request") { Task { await viewModel.sendRequest(to: profile) } }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.isBusy)
                    }
                case .requestSent(let profile):
                    Text("Request sent to \(profile.handle).")
                        .font(.footnote)
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 32)

            Divider().padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 8) {
                Text("Your invite link")
                    .font(.subheadline.bold())
                if let myInviteCode = viewModel.myInviteCode {
                    HStack {
                        Text(myInviteCode)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = myInviteCode
                            didCopyInviteCode = true
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                didCopyInviteCode = false
                            }
                        } label: {
                            Label(didCopyInviteCode ? "Copied" : "Copy", systemImage: didCopyInviteCode ? "checkmark" : "doc.on.doc")
                                .font(.footnote)
                        }
                    }
                } else {
                    ProgressView()
                }

                HStack {
                    TextField("Enter a friend's invite code", text: $viewModel.inviteCodeQuery)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                    Button("Use Code") { Task { await viewModel.resolveInviteCode() } }
                        .disabled(viewModel.inviteCodeQuery.isEmpty || viewModel.isBusy)
                }
            }
            .padding(.horizontal, 32)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button("Skip", action: onFinish)
                .font(.footnote)
                .padding(.bottom, 32)
        }
    }

    private func pendingAcceptView(for profile: FriendProfile) -> some View {
        // The current user is the one who typed in someone else's invite
        // code, so they're the one proposing the connection here — not the
        // other way around. See FriendOnboardingViewModel.declineResolvedInvite.
        VStack(spacing: 20) {
            Spacer()
            Text("Connect with \(profile.handle)?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Text("They shared this invite code with you.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
            }

            HStack(spacing: 16) {
                Button("Cancel", role: .cancel) { viewModel.declineResolvedInvite() }
                    .disabled(viewModel.isBusy)
                Button("Connect") { Task { await viewModel.acceptResolvedInvite() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isBusy)
            }
            Spacer()
        }
    }
}
