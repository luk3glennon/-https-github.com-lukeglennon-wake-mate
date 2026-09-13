import AppIntents
import ActivityKit
import AlarmKit

/// App Intents AlarmKit runs when the user taps the alert's Stop/Snooze
/// buttons. These run out-of-process — the app need not be foregrounded —
/// so they can only carry a small Codable payload (the alarm id as a
/// string), never a reference to any live app object. See
/// .scratch/wake-mate/research/alarmkit-api.md §5 for the API this is based
/// on, and AlarmKitScheduler for the other side (schedule/cancel).
struct StopAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop"
    static var openAppWhenRun = false

    @Parameter(title: "alarmID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        alarmID = ""
    }

    func perform() async throws -> some IntentResult {
        if let uuid = UUID(uuidString: alarmID) {
            try? AlarmManager.shared.stop(id: uuid)
        }
        return .result()
    }
}

/// Per ADR-0003, snooze always replays the exact same alert via AlarmKit's
/// own re-ring mechanics rather than any app-level reschedule. The alert's
/// secondary button is configured with `secondaryButtonBehavior: .countdown`
/// at schedule time (see AlarmKitScheduler.schedule), which is what's
/// documented to actually re-arm the ring; calling `countdown(id:)` here too
/// is belt-and-braces in case that transition isn't fully automatic — see
/// the unresolved question flagged in
/// .scratch/wake-mate/research/alarmkit-api.md §5, to be confirmed on-device.
struct SnoozeAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Snooze"
    static var openAppWhenRun = false

    @Parameter(title: "alarmID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        alarmID = ""
    }

    func perform() async throws -> some IntentResult {
        if let uuid = UUID(uuidString: alarmID) {
            try? AlarmManager.shared.countdown(id: uuid)
        }
        return .result()
    }
}
