import Foundation
import Supabase

/// Thin seam over the `alarms` table — see AuthServicing for why this
/// exists (view-model unit testing without a network).
protocol AlarmServicing: Sendable {
    func listAlarms() async throws -> [Alarm]
    func createAlarm(
        label: String?,
        wakeTime: WakeTime,
        repeatDays: [Int],
        mode: AlarmMode,
        libraryOverrideAlarmCallID: UUID?
    ) async throws -> Alarm
    func updateAlarm(
        id: UUID,
        label: String?,
        wakeTime: WakeTime,
        repeatDays: [Int],
        mode: AlarmMode,
        libraryOverrideAlarmCallID: UUID?
    ) async throws -> Alarm
    func deleteAlarm(id: UUID) async throws
}

final class SupabaseAlarmService: AlarmServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func listAlarms() async throws -> [Alarm] {
        try await client
            .from("alarms")
            .select()
            .order("wake_time")
            .execute()
            .value
    }

    func createAlarm(
        label: String?,
        wakeTime: WakeTime,
        repeatDays: [Int],
        mode: AlarmMode,
        libraryOverrideAlarmCallID: UUID?
    ) async throws -> Alarm {
        let ownerID = try await client.auth.session.user.id
        return try await client
            .from("alarms")
            .insert(
                AlarmInsert(
                    ownerID: ownerID,
                    label: label,
                    wakeTime: wakeTime,
                    repeatDays: repeatDays.sorted(),
                    mode: mode,
                    libraryOverrideAlarmCallID: libraryOverrideAlarmCallID
                ),
                returning: .representation
            )
            .single()
            .execute()
            .value
    }

    func updateAlarm(
        id: UUID,
        label: String?,
        wakeTime: WakeTime,
        repeatDays: [Int],
        mode: AlarmMode,
        libraryOverrideAlarmCallID: UUID?
    ) async throws -> Alarm {
        try await client
            .from("alarms")
            .update(
                AlarmUpdate(
                    label: label,
                    wakeTime: wakeTime,
                    repeatDays: repeatDays.sorted(),
                    mode: mode,
                    libraryOverrideAlarmCallID: libraryOverrideAlarmCallID,
                    updatedAt: ISO8601DateFormatter().string(from: Date())
                ),
                returning: .representation
            )
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func deleteAlarm(id: UUID) async throws {
        try await client
            .from("alarms")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

private struct AlarmInsert: Encodable {
    let ownerID: UUID
    let label: String?
    let wakeTime: WakeTime
    let repeatDays: [Int]
    let mode: AlarmMode
    let libraryOverrideAlarmCallID: UUID?

    enum CodingKeys: String, CodingKey {
        case ownerID = "owner_id"
        case label
        case wakeTime = "wake_time"
        case repeatDays = "repeat_days"
        case mode
        case libraryOverrideAlarmCallID = "library_override_alarm_call_id"
    }
}

private struct AlarmUpdate: Encodable {
    let label: String?
    let wakeTime: WakeTime
    let repeatDays: [Int]
    let mode: AlarmMode
    let libraryOverrideAlarmCallID: UUID?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case label
        case wakeTime = "wake_time"
        case repeatDays = "repeat_days"
        case mode
        case libraryOverrideAlarmCallID = "library_override_alarm_call_id"
        case updatedAt = "updated_at"
    }
}
