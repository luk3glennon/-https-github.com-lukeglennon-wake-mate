import XCTest
@testable import WakeMate

final class AlarmSyncCoordinatorTests: XCTestCase {
    func test_sync_schedulesEveryIdleAlarm() async {
        let scheduler = MockAlarmScheduler()
        let activity = MockAlarmActivityTracker()
        let coordinator = AlarmSyncCoordinator(scheduler: scheduler, activity: activity)
        let alarms = [makeAlarm(), makeAlarm()]

        await coordinator.sync(alarms: alarms)

        XCTAssertEqual(Set(scheduler.scheduledCallIDs), Set(alarms.map(\.id)))
    }

    func test_sync_neverSchedulesAnAlarmMidWakeEvent() async {
        let scheduler = MockAlarmScheduler()
        let activity = MockAlarmActivityTracker()
        let ringingAlarm = makeAlarm()
        let idleAlarm = makeAlarm()
        activity.activeIDs = [ringingAlarm.id]
        let coordinator = AlarmSyncCoordinator(scheduler: scheduler, activity: activity)

        await coordinator.sync(alarms: [ringingAlarm, idleAlarm])

        XCTAssertFalse(scheduler.scheduledCallIDs.contains(ringingAlarm.id))
        XCTAssertTrue(scheduler.scheduledCallIDs.contains(idleAlarm.id))
    }

    func test_sync_cancelsAlarmsNoLongerInTheList() async {
        let scheduler = MockAlarmScheduler()
        let activity = MockAlarmActivityTracker()
        let removedID = UUID()
        scheduler.preexistingScheduledIDs = [removedID]
        let coordinator = AlarmSyncCoordinator(scheduler: scheduler, activity: activity)

        await coordinator.sync(alarms: [])

        XCTAssertEqual(scheduler.cancelledIDs, [removedID])
    }

    func test_sync_neverCancelsAStaleAlarmMidWakeEvent() async {
        let scheduler = MockAlarmScheduler()
        let activity = MockAlarmActivityTracker()
        let removedButRingingID = UUID()
        scheduler.preexistingScheduledIDs = [removedButRingingID]
        activity.activeIDs = [removedButRingingID]
        let coordinator = AlarmSyncCoordinator(scheduler: scheduler, activity: activity)

        await coordinator.sync(alarms: [])

        XCTAssertTrue(scheduler.cancelledIDs.isEmpty)
    }

    func test_sync_doesNothing_whenAuthorizationIsDenied() async {
        let scheduler = MockAlarmScheduler()
        scheduler.authorizationGranted = false
        let activity = MockAlarmActivityTracker()
        let coordinator = AlarmSyncCoordinator(scheduler: scheduler, activity: activity)

        await coordinator.sync(alarms: [makeAlarm()])

        XCTAssertTrue(scheduler.scheduledCallIDs.isEmpty)
        XCTAssertTrue(scheduler.cancelledIDs.isEmpty)
    }

    private func makeAlarm() -> Alarm {
        Alarm(
            id: UUID(),
            ownerID: UUID(),
            label: "Weekdays",
            wakeTime: WakeTime(hour: 7, minute: 0),
            repeatDays: [2, 3, 4, 5, 6],
            mode: .autoPlay,
            libraryOverrideAlarmCallID: nil,
            snoozeEnabled: true,
            snoozeDurationMinutes: 9,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

private final class MockAlarmScheduler: AlarmSchedulingServicing, @unchecked Sendable {
    var authorizationGranted = true
    var preexistingScheduledIDs: Set<UUID> = []
    private(set) var scheduledCallIDs: [UUID] = []
    private(set) var cancelledIDs: [UUID] = []

    func requestAuthorizationIfNeeded() async -> Bool {
        authorizationGranted
    }

    func scheduledAlarmIDs() async -> Set<UUID> {
        preexistingScheduledIDs.union(scheduledCallIDs)
    }

    func schedule(_ alarm: Alarm) async throws {
        scheduledCallIDs.append(alarm.id)
    }

    func cancel(alarmID: UUID) async throws {
        cancelledIDs.append(alarmID)
    }
}

private final class MockAlarmActivityTracker: AlarmActivityTracking, @unchecked Sendable {
    var activeIDs: Set<UUID> = []

    func refreshActiveAlarms() async {}

    func isActive(alarmID: UUID) -> Bool {
        activeIDs.contains(alarmID)
    }
}
