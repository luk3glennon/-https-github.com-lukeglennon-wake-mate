import XCTest
@testable import WakeMate

@MainActor
final class FriendOnboardingViewModelTests: XCTestCase {
    func test_searchByHandle_setsFound_whenProfileExists() async {
        let mock = MockFriendService()
        let profile = FriendProfile(userID: UUID(), handle: "alice")
        mock.profileToReturn = profile
        let viewModel = FriendOnboardingViewModel(friendService: mock)
        viewModel.handleQuery = "alice"

        await viewModel.searchByHandle()

        XCTAssertEqual(viewModel.searchState, .found(profile))
    }

    func test_searchByHandle_setsNotFound_whenNoMatch() async {
        let mock = MockFriendService()
        mock.profileToReturn = nil
        let viewModel = FriendOnboardingViewModel(friendService: mock)
        viewModel.handleQuery = "nobody"

        await viewModel.searchByHandle()

        XCTAssertEqual(viewModel.searchState, .notFound)
    }

    func test_sendRequest_movesToRequestSent_onSuccess() async {
        let mock = MockFriendService()
        let profile = FriendProfile(userID: UUID(), handle: "alice")
        let viewModel = FriendOnboardingViewModel(friendService: mock)

        await viewModel.sendRequest(to: profile)

        XCTAssertEqual(mock.sendFriendRequestCallCount, 1)
        XCTAssertEqual(viewModel.searchState, .requestSent(profile))
    }

    func test_resolveInviteCode_setsResolvedInvite_withoutCreatingConnection() async {
        let mock = MockFriendService()
        let profile = FriendProfile(userID: UUID(), handle: "bob")
        mock.profileToReturn = profile
        let viewModel = FriendOnboardingViewModel(friendService: mock)
        viewModel.inviteCodeQuery = "abc123"

        await viewModel.resolveInviteCode()

        XCTAssertEqual(viewModel.resolvedInvite, profile)
        XCTAssertEqual(mock.acceptInviteCallCount, 0)
    }

    func test_declineResolvedInvite_clearsStateWithoutAnyNetworkCall() async {
        let mock = MockFriendService()
        mock.profileToReturn = FriendProfile(userID: UUID(), handle: "bob")
        let viewModel = FriendOnboardingViewModel(friendService: mock)
        viewModel.inviteCodeQuery = "abc123"
        await viewModel.resolveInviteCode()

        viewModel.declineResolvedInvite()

        XCTAssertNil(viewModel.resolvedInvite)
        XCTAssertEqual(mock.acceptInviteCallCount, 0)
        XCTAssertEqual(mock.sendFriendRequestCallCount, 0)
    }

    func test_acceptResolvedInvite_callsAcceptInvite_andSetsInviteAccepted() async {
        let mock = MockFriendService()
        mock.profileToReturn = FriendProfile(userID: UUID(), handle: "bob")
        let viewModel = FriendOnboardingViewModel(friendService: mock)
        viewModel.inviteCodeQuery = "abc123"
        await viewModel.resolveInviteCode()

        await viewModel.acceptResolvedInvite()

        XCTAssertEqual(mock.acceptInviteCallCount, 1)
        XCTAssertTrue(viewModel.inviteAccepted)
    }
}

private final class MockFriendService: FriendServicing, @unchecked Sendable {
    var profileToReturn: FriendProfile?
    private(set) var sendFriendRequestCallCount = 0
    private(set) var acceptInviteCallCount = 0

    func searchProfile(byHandle handle: String) async throws -> FriendProfile? {
        profileToReturn
    }

    func myInviteCode() async throws -> String {
        "own-code"
    }

    func resolveInviteCode(_ code: String) async throws -> FriendProfile? {
        profileToReturn
    }

    func sendFriendRequest(toUserID userID: UUID) async throws {
        sendFriendRequestCallCount += 1
    }

    func acceptInvite(code: String) async throws {
        acceptInviteCallCount += 1
    }

    func pendingIncomingRequests() async throws -> [IncomingFriendRequest] {
        []
    }

    func respond(toRequestID requestID: UUID, accept: Bool) async throws {}
}
