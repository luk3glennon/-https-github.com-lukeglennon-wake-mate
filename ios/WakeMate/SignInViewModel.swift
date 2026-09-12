import Foundation

@MainActor
final class SignInViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?

    private let authService: AuthServicing

    init(authService: AuthServicing) {
        self.authService = authService
    }

    var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && !isSubmitting
    }

    /// Returns true on success so the caller can advance past the auth
    /// gate; false (with errorMessage set) leaves the user on this screen.
    @discardableResult
    func submit() async -> Bool {
        guard canSubmit else { return false }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await authService.signIn(email: email, password: password)
            return true
        } catch {
            // Supabase Auth returns the same generic invalid-credentials
            // error for "no such user" and "wrong password" alike, which is
            // already the readable, non-enumerating message this screen
            // needs — no translation layer required.
            errorMessage = error.localizedDescription
            return false
        }
    }
}
