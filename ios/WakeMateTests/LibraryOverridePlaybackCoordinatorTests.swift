import XCTest
@testable import WakeMate

@MainActor
final class LibraryOverridePlaybackCoordinatorTests: XCTestCase {
    func test_playIfNeeded_doesNothing_whenNoAlarmIsActive() async {
        let alarmService = MockAlarmService()
        alarmService.alarmsToReturn = [makeAlarm(mode: .libraryOverride, libraryOverrideAlarmCallID: UUID())]
        let alarmCallService = MockAlarmCallService()
        let activity = MockAlarmActivityTracker()
        let coordinator = LibraryOverridePlaybackCoordinator(
            alarmService: alarmService,
            alarmCallService: alarmCallService,
            activityTracking: activity
        )

        await coordinator.playIfNeeded()

        XCTAssertEqual(activity.refreshCallCount, 1)
        XCTAssertFalse(alarmCallService.didFetchAlarmCall)
    }

    func test_playIfNeeded_doesNothing_forAnActiveAutoPlayAlarm() async {
        let alarmService = MockAlarmService()
        let alarm = makeAlarm(mode: .autoPlay, libraryOverrideAlarmCallID: nil)
        alarmService.alarmsToReturn = [alarm]
        let alarmCallService = MockAlarmCallService()
        let activity = MockAlarmActivityTracker()
        activity.activeIDs = [alarm.id]
        let coordinator = LibraryOverridePlaybackCoordinator(
            alarmService: alarmService,
            alarmCallService: alarmCallService,
            activityTracking: activity
        )

        await coordinator.playIfNeeded()

        XCTAssertFalse(alarmCallService.didFetchAlarmCall)
    }

    func test_playIfNeeded_doesNothing_forAnActiveLibraryOverrideAlarmWithNoClip() async {
        let alarmService = MockAlarmService()
        let alarm = makeAlarm(mode: .libraryOverride, libraryOverrideAlarmCallID: nil)
        alarmService.alarmsToReturn = [alarm]
        let alarmCallService = MockAlarmCallService()
        let activity = MockAlarmActivityTracker()
        activity.activeIDs = [alarm.id]
        let coordinator = LibraryOverridePlaybackCoordinator(
            alarmService: alarmService,
            alarmCallService: alarmCallService,
            activityTracking: activity
        )

        await coordinator.playIfNeeded()

        XCTAssertFalse(alarmCallService.didFetchAlarmCall)
    }

    func test_playIfNeeded_fetchesAndDownloadsClip_forAnActiveLibraryOverrideAlarm() async {
        let alarmService = MockAlarmService()
        let clipID = UUID()
        let alarm = makeAlarm(mode: .libraryOverride, libraryOverrideAlarmCallID: clipID)
        alarmService.alarmsToReturn = [alarm]
        let alarmCallService = MockAlarmCallService()
        alarmCallService.fetchResult = .success(
            AlarmCall(id: clipID, ownerID: alarm.ownerID, storagePath: "user/clip.m4a", durationSeconds: 5, createdAt: Date())
        )
        alarmCallService.downloadResult = .success(Data([0x00]))
        let activity = MockAlarmActivityTracker()
        activity.activeIDs = [alarm.id]
        let coordinator = LibraryOverridePlaybackCoordinator(
            alarmService: alarmService,
            alarmCallService: alarmCallService,
            activityTracking: activity
        )

        await coordinator.playIfNeeded()

        XCTAssertTrue(alarmCallService.didFetchAlarmCall)
        XCTAssertEqual(alarmCallService.lastFetchedAlarmCallID, clipID)
        XCTAssertEqual(alarmCallService.lastDownloadedStoragePath, "user/clip.m4a")
    }

    private func makeAlarm(mode: AlarmMode, libraryOverrideAlarmCallID: UUID?) -> Alarm {
        Alarm(
            id: UUID(),
            ownerID: UUID(),
            label: "Weekdays",
            wakeTime: WakeTime(hour: 7, minute: 0),
            repeatDays: [],
            mode: mode,
            libraryOverrideAlarmCallID: libraryOverrideAlarmCallID,
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
        throw TestError.boom
    }

    func updateAlarm(
        id: UUID,
        label: String?,
        wakeTime: WakeTime,
        repeatDays: [Int],
        mode: AlarmMode,
        libraryOverrideAlarmCallID: UUID?
    ) async throws -> Alarm {
        throw TestError.boom
    }

    func deleteAlarm(id: UUID) async throws {}
}

private final class MockAlarmCallService: AlarmCallServicing, @unchecked Sendable {
    var fetchResult: Result<AlarmCall, Error> = .failure(TestError.boom)
    var downloadResult: Result<Data, Error> = .failure(TestError.boom)
    private(set) var didFetchAlarmCall = false
    private(set) var lastFetchedAlarmCallID: UUID?
    private(set) var lastDownloadedStoragePath: String?

    func upload(fileURL: URL, durationSeconds: Double) async throws -> AlarmCall {
        throw TestError.boom
    }

    func listLibrary() async throws -> [LibraryClip] {
        []
    }

    func fetchAlarmCall(id: UUID) async throws -> AlarmCall {
        didFetchAlarmCall = true
        lastFetchedAlarmCallID = id
        return try fetchResult.get()
    }

    func downloadClipData(storagePath: String) async throws -> Data {
        lastDownloadedStoragePath = storagePath
        return try downloadResult.get()
    }
}

private final class MockAlarmActivityTracker: AlarmActivityTracking, @unchecked Sendable {
    var activeIDs: Set<UUID> = []
    private(set) var refreshCallCount = 0

    func refreshActiveAlarms() async {
        refreshCallCount += 1
    }

    func isActive(alarmID: UUID) -> Bool {
        activeIDs.contains(alarmID)
    }
}
