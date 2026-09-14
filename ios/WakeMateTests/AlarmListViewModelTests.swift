import XCTest
@testable import WakeMate

@MainActor
final class AlarmListViewModelTests: XCTestCase {
    func test_load_populatesAlarms_sortedByWakeTime_andSyncs() async {
        let service = MockAlarmService()
        let late = makeAlarm(hour: 9)
        let early = makeAlarm(hour: 6)
        service.alarmsToReturn = [late, early]
        let sync = MockSyncCoordinator()
        let viewModel = makeViewModel(alarmService: service, syncCoordinator: sync)

        await viewModel.load()

        XCTAssertEqual(viewModel.alarms.map(\.id), [late.id, early.id])
        XCTAssertEqual(sync.syncCallCount, 1)
    }

    func test_createAlarm_appendsInSortedOrder_andSyncs() async {
        let service = MockAlarmService()
        let existing = makeAlarm(hour: 6)
        service.alarmsToReturn = [existing]
        let sync = MockSyncCoordinator()
        let viewModel = makeViewModel(alarmService: service, syncCoordinator: sync)
        await viewModel.load()

        let created = makeAlarm(hour: 5)
        service.createResult = .success(created)
        await viewModel.createAlarm(
            label: "Early",
            wakeTime: created.wakeTime,
            repeatDays: [],
            mode: .autoPlay,
            libraryOverrideAlarmCallID: nil
        )

        XCTAssertEqual(viewModel.alarms.map(\.id), [created.id, existing.id])
        XCTAssertEqual(sync.syncCallCount, 2)
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_createAlarm_passesModeAndLibraryOverrideThrough() async {
        let service = MockAlarmService()
        let sync = MockSyncCoordinator()
        let viewModel = makeViewModel(alarmService: service, syncCoordinator: sync)
        let clipID = UUID()
        let created = makeAlarm(hour: 5, mode: .libraryOverride, libraryOverrideAlarmCallID: clipID)
        service.createResult = .success(created)

        await viewModel.createAlarm(
            label: nil,
            wakeTime: created.wakeTime,
            repeatDays: [],
            mode: .libraryOverride,
            libraryOverrideAlarmCallID: clipID
        )

        XCTAssertEqual(service.lastCreateMode, .libraryOverride)
        XCTAssertEqual(service.lastCreateLibraryOverrideAlarmCallID, clipID)
    }

    func test_createAlarm_surfacesError_onFailure() async {
        let service = MockAlarmService()
        service.createResult = .failure(TestError.boom)
        let sync = MockSyncCoordinator()
        let viewModel = makeViewModel(alarmService: service, syncCoordinator: sync)

        await viewModel.createAlarm(
            label: nil,
            wakeTime: WakeTime(hour: 7, minute: 0),
            repeatDays: [],
            mode: .autoPlay,
            libraryOverrideAlarmCallID: nil
        )

        XCTAssertTrue(viewModel.alarms.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(sync.syncCallCount, 0)
    }

    func test_updateAlarm_replacesRowInPlace_andSyncs() async {
        let service = MockAlarmService()
        let original = makeAlarm(hour: 7, label: "Old")
        service.alarmsToReturn = [original]
        let sync = MockSyncCoordinator()
        let viewModel = makeViewModel(alarmService: service, syncCoordinator: sync)
        await viewModel.load()

        var renamed = original
        renamed.label = "New"
        service.updateResult = .success(renamed)
        await viewModel.updateAlarm(
            original,
            label: "New",
            wakeTime: original.wakeTime,
            repeatDays: [],
            mode: .autoPlay,
            libraryOverrideAlarmCallID: nil
        )

        XCTAssertEqual(viewModel.alarms.first?.label, "New")
        XCTAssertEqual(sync.syncCallCount, 2)
    }

    func test_deleteAlarm_removesRow_andSyncs() async {
        let service = MockAlarmService()
        let alarm = makeAlarm(hour: 7)
        service.alarmsToReturn = [alarm]
        let sync = MockSyncCoordinator()
        let viewModel = makeViewModel(alarmService: service, syncCoordinator: sync)
        await viewModel.load()

        await viewModel.deleteAlarm(alarm)

        XCTAssertTrue(viewModel.alarms.isEmpty)
        XCTAssertEqual(sync.syncCallCount, 2)
    }

    func test_loadLibraryClips_populatesClips() async {
        let service = MockAlarmService()
        let alarmCallService = MockAlarmCallService()
        let clip = makeClip()
        alarmCallService.libraryToReturn = [clip]
        let viewModel = makeViewModel(alarmService: service, alarmCallService: alarmCallService)

        await viewModel.loadLibraryClips()

        XCTAssertEqual(viewModel.libraryClips, [clip])
    }

    func test_loadLibraryClips_surfacesError_onFailure() async {
        let service = MockAlarmService()
        let alarmCallService = MockAlarmCallService()
        alarmCallService.libraryResult = .failure(TestError.boom)
        let viewModel = makeViewModel(alarmService: service, alarmCallService: alarmCallService)

        await viewModel.loadLibraryClips()

        XCTAssertTrue(viewModel.libraryClips.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    private func makeViewModel(
        alarmService: AlarmServicing,
        syncCoordinator: AlarmSyncCoordinating = MockSyncCoordinator(),
        alarmCallService: AlarmCallServicing = MockAlarmCallService()
    ) -> AlarmListViewModel {
        AlarmListViewModel(alarmService: alarmService, syncCoordinator: syncCoordinator, alarmCallService: alarmCallService)
    }

    private func makeAlarm(
        hour: Int,
        label: String? = "Alarm",
        mode: AlarmMode = .autoPlay,
        libraryOverrideAlarmCallID: UUID? = nil
    ) -> Alarm {
        Alarm(
            id: UUID(),
            ownerID: UUID(),
            label: label,
            wakeTime: WakeTime(hour: hour, minute: 0),
            repeatDays: [],
            mode: mode,
            libraryOverrideAlarmCallID: libraryOverrideAlarmCallID,
            snoozeEnabled: true,
            snoozeDurationMinutes: 9,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func makeClip() -> LibraryClip {
        LibraryClip(id: UUID(), storagePath: "user/clip.m4a", durationSeconds: 5, source: .created, addedAt: Date())
    }
}

private enum TestError: Error, LocalizedError {
    case boom
    var errorDescription: String? { "Something went wrong." }
}

private final class MockAlarmService: AlarmServicing, @unchecked Sendable {
    var alarmsToReturn: [Alarm] = []
    var createResult: Result<Alarm, Error> = .failure(TestError.boom)
    var updateResult: Result<Alarm, Error> = .failure(TestError.boom)
    var deleteError: Error?
    private(set) var lastCreateMode: AlarmMode?
    private(set) var lastCreateLibraryOverrideAlarmCallID: UUID?

    func listAlarms() async throws -> [Alarm] {
        alarmsToReturn
    }

    func createAlarm(
        label: String?,
        wakeTime: WakeTime,
        repeatDays: [Int],
        mode: AlarmMode,
        libraryOverrideAlarmCallID: UUID?
    ) async throws -> Alarm {
        lastCreateMode = mode
        lastCreateLibraryOverrideAlarmCallID = libraryOverrideAlarmCallID
        return try createResult.get()
    }

    func updateAlarm(
        id: UUID,
        label: String?,
        wakeTime: WakeTime,
        repeatDays: [Int],
        mode: AlarmMode,
        libraryOverrideAlarmCallID: UUID?
    ) async throws -> Alarm {
        try updateResult.get()
    }

    func deleteAlarm(id: UUID) async throws {
        if let deleteError { throw deleteError }
    }
}

private final class MockAlarmCallService: AlarmCallServicing, @unchecked Sendable {
    var uploadResult: Result<AlarmCall, Error> = .failure(TestError.boom)
    var libraryToReturn: [LibraryClip] = []
    var libraryResult: Result<[LibraryClip], Error>?
    var fetchResult: Result<AlarmCall, Error> = .failure(TestError.boom)
    var downloadResult: Result<Data, Error> = .failure(TestError.boom)

    func upload(fileURL: URL, durationSeconds: Double) async throws -> AlarmCall {
        try uploadResult.get()
    }

    func listLibrary() async throws -> [LibraryClip] {
        if let libraryResult {
            return try libraryResult.get()
        }
        return libraryToReturn
    }

    func fetchAlarmCall(id: UUID) async throws -> AlarmCall {
        try fetchResult.get()
    }

    func downloadClipData(storagePath: String) async throws -> Data {
        try downloadResult.get()
    }
}

private final class MockSyncCoordinator: AlarmSyncCoordinating, @unchecked Sendable {
    private(set) var syncCallCount = 0

    func sync(alarms: [Alarm]) async {
        syncCallCount += 1
    }
}
