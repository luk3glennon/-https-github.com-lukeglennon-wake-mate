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
    let alarmService: AlarmServicing
    let alarmSyncCoordinator: AlarmSyncCoordinating
    let onSignOut: () -> Void
    @State private var isAddingFriend = false

    init(
        session: Session,
        friendService: FriendServicing,
        alarmService: AlarmServicing,
        alarmSyncCoordinator: AlarmSyncCoordinating,
        onSignOut: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(friendService: friendService))
        self.session = session
        self.friendService = friendService
        self.alarmService = alarmService
        self.alarmSyncCoordinator = alarmSyncCoordinator
        self.onSignOut = onSignOut
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !viewModel.pendingRequests.isEmpty {
                        friendRequestsSection
                    }

                    AlarmListView(alarmService: alarmService, syncCoordinator: alarmSyncCoordinator)
                }
                .padding()
            }
            .navigationTitle("Wake Mate")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Add Friend") { isAddingFriend = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out", role: .destructive, action: onSignOut)
                }
            }
        }
        .task { await viewModel.loadPendingRequests() }
        .sheet(isPresented: $isAddingFriend) {
            FriendOnboardingView(friendService: friendService, onFinish: { isAddingFriend = false })
        }
    }

    private var friendRequestsSection: some View {
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
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }
}
