import XCTest
@testable import WakeMate

@MainActor
final class LibraryViewModelTests: XCTestCase {
    func test_load_populatesClips_onSuccess() async {
        let service = MockAlarmCallService()
        let clip = LibraryClip(id: UUID(), storagePath: "user/clip.m4a", durationSeconds: 5, source: .created, addedAt: Date())
        service.libraryResult = .success([clip])
        let viewModel = makeViewModel(alarmCallService: service)

        await viewModel.load()

        XCTAssertEqual(viewModel.clips, [clip])
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_load_surfacesError_onFailure() async {
        let service = MockAlarmCallService()
        service.libraryResult = .failure(TestError.boom)
        let viewModel = makeViewModel(alarmCallService: service)

        await viewModel.load()

        XCTAssertTrue(viewModel.clips.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func test_deleteClip_removesItFromClips_onSuccess() async {
        let service = MockAlarmCallService()
        let clip = LibraryClip(id: UUID(), storagePath: "user/clip.m4a", durationSeconds: 5, source: .created, addedAt: Date())
        let other = LibraryClip(id: UUID(), storagePath: "user/other.m4a", durationSeconds: 5, source: .created, addedAt: Date())
        service.libraryResult = .success([clip, other])
        let viewModel = makeViewModel(alarmCallService: service)
        await viewModel.load()

        await viewModel.deleteClip(clip)

        XCTAssertEqual(viewModel.clips, [other])
        XCTAssertEqual(service.lastDeletedID, clip.id)
        XCTAssertEqual(service.lastDeletedStoragePath, clip.storagePath)
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_deleteClip_surfacesError_andKeepsClip_onFailure() async {
        let service = MockAlarmCallService()
        let clip = LibraryClip(id: UUID(), storagePath: "user/clip.m4a", durationSeconds: 5, source: .created, addedAt: Date())
        service.libraryResult = .success([clip])
        service.deleteResult = .failure(TestError.boom)
        let viewModel = makeViewModel(alarmCallService: service)
        await viewModel.load()

        await viewModel.deleteClip(clip)

        XCTAssertEqual(viewModel.clips, [clip])
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func test_share_sendsToResolvedRecipient_onSuccess() async {
        let friendService = MockFriendService()
        let recipientID = UUID()
        friendService.searchResult = .success(FriendProfile(userID: recipientID, handle: "friend"))
        let shareService = MockShareService()
        let viewModel = makeViewModel(shareService: shareService, friendService: friendService)
        let clip = LibraryClip(id: UUID(), storagePath: "user/clip.m4a", durationSeconds: 5, source: .created, addedAt: Date())

        let sent = await viewModel.share(clip: clip, toHandle: "friend")

        XCTAssertTrue(sent)
        XCTAssertEqual(shareService.lastAlarmCallID, clip.id)
        XCTAssertEqual(shareService.lastRecipientID, recipientID)
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_share_surfacesFriendlyError_whenHandleNotFound() async {
        let friendService = MockFriendService()
        friendService.searchResult = .success(nil)
        let shareService = MockShareService()
        let viewModel = makeViewModel(shareService: shareService, friendService: friendService)
        let clip = LibraryClip(id: UUID(), storagePath: "user/clip.m4a", durationSeconds: 5, source: .created, addedAt: Date())

        let sent = await viewModel.share(clip: clip, toHandle: "nobody")

        XCTAssertFalse(sent)
        XCTAssertFalse(shareService.createShareCalled)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func test_share_surfacesError_onCreateShareFailure() async {
        let friendService = MockFriendService()
        friendService.searchResult = .success(FriendProfile(userID: UUID(), handle: "friend"))
        let shareService = MockShareService()
        shareService.createShareResult = .failure(TestError.boom)
        let viewModel = makeViewModel(shareService: shareService, friendService: friendService)
        let clip = LibraryClip(id: UUID(), storagePath: "user/clip.m4a", durationSeconds: 5, source: .created, addedAt: Date())

        let sent = await viewModel.share(clip: clip, toHandle: "friend")

        XCTAssertFalse(sent)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    private func makeViewModel(
        alarmCallService: AlarmCallServicing = MockAlarmCallService(),
        shareService: ShareServicing = MockShareService(),
        friendService: FriendServicing = MockFriendService()
    ) -> LibraryViewModel {
        LibraryViewModel(alarmCallService: alarmCallService, shareService: shareService, friendService: friendService)
    }
}

private enum TestError: Error, LocalizedError {
    case boom
    var errorDescription: String? { "Something went wrong." }
}

private final class MockAlarmCallService: AlarmCallServicing, @unchecked Sendable {
    var libraryResult: Result<[LibraryClip], Error> = .success([])
    var deleteResult: Result<Void, Error> = .success(())
    private(set) var lastDeletedID: UUID?
    private(set) var lastDeletedStoragePath: String?

    func upload(fileURL: URL, durationSeconds: Double, title: String?) async throws -> AlarmCall {
        throw TestError.boom
    }

    func listLibrary() async throws -> [LibraryClip] {
        try libraryResult.get()
    }

    func fetchAlarmCall(id: UUID) async throws -> AlarmCall {
        throw TestError.boom
    }

    func downloadClipData(storagePath: String) async throws -> Data {
        throw TestError.boom
    }

    func deleteClip(id: UUID, storagePath: String) async throws {
        lastDeletedID = id
        lastDeletedStoragePath = storagePath
        try deleteResult.get()
    }
}

private final class MockShareService: ShareServicing, @unchecked Sendable {
    var createShareResult: Result<UUID, Error> = .success(UUID())
    private(set) var createShareCalled = false
    private(set) var lastAlarmCallID: UUID?
    private(set) var lastRecipientID: UUID?

    @discardableResult
    func createShare(alarmCallID: UUID, recipientID: UUID) async throws -> UUID {
        createShareCalled = true
        lastAlarmCallID = alarmCallID
        lastRecipientID = recipientID
        return try createShareResult.get()
    }

    func downloadURL(shareID: UUID) async throws -> URL {
        throw TestError.boom
    }
}

private final class MockFriendService: FriendServicing, @unchecked Sendable {
    var searchResult: Result<FriendProfile?, Error> = .success(nil)

    func searchProfile(byHandle handle: String) async throws -> FriendProfile? {
        try searchResult.get()
    }

    func myProfile() async throws -> (handle: String, inviteCode: String) {
        throw TestError.boom
    }

    func resolveInviteCode(_ code: String) async throws -> FriendProfile? {
        throw TestError.boom
    }

    func sendFriendRequest(toUserID userID: UUID) async throws {
        throw TestError.boom
    }

    func acceptInvite(code: String) async throws {
        throw TestError.boom
    }

    func pendingIncomingRequests() async throws -> [IncomingFriendRequest] {
        throw TestError.boom
    }

    func respond(toRequestID requestID: UUID, accept: Bool) async throws {
        throw TestError.boom
    }
}
