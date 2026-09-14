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
}

private enum TestError: Error, LocalizedError {
    case boom
    var errorDescription: String? { "Something went wrong." }
}

private final class MockAlarmCallService: AlarmCallServicing, @unchecked Sendable {
    var libraryResult: Result<[LibraryClip], Error> = .success([])

    func upload(fileURL: URL, durationSeconds: Double) async throws -> AlarmCall {
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
}
