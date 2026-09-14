import Foundation

/// The hour/minute a user wants to wake up at. Postgres stores this as its
/// native `time` column type, which supabase-swift round-trips as a plain
/// "HH:mm:ss" string — this wraps that string so the rest of the app never
/// parses it by hand.
struct WakeTime: Sendable, Equatable, Comparable {
    var hour: Int
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    static func < (lhs: WakeTime, rhs: WakeTime) -> Bool {
        (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
    }
}

extension WakeTime: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        let parts = raw.split(separator: ":")
        guard parts.count >= 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid wake_time value '\(raw)'"
            )
        }
        self.hour = hour
        self.minute = minute
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(format: "%02d:%02d:00", hour, minute))
    }
}

enum AlarmMode: String, Codable, Sendable, Hashable {
    case autoPlay = "auto_play"
    case libraryOverride = "library_override"
}

/// Weekday numbering matches `Calendar.Component.weekday`/`DateComponents.weekday`
/// (1 = Sunday ... 7 = Saturday) so the DB column, this model, and
/// `Alarm.Schedule.Relative.Recurrence.weekly` (AlarmKit) all agree without a
/// translation table. An empty set means "does not repeat" (fires once).
struct Alarm: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var ownerID: UUID
    var label: String?
    var wakeTime: WakeTime
    var repeatDays: [Int]
    var mode: AlarmMode
    var libraryOverrideAlarmCallID: UUID?
    var snoozeEnabled: Bool
    var snoozeDurationMinutes: Int
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case label
        case wakeTime = "wake_time"
        case repeatDays = "repeat_days"
        case mode
        case libraryOverrideAlarmCallID = "library_override_alarm_call_id"
        case snoozeEnabled = "snooze_enabled"
        case snoozeDurationMinutes = "snooze_duration_minutes"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
