import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var pendingRequests: [IncomingFriendRequest] = []
    @Published var errorMessage: String?
    @Published private(set) var isBusy = false

    private let friendService: FriendServicing

    init(friendService: FriendServicing) {
        self.friendService = friendService
    }

    func loadPendingRequests() async {
        do {
            pendingRequests = try await friendService.pendingIncomingRequests()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func respond(to request: IncomingFriendRequest, accept: Bool) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await friendService.respond(toRequestID: request.id, accept: accept)
            pendingRequests.removeAll { $0.id == request.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
