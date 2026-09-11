import XCTest
import Supabase
@testable import WakeMate

@MainActor
final class SignUpViewModelTests: XCTestCase {
    func test_canSubmit_isFalse_untilTermsAccepted() {
        let viewModel = SignUpViewModel(authService: MockAuthService())
        viewModel.email = "person@example.com"
        viewModel.password = "supersecret"

        XCTAssertFalse(viewModel.canSubmit)
        viewModel.hasAcceptedTerms = true
        XCTAssertTrue(viewModel.canSubmit)
    }

    func test_canSubmit_isFalse_forPasswordShorterThanMinimum() {
        let viewModel = SignUpViewModel(authService: MockAuthService())
        viewModel.email = "person@example.com"
        viewModel.hasAcceptedTerms = true
        viewModel.password = String(repeating: "a", count: SignUpViewModel.minimumPasswordLength - 1)

        XCTAssertFalse(viewModel.canSubmit)
    }

    func test_canSubmit_isFalse_forImplausibleEmail() {
        let viewModel = SignUpViewModel(authService: MockAuthService())
        viewModel.password = "supersecret"
        viewModel.hasAcceptedTerms = true

        for badEmail in ["not-an-email", "missing-domain@", "@missing-local.com", ""] {
            viewModel.email = badEmail
            XCTAssertFalse(viewModel.canSubmit, "expected '\(badEmail)' to be rejected")
        }
    }

    func test_submit_callsAuthServiceSignUp_whenValid() async {
        let mock = MockAuthService()
        let viewModel = SignUpViewModel(authService: mock)
        viewModel.email = "person@example.com"
        viewModel.password = "supersecret"
        viewModel.hasAcceptedTerms = true

        await viewModel.submit()

        XCTAssertEqual(mock.signUpCallCount, 1)
        XCTAssertEqual(mock.lastEmail, "person@example.com")
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_submit_doesNothing_whenInvalid() async {
        let mock = MockAuthService()
        let viewModel = SignUpViewModel(authService: mock)
        // hasAcceptedTerms defaults to false, so this is invalid input.
        viewModel.email = "person@example.com"
        viewModel.password = "supersecret"

        await viewModel.submit()

        XCTAssertEqual(mock.signUpCallCount, 0)
    }

    func test_submit_surfacesError_whenAuthServiceThrows() async {
        let mock = MockAuthService()
        mock.errorToThrow = TestError.boom
        let viewModel = SignUpViewModel(authService: mock)
        viewModel.email = "person@example.com"
        viewModel.password = "supersecret"
        viewModel.hasAcceptedTerms = true

        await viewModel.submit()

        XCTAssertEqual(mock.signUpCallCount, 1)
        XCTAssertNotNil(viewModel.errorMessage)
    }
}

private enum TestError: Error, LocalizedError {
    case boom
    var errorDescription: String? { "boom" }
}

private final class MockAuthService: AuthServicing, @unchecked Sendable {
    private(set) var signUpCallCount = 0
    private(set) var lastEmail: String?
    var errorToThrow: Error?

    func signUp(email: String, password: String, tosAcceptedAt: Date) async throws {
        signUpCallCount += 1
        lastEmail = email
        if let errorToThrow {
            throw errorToThrow
        }
    }

    func signOut() async throws {}

    var session: Session? {
        get async { nil }
    }

    func observeAuthState() -> AsyncStream<Session?> {
        AsyncStream { $0.finish() }
    }
}
