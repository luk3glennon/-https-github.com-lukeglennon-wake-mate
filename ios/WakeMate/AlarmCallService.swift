import Foundation
import Supabase

/// Thin seam over `alarm_calls`/`library_entries` and the "alarm-calls"
/// Storage bucket — see AuthServicing for why this pattern exists
/// (view-model unit testing without a network).
protocol AlarmCallServicing: Sendable {
    /// Uploads the recording at `fileURL` via a presigned Storage upload
    /// URL (ticket 11: this initial upload is ticket 05's job, distinct
    /// from ticket 06's server-side per-Share copy), then inserts the
    /// `alarm_calls` row (with the user's optional `title`, nil if left
    /// blank) and a matching `library_entries` row (`source: created`).
    func upload(fileURL: URL, durationSeconds: Double, title: String?) async throws -> AlarmCall
    /// Every clip in the current user's Library, newest first.
    func listLibrary() async throws -> [LibraryClip]
    /// A single Alarm Call by id, used to resolve a `library_override`
    /// Alarm's clip for playback. RLS currently only permits the owner to
    /// read their own `alarm_calls` row (ticket 06/07 will need to widen
    /// this once a clip can be Shared to someone else).
    func fetchAlarmCall(id: UUID) async throws -> AlarmCall
    /// Downloads a clip's raw audio data so it can be played locally.
    func downloadClipData(storagePath: String) async throws -> Data
    /// Permanently deletes the clip: its `alarm_calls` row (which cascades
    /// to the matching `library_entries` row) and its Storage object. A DB
    /// trigger resets any Alarm using it as a library_override sound back
    /// to auto_play, so this never leaves an Alarm silently pointing at a
    /// clip that no longer exists.
    func deleteClip(id: UUID, storagePath: String) async throws
}

final class SupabaseAlarmCallService: AlarmCallServicing {
    private static let bucket = "alarm-calls"

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func upload(fileURL: URL, durationSeconds: Double, title: String?) async throws -> AlarmCall {
        let ownerID = try await client.auth.session.user.id
        let alarmCallID = UUID()
        // Swift's UUID string interpolation is uppercase, but Postgres's
        // auth.uid()::text (compared against this path's folder segment by
        // the storage.objects RLS policy) is lowercase - an uppercase path
        // here makes that comparison fail every time. Lowercase to match.
        let storagePath = "\(ownerID.uuidString.lowercased())/\(alarmCallID.uuidString.lowercased()).m4a"
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
                AlarmCallInsert(
                    id: alarmCallID,
                    ownerID: ownerID,
                    storagePath: storagePath,
                    durationSeconds: durationSeconds,
                    title: title
                ),
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
            .select("source, added_at, alarm_calls(id, storage_path, duration_seconds, title)")
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

    func deleteClip(id: UUID, storagePath: String) async throws {
        // DB row first: if this fails, the clip and its Storage object are
        // still in a consistent state. If the Storage removal below fails
        // after this succeeds, the row (and any dangling reference to it)
        // is already gone - worst case is an orphaned Storage object.
        try await client
            .from("alarm_calls")
            .delete()
            .eq("id", value: id)
            .execute()
        _ = try await client.storage.from(Self.bucket).remove(paths: [storagePath])
    }
}

private struct AlarmCallInsert: Encodable {
    let id: UUID
    let ownerID: UUID
    let storagePath: String
    let durationSeconds: Double
    let title: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case storagePath = "storage_path"
        case durationSeconds = "duration_seconds"
        case title
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
        let title: String?

        enum CodingKeys: String, CodingKey {
            case id
            case storagePath = "storage_path"
            case durationSeconds = "duration_seconds"
            case title
        }
    }

    var asLibraryClip: LibraryClip {
        LibraryClip(
            id: alarmCalls.id,
            storagePath: alarmCalls.storagePath,
            durationSeconds: alarmCalls.durationSeconds,
            source: source,
            addedAt: addedAt,
            title: alarmCalls.title
        )
    }
}
