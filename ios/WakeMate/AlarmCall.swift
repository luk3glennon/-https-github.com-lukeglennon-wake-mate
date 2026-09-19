import Foundation

/// A user's own permanent, reusable recording (CONTEXT.md: "one recording
/// can be Shared to any number of friends independently"). Fixed encoding
/// profile per ticket 13 (AAC-HE mono 44.1kHz 32kbps, .m4a, <=30s), so no
/// per-row codec metadata is needed.
struct AlarmCall: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var ownerID: UUID
    var storagePath: String
    var durationSeconds: Double
    var createdAt: Date
    /// User-chosen name given at save time; nil if left blank, in which case
    /// callers fall back to a timestamp (see `LibraryClip.displayTitle`).
    var title: String? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case storagePath = "storage_path"
        case durationSeconds = "duration_seconds"
        case createdAt = "created_at"
        case title
    }
}

/// Matches `library_entries.source` — whether this clip was recorded by the
/// user themselves or received from a friend and saved (ticket 06/07).
enum LibrarySource: String, Codable, Sendable, Equatable {
    case created
    case received
}

/// A row in a user's unified Library (CONTEXT.md), joining `library_entries`
/// to the underlying `alarm_calls` row it points at.
struct LibraryClip: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var storagePath: String
    var durationSeconds: Double
    var source: LibrarySource
    var addedAt: Date
    var title: String? = nil
}

extension LibraryClip {
    /// The user's own title, if they gave one; otherwise a timestamp +
    /// duration fallback so the clip is still distinguishable in a picker.
    var displayTitle: String {
        if let title, !title.isEmpty {
            return title
        }
        let seconds = Int(durationSeconds.rounded())
        return "\(Self.dateFormatter.string(from: addedAt)) \u{00B7} \(seconds)s"
    }

    var sourceLabel: String {
        switch source {
        case .created: return "Recorded"
        case .received: return "Received"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}
