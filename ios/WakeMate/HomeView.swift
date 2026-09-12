import SwiftUI
import Supabase

/// Home stub — ticket 01 only requires landing here after signup with a
/// real account behind it. Real home-screen content (alarms, queue) is
/// later tickets. The pending-requests list below is ticket 03's: it's the
/// only place a handle-search-based request (as opposed to an invite link,
/// which resolves to 'accepted' immediately) can actually be accepted.
struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    let session: Session
    let onSignOut: () -> Void

    init(session: Session, friendService: FriendServicing, onSignOut: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(friendService: friendService))
        self.session = session
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
    }
}
