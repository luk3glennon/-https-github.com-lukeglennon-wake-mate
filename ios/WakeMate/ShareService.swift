import Foundation
import Supabase

/// Thin seam over the createShare/getShareDownloadUrl Edge Functions
/// (ticket 06/11) — see AuthServicing for why this pattern exists (view-model
/// unit testing without a network). Both operations need to act across the
/// sender/recipient boundary, which is why they're server-side Edge
/// Functions rather than plain table calls the client could make itself.
protocol ShareServicing: Sendable {
    /// Sends `alarmCallID` (one of the caller's own Library clips) to
    /// `recipientID`. Fails server-side if they aren't an accepted friend.
    @discardableResult
    func createShare(alarmCallID: UUID, recipientID: UUID) async throws -> UUID
    /// A short-lived download URL for a Share's audio, valid only for its
    /// actual recipient.
    func downloadURL(shareID: UUID) async throws -> URL
}

final class SupabaseShareService: ShareServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    @discardableResult
    func createShare(alarmCallID: UUID, recipientID: UUID) async throws -> UUID {
        struct Response: Decodable { let shareId: UUID }
        let response: Response = try await client.functions.invoke(
            "create-share",
            options: FunctionInvokeOptions(
                body: CreateShareRequest(alarmCallId: alarmCallID, recipientId: recipientID)
            )
        )
        return response.shareId
    }

    func downloadURL(shareID: UUID) async throws -> URL {
        struct Response: Decodable { let url: URL }
        let response: Response = try await client.functions.invoke(
            "get-share-download-url",
            options: FunctionInvokeOptions(body: GetShareDownloadUrlRequest(shareId: shareID))
        )
        return response.url
    }
}

private struct CreateShareRequest: Encodable {
    let alarmCallId: UUID
    let recipientId: UUID
}

private struct GetShareDownloadUrlRequest: Encodable {
    let shareId: UUID
}
