import SwiftUI
import Supabase

/// Home stub — ticket 01 only requires landing here after signup with a
/// real account behind it. Real home-screen content (alarms, queue) is
/// later tickets. The pending-requests list below is ticket 03's: it's the
/// only place a handle-search-based request (as opposed to an invite link,
/// which resolves to 'accepted' immediately) can actually be accepted.
///
/// "Add a Friend" reopens FriendOnboardingView's search/invite-code screen
/// as a sheet — that screen only auto-appears once, right after a fresh
/// sign-up (see RootView's Flow), so a returning user who already has an
/// account (i.e. every real test of this feature, per the Testing note in
/// ticket 03) would otherwise have no way back into it. Found 2026-09-12
/// when a real sign-in landed on this screen with nothing but Sign Out.
struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    let session: Session
    let friendService: FriendServicing
    let onSignOut: () -> Void
    @State private var isAddingFriend = false

    init(session: Session, friendService: FriendServicing, onSignOut: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(friendService: friendService))
        self.session = session
        self.friendService = friendService
        self.onSignOut = onSignOut
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            Text("You're all set")
                .font(.title2.bold())
            Text(session.user.email ?? "")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Add a Friend") { isAddingFriend = true }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)

            if !viewModel.pendingRequests.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Friend requests")
                        .font(.subheadline.bold())
                    ForEach(viewModel.pendingRequests) { request in
                        HStack {
                            Text(request.requesterHandle)
                            Spacer()
                            Button("Decline") { Task { await viewModel.respond(to: request, accept: false) } }
                                .disabled(viewModel.isBusy)
                            Button("Accept") { Task { await viewModel.respond(to: request, accept: true) } }
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.isBusy)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 16)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
            }

            Button("Sign Out", role: .destructive, action: onSignOut)
                .padding(.top, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await viewModel.loadPendingRequests() }
        .sheet(isPresented: $isAddingFriend) {
            FriendOnboardingView(friendService: friendService, onFinish: { isAddingFriend = false })
        }
    }
}
