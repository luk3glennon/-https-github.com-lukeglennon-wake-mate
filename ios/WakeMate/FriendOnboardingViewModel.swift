import Foundation

@MainActor
final class FriendOnboardingViewModel: ObservableObject {
    enum SearchState: Equatable {
        case idle
        case notFound
        case found(FriendProfile)
        case requestSent(FriendProfile)
    }

    @Published var handleQuery = ""
    @Published var inviteCodeQuery = ""
    @Published private(set) var searchState: SearchState = .idle
    /// Set only by resolving a code (read-only lookup) — never touches
    /// friend_connections. Accepting/declining is the only write path.
    @Published private(set) var resolvedInvite: FriendProfile?
    @Published private(set) var myInviteCode: String?
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?
    @Published private(set) var inviteAccepted = false

    private let friendService: FriendServicing

    init(friendService: FriendServicing) {
        self.friendService = friendService
    }

    func loadMyInviteCode() async {
        do {
            myInviteCode = try await friendService.myInviteCode()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func searchByHandle() async {
        guard !handleQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            if let profile = try await friendService.searchProfile(byHandle: handleQuery) {
                searchState = .found(profile)
            } else {
                searchState = .notFound
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendRequest(to profile: FriendProfile) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await friendService.sendFriendRequest(toUserID: profile.userID)
            searchState = .requestSent(profile)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resolveInviteCode() async {
        guard !inviteCodeQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            if let profile = try await friendService.resolveInviteCode(inviteCodeQuery) {
                resolvedInvite = profile
            } else {
                errorMessage = "That invite code doesn't match anyone."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptResolvedInvite() async {
        guard resolvedInvite != nil else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await friendService.acceptInvite(code: inviteCodeQuery)
            inviteAccepted = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// No network call — declining an invite-link connection leaves no
    /// trace, by design (see ticket 03: "no auto-created connections").
    func declineResolvedInvite() {
        resolvedInvite = nil
        inviteCodeQuery = ""
    }
}
