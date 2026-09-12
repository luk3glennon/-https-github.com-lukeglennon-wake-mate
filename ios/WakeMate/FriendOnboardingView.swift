import SwiftUI

/// Inline Minimal layout: compact single column, Skip always available,
/// Invite Link as a prominent inline row. Shown once, right after a fresh
/// sign-up — see AppState.flow.
struct FriendOnboardingView: View {
    @StateObject private var viewModel: FriendOnboardingViewModel
    let onFinish: () -> Void

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
        .task { await viewModel.loadMyInviteCode() }
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
                    Text(myInviteCode)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
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
        VStack(spacing: 20) {
            Spacer()
            Text("\(profile.handle) wants to connect")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
            }

            HStack(spacing: 16) {
                Button("Decline", role: .destructive) { viewModel.declineResolvedInvite() }
                    .disabled(viewModel.isBusy)
                Button("Accept") { Task { await viewModel.acceptResolvedInvite() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isBusy)
            }
            Spacer()
        }
    }
}
