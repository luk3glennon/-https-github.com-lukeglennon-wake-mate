import Foundation
import Supabase

struct FriendProfile: Decodable, Sendable, Equatable {
    let userID: UUID
    let handle: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case handle
    }
}

struct IncomingFriendRequest: Decodable, Sendable, Equatable, Identifiable {
    let id: UUID
    let requesterHandle: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "request_id"
        case requesterHandle = "requester_handle"
        case createdAt = "created_at"
    }
}

/// Thin seam over the friend-connection RPCs/tables — see AuthServicing for
/// why this exists (view-model unit testing without a network).
protocol FriendServicing: Sendable {
    /// Exact-handle-only lookup; nil if no other user has that handle.
    func searchProfile(byHandle handle: String) async throws -> FriendProfile?
    func myInviteCode() async throws -> String
    /// Read-only: never creates a connection. See FriendService's header.
    func resolveInviteCode(_ code: String) async throws -> FriendProfile?
    /// Sends a pending request as the current user (the "explicit accept
    /// step" search shares with invite links — see ticket 03).
    func sendFriendRequest(toUserID userID: UUID) async throws
    /// The only write path for the invite-link flow; creates the
    /// connection already accepted.
    func acceptInvite(code: String) async throws
    func pendingIncomingRequests() async throws -> [IncomingFriendRequest]
    func respond(toRequestID requestID: UUID, accept: Bool) async throws
}

final class SupabaseFriendService: FriendServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func searchProfile(byHandle handle: String) async throws -> FriendProfile? {
        let results: [FriendProfile] = try await client
            .rpc("search_profile_by_handle", params: ["p_handle": handle])
            .execute()
            .value
        return results.first
    }

    func myInviteCode() async throws -> String {
        struct Row: Decodable { let invite_code: String }
        let row: Row = try await client
            .from("profiles")
            .select("invite_code")
            .single()
            .execute()
            .value
        return row.invite_code
    }

    func resolveInviteCode(_ code: String) async throws -> FriendProfile? {
        let results: [FriendProfile] = try await client
            .rpc("resolve_invite_code", params: ["p_code": code])
            .execute()
            .value
        return results.first
    }

    func sendFriendRequest(toUserID userID: UUID) async throws {
        let requesterID = try await client.auth.session.user.id
        try await client
            .from("friend_connections")
            .insert(FriendRequestInsert(requesterID: requesterID, addresseeID: userID))
            .execute()
    }

    func acceptInvite(code: String) async throws {
        try await client
            .rpc("accept_invite", params: ["p_code": code])
            .execute()
    }

    func pendingIncomingRequests() async throws -> [IncomingFriendRequest] {
        try await client
            .rpc("pending_incoming_requests")
            .execute()
            .value
    }

    func respond(toRequestID requestID: UUID, accept: Bool) async throws {
        try await client
            .from("friend_connections")
            .update(FriendRequestStatusUpdate(
                status: accept ? "accepted" : "declined",
                respondedAt: ISO8601DateFormatter().string(from: Date())
            ))
            .eq("id", value: requestID)
            .execute()
    }
}

private struct FriendRequestInsert: Encodable {
    let requesterID: UUID
    let addresseeID: UUID

    enum CodingKeys: String, CodingKey {
        case requesterID = "requester_id"
        case addresseeID = "addressee_id"
    }
}

private struct FriendRequestStatusUpdate: Encodable {
    let status: String
    let respondedAt: String

    enum CodingKeys: String, CodingKey {
        case status
        case respondedAt = "responded_at"
    }
}
