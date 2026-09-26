import XCTest
@testable import WakeMate

@MainActor
final class LibraryViewModelTests: XCTestCase {
    func test_load_populatesClips_onSuccess() async {
        let service = MockAlarmCallService()
        let clip = LibraryClip(id: UUID(), storagePath: "user/clip.m4a", durationSeconds: 5, source: .created, addedAt: Date())
        service.libraryResult = .success([clip])
        let viewModel = LibraryViewModel(alarmCallService: service)

        await viewModel.load()

        XCTAssertEqual(viewModel.clips, [clip])
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_load_surfacesError_onFailure() async {
        let service = MockAlarmCallService()
        service.libraryResult = .failure(TestError.boom)
        let viewModel = LibraryViewModel(alarmCallService: service)

        await viewModel.load()

        XCTAssertTrue(viewModel.clips.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func test_deleteClip_removesItFromClips_onSuccess() async {
        let service = MockAlarmCallService()
        let clip = LibraryClip(id: UUID(), storagePath: "user/clip.m4a", durationSeconds: 5, source: .created, addedAt: Date())
        let other = LibraryClip(id: UUID(), storagePath: "user/other.m4a", durationSeconds: 5, source: .created, addedAt: Date())
        service.libraryResult = .success([clip, other])
        let viewModel = LibraryViewModel(alarmCallService: service)
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
        let viewModel = LibraryViewModel(alarmCallService: service)
        await viewModel.load()

        await viewModel.deleteClip(clip)

        XCTAssertEqual(viewModel.clips, [clip])
        XCTAssertNotNil(viewModel.errorMessage)
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
