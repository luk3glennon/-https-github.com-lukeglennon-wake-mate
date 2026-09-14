import Foundation
import Supabase

/// Thin seam over `alarm_calls`/`library_entries` and the "alarm-calls"
/// Storage bucket — see AuthServicing for why this pattern exists
/// (view-model unit testing without a network).
protocol AlarmCallServicing: Sendable {
    /// Uploads the recording at `fileURL` via a presigned Storage upload
    /// URL (ticket 11: this initial upload is ticket 05's job, distinct
    /// from ticket 06's server-side per-Share copy), then inserts the
    /// `alarm_calls` row and a matching `library_entries` row
    /// (`source: created`).
    func upload(fileURL: URL, durationSeconds: Double) async throws -> AlarmCall
    /// Every clip in the current user's Library, newest first.
    func listLibrary() async throws -> [LibraryClip]
    /// A single Alarm Call by id, used to resolve a `library_override`
    /// Alarm's clip for playback. RLS currently only permits the owner to
    /// read their own `alarm_calls` row (ticket 06/07 will need to widen
    /// this once a clip can be Shared to someone else).
    func fetchAlarmCall(id: UUID) async throws -> AlarmCall
    /// Downloads a clip's raw audio data so it can be played locally.
    func downloadClipData(storagePath: String) async throws -> Data
}

final class SupabaseAlarmCallService: AlarmCallServicing {
    private static let bucket = "alarm-calls"

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func upload(fileURL: URL, durationSeconds: Double) async throws -> AlarmCall {
        let ownerID = try await client.auth.session.user.id
        let alarmCallID = UUID()
        let storagePath = "\(ownerID)/\(alarmCallID).m4a"
        let fileData = try Data(contentsOf: fileURL)

        // Presigned upload per ticket 11 (the initial alarm_calls upload is
        // ticket 05's job, distinct from ticket 06's server-side per-Share
        // copy). Argument labels below confirmed against supabase-swift's
        // StorageFileApi source (createSignedUploadURL(path:options:) ->
        // SignedUploadURL{signedURL, path, token}; uploadToSignedURL(_:token:data:options:)).
        let signedUpload = try await client.storage.from(Self.bucket).createSignedUploadURL(path: storagePath)
        _ = try await client.storage.from(Self.bucket).uploadToSignedURL(
            signedUpload.path,
            token: signedUpload.token,
            data: fileData,
            options: FileOptions(contentType: "audio/mp4")
        )

        let alarmCall: AlarmCall = try await client
            .from("alarm_calls")
            .insert(
                AlarmCallInsert(id: alarmCallID, ownerID: ownerID, storagePath: storagePath, durationSeconds: durationSeconds),
                returning: .representation
            )
            .single()
            .execute()
            .value

        try await client
            .from("library_entries")
            .insert(LibraryEntryInsert(userID: ownerID, alarmCallID: alarmCall.id, source: .created))
            .execute()

        return alarmCall
    }

    func listLibrary() async throws -> [LibraryClip] {
        let rows: [LibraryEntryRow] = try await client
            .from("library_entries")
            .select("source, added_at, alarm_calls(id, storage_path, duration_seconds)")
            .order("added_at", ascending: false)
            .execute()
            .value
        return rows.compactMap(\.asLibraryClip)
    }

    func fetchAlarmCall(id: UUID) async throws -> AlarmCall {
        try await client
            .from("alarm_calls")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func downloadClipData(storagePath: String) async throws -> Data {
        try await client.storage.from(Self.bucket).download(path: storagePath)
    }
}

private struct AlarmCallInsert: Encodable {
    let id: UUID
    let ownerID: UUID
    let storagePath: String
    let durationSeconds: Double

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case storagePath = "storage_path"
        case durationSeconds = "duration_seconds"
    }
}

private struct LibraryEntryInsert: Encodable {
    let userID: UUID
    let alarmCallID: UUID
    let source: LibrarySource

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case alarmCallID = "alarm_call_id"
        case source
    }
}

private struct LibraryEntryRow: Decodable {
    let source: LibrarySource
    let addedAt: Date
    let alarmCalls: NestedAlarmCall

    enum CodingKeys: String, CodingKey {
        case source
        case addedAt = "added_at"
        case alarmCalls = "alarm_calls"
    }

    struct NestedAlarmCall: Decodable {
        let id: UUID
        let storagePath: String
        let durationSeconds: Double

        enum CodingKeys: String, CodingKey {
            case id
            case storagePath = "storage_path"
            case durationSeconds = "duration_seconds"
        }
    }

    var asLibraryClip: LibraryClip {
        LibraryClip(
            id: alarmCalls.id,
            storagePath: alarmCalls.storagePath,
            durationSeconds: alarmCalls.durationSeconds,
            source: source,
            addedAt: addedAt
        )
    }
}
