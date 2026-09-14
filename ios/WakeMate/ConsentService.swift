import Foundation
import Supabase

/// Thin seam over `consent_log`. Ticket 15's policy: in-app consent capture
/// alongside (not instead of) the OS permission prompt, logged here rather
/// than relying on OS permission state as evidence.
protocol ConsentServicing: Sendable {
    func logMicRecordingConsent() async throws
}

enum ConsentType: String {
    case micRecording = "mic_recording"
}

final class SupabaseConsentService: ConsentServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func logMicRecordingConsent() async throws {
        let userID = try await client.auth.session.user.id
        try await client
            .from("consent_log")
            .insert(
                ConsentLogInsert(
                    userID: userID,
                    consentType: ConsentType.micRecording.rawValue,
                    grantedAt: ISO8601DateFormatter().string(from: Date())
                )
            )
            .execute()
    }
}

private struct ConsentLogInsert: Encodable {
    let userID: UUID
    let consentType: String
    let grantedAt: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case consentType = "consent_type"
        case grantedAt = "granted_at"
    }
}
