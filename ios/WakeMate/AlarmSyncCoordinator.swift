import Foundation

/// Reconciles AlarmKit's scheduled alarms to match a set of `Alarm` rows.
/// Kept free of any `import AlarmKit` so it's unit-testable — the actual
/// AlarmKit calls live behind `AlarmSchedulingServicing`, implemented by
/// `AlarmKitScheduler`.
protocol AlarmSyncCoordinating: Sendable {
    func sync(alarms: [Alarm]) async
}

/// Tracks which Alarms are currently mid-Wake-Event (ringing or snoozed).
/// Backed by AlarmKit's own alert state in production — see
/// `AlarmKitScheduler`.
protocol AlarmActivityTracking: Sendable {
    /// Fetches the current activity snapshot directly from the source of
    /// truth (AlarmKit) before `isActive` is trusted. `AlarmKitScheduler`
    /// also keeps this snapshot fresh via a live update stream, but that
    /// stream's first value can race a cold-launch `sync()` call — calling
    /// this first closes that window rather than relying on the stream
    /// having already delivered something.
    func refreshActiveAlarms() async
    func isActive(alarmID: UUID) -> Bool
}

protocol AlarmSchedulingServicing: Sendable {
    /// Requests AlarmKit authorization if not already determined. Returns
    /// whether scheduling is currently permitted.
    func requestAuthorizationIfNeeded() async -> Bool
    /// IDs of every Alarm AlarmKit currently has scheduled (any state).
    func scheduledAlarmIDs() async -> Set<UUID>
    /// Schedules (or re-schedules, cancel-and-replace) `alarm`. Never called
    /// for an Alarm the activity tracker reports as active — see
    /// AlarmSyncCoordinator.sync.
    func schedule(_ alarm: Alarm) async throws
    func cancel(alarmID: UUID) async throws
}

/// See ADR-0003: an Alarm that's alerting or snoozed must never be
/// cancelled/rescheduled out from under the user — that would abort a wake
/// they haven't acknowledged yet. `sync` is the single choke point every
/// Alarm mutation (create/edit/delete) and future queue-mutation resync
/// (ticket 06/07) funnels through, so that invariant only needs enforcing
/// once, here.
final class AlarmSyncCoordinator: AlarmSyncCoordinating, Sendable {
    private let scheduler: AlarmSchedulingServicing
    private let activity: AlarmActivityTracking

    init(scheduler: AlarmSchedulingServicing, activity: AlarmActivityTracking) {
        self.scheduler = scheduler
        self.activity = activity
    }

    func sync(alarms: [Alarm]) async {
        guard await scheduler.requestAuthorizationIfNeeded() else { return }
        await activity.refreshActiveAlarms()

        let desiredIDs = Set(alarms.map(\.id))
        let scheduledIDs = await scheduler.scheduledAlarmIDs()

        for alarm in alarms where !activity.isActive(alarmID: alarm.id) {
            try? await scheduler.schedule(alarm)
        }

        let staleIDs = scheduledIDs.subtracting(desiredIDs)
        for staleID in staleIDs where !activity.isActive(alarmID: staleID) {
            try? await scheduler.cancel(alarmID: staleID)
        }
    }
}
