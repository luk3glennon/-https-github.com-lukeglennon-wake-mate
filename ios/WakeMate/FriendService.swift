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
    /// The current user's own handle (to give out for others to search) and
    /// invite code (to hand out directly), fetched together since both come
    /// off the same profile row.
    func myProfile() async throws -> (handle: String, inviteCode: String)
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

    func myProfile() async throws -> (handle: String, inviteCode: String) {
        struct Row: Decodable { let handle: String; let invite_code: String }
        let row: Row = try await client
            .from("profiles")
            .select("handle, invite_code")
            .single()
            .execute()
            .value
        return (row.handle, row.invite_code)
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
        do {
            try await client
                .from("friend_connections")
                .insert(FriendRequestInsert(requesterID: requesterID, addresseeID: userID))
                .execute()
        } catch {
            // The normalized-pair unique index (friend_connections_unique_pair,
            // see the migration) rejects a second request between the same two
            // people in either direction — that's correct, but surfacing its
            // raw Postgres text ("duplicate key value violates unique
            // constraint...") to the user is not. Found 2026-09-13 testing
            // handle search against two accounts already connected via invite
            // code.
            if error.localizedDescription.contains("friend_connections_unique_pair") {
                throw FriendServiceError.alreadyConnectedOrPending
            }
            throw error
        }
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

enum FriendServiceError: LocalizedError {
    case alreadyConnectedOrPending

    var errorDescription: String? {
        switch self {
        case .alreadyConnectedOrPending:
            return "You're already connected, or already have a pending request, with them."
        }
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
