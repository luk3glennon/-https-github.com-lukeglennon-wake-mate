import Foundation
import Supabase

/// Thin seam over Supabase's auth client so view models can be unit tested
/// without hitting a network — see WakeMateTests/SignUpViewModelTests.swift.
protocol AuthServicing: Sendable {
    func signUp(email: String, password: String, tosAcceptedAt: Date) async throws
    func signOut() async throws
    var session: Session? { get async }
    /// Emits the current session immediately, then again on every auth
    /// state change (sign in, sign out, token refresh).
    func observeAuthState() -> AsyncStream<Session?>
}

final class SupabaseAuthService: AuthServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func signUp(email: String, password: String, tosAcceptedAt: Date) async throws {
        // tos_accepted_at rides in signup metadata; the `handle_new_user`
        // trigger (see supabase/migrations) reads it when creating the
        // profiles row. The client only calls this after the ToS toggle is
        // on (see SignUpViewModel.canSubmit) — the timestamp records when
        // that happened, not when this network call happens to complete.
        _ = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["tos_accepted_at": .string(ISO8601DateFormatter().string(from: tosAcceptedAt))]
        )
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    var session: Session? {
        get async { try? await client.auth.session }
    }

    func observeAuthState() -> AsyncStream<Session?> {
        AsyncStream { continuation in
            let task = Task {
                for await (_, session) in client.auth.authStateChanges {
                    continuation.yield(session)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
