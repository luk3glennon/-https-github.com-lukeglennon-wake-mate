import Foundation
import Supabase

/// Thin seam over `register_device_token` (ticket 06) — see AuthServicing
/// for why this pattern exists (view-model unit testing without a network).
protocol DeviceTokenServicing: Sendable {
    /// Registers (or reassigns, if this physical device previously belonged
    /// to a different account) the current user as this APNs token's owner.
    func register(apnsToken: String) async throws
}

final class SupabaseDeviceTokenService: DeviceTokenServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func register(apnsToken: String) async throws {
        try await client
            .rpc("register_device_token", params: ["p_apns_token": apnsToken])
            .execute()
    }
}
