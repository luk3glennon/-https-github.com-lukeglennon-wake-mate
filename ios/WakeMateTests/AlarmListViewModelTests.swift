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
        let viewModel = AlarmListViewModel(alarmService: service, syncCoordinator: sync)

        await viewModel.load()

        XCTAssertEqual(viewModel.alarms.map(\.id), [late.id, early.id])
        XCTAssertEqual(sync.syncCallCount, 1)
    }

    func test_createAlarm_appendsInSortedOrder_andSyncs() async {
        let service = MockAlarmService()
        let existing = makeAlarm(hour: 6)
        service.alarmsToReturn = [existing]
        let sync = MockSyncCoordinator()
        let viewModel = AlarmListViewModel(alarmService: service, syncCoordinator: sync)
        await viewModel.load()

        let created = makeAlarm(hour: 5)
        service.createResult = .success(created)
        await viewModel.createAlarm(label: "Early", wakeTime: created.wakeTime, repeatDays: [])

        XCTAssertEqual(viewModel.alarms.map(\.id), [created.id, existing.id])
        XCTAssertEqual(sync.syncCallCount, 2)
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_createAlarm_surfacesError_onFailure() async {
        let service = MockAlarmService()
        service.createResult = .failure(TestError.boom)
        let sync = MockSyncCoordinator()
        let viewModel = AlarmListViewModel(alarmService: service, syncCoordinator: sync)

        await viewModel.createAlarm(label: nil, wakeTime: WakeTime(hour: 7, minute: 0), repeatDays: [])

        XCTAssertTrue(viewModel.alarms.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(sync.syncCallCount, 0)
    }

    func test_updateAlarm_replacesRowInPlace_andSyncs() async {
        let service = MockAlarmService()
        let original = makeAlarm(hour: 7, label: "Old")
        service.alarmsToReturn = [original]
        let sync = MockSyncCoordinator()
        let viewModel = AlarmListViewModel(alarmService: service, syncCoordinator: sync)
        await viewModel.load()

        var renamed = original
        renamed.label = "New"
        service.updateResult = .success(renamed)
        await viewModel.updateAlarm(original, label: "New", wakeTime: original.wakeTime, repeatDays: [])

        XCTAssertEqual(viewModel.alarms.first?.label, "New")
        XCTAssertEqual(sync.syncCallCount, 2)
    }

    func test_deleteAlarm_removesRow_andSyncs() async {
        let service = MockAlarmService()
        let alarm = makeAlarm(hour: 7)
        service.alarmsToReturn = [alarm]
        let sync = MockSyncCoordinator()
        let viewModel = AlarmListViewModel(alarmService: service, syncCoordinator: sync)
        await viewModel.load()

        await viewModel.deleteAlarm(alarm)

        XCTAssertTrue(viewModel.alarms.isEmpty)
        XCTAssertEqual(sync.syncCallCount, 2)
    }

    private func makeAlarm(hour: Int, label: String? = "Alarm") -> Alarm {
        Alarm(
            id: UUID(),
            ownerID: UUID(),
            label: label,
            wakeTime: WakeTime(hour: hour, minute: 0),
            repeatDays: [],
            mode: .autoPlay,
            libraryOverrideAlarmCallID: nil,
            snoozeEnabled: true,
            snoozeDurationMinutes: 9,
            createdAt: Date(),
            updatedAt: Date()
        )
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

    func listAlarms() async throws -> [Alarm] {
        alarmsToReturn
    }

    func createAlarm(label: String?, wakeTime: WakeTime, repeatDays: [Int]) async throws -> Alarm {
        try createResult.get()
    }

    func updateAlarm(id: UUID, label: String?, wakeTime: WakeTime, repeatDays: [Int]) async throws -> Alarm {
        try updateResult.get()
    }

    func deleteAlarm(id: UUID) async throws {
        if let deleteError { throw deleteError }
    }
}

private final class MockSyncCoordinator: AlarmSyncCoordinating, @unchecked Sendable {
    private(set) var syncCallCount = 0

    func sync(alarms: [Alarm]) async {
        syncCallCount += 1
    }
}
