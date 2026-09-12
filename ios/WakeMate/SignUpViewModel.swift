import Foundation

@MainActor
final class SignUpViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var hasAcceptedTerms = false {
        didSet {
            // Stamp the moment the toggle actually flips on, not whenever
            // submit() later runs, so this is a true acceptance record.
            if hasAcceptedTerms && !oldValue {
                tosAcceptedAt = Date()
            } else if !hasAcceptedTerms {
                tosAcceptedAt = nil
            }
        }
    }
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?

    private(set) var tosAcceptedAt: Date?

    static let minimumPasswordLength = 6

    private let authService: AuthServicing

    init(authService: AuthServicing) {
        self.authService = authService
    }

    var canSubmit: Bool {
        hasAcceptedTerms
            && tosAcceptedAt != nil
            && password.count >= Self.minimumPasswordLength
            && Self.isPlausibleEmail(email)
            && !isSubmitting
    }

    /// Returns true on success so the caller can advance past the auth
    /// gate; false (with errorMessage set) leaves the user on this screen.
    @discardableResult
    func submit() async -> Bool {
        guard canSubmit, let tosAcceptedAt else { return false }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await authService.signUp(email: email, password: password, tosAcceptedAt: tosAcceptedAt)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Deliberately loose — this only blocks obviously-empty/malformed
    /// input from reaching the network call. Supabase Auth is the real
    /// validator of what counts as a usable email address.
    static func isPlausibleEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".")
    }
}
