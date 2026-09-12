import XCTest
import Supabase
@testable import WakeMate

@MainActor
final class SignInViewModelTests: XCTestCase {
    func test_canSubmit_isFalse_untilBothFieldsFilled() {
        let viewModel = SignInViewModel(authService: MockAuthService())

        XCTAssertFalse(viewModel.canSubmit)
        viewModel.email = "person@example.com"
        XCTAssertFalse(viewModel.canSubmit)
        viewModel.password = "supersecret"
        XCTAssertTrue(viewModel.canSubmit)
    }

    func test_submit_callsAuthServiceSignIn_whenValid() async {
        let mock = MockAuthService()
        let viewModel = SignInViewModel(authService: mock)
        viewModel.email = "person@example.com"
        viewModel.password = "supersecret"

        let result = await viewModel.submit()

        XCTAssertTrue(result)
        XCTAssertEqual(mock.signInCallCount, 1)
        XCTAssertEqual(mock.lastEmail, "person@example.com")
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_submit_doesNothing_whenInvalid() async {
        let mock = MockAuthService()
        let viewModel = SignInViewModel(authService: mock)
        viewModel.email = "person@example.com"
        // password left blank

        let result = await viewModel.submit()

        XCTAssertFalse(result)
        XCTAssertEqual(mock.signInCallCount, 0)
    }

    func test_submit_surfacesReadableError_onWrongCredentials() async {
        let mock = MockAuthService()
        mock.errorToThrow = TestError.invalidCredentials
        let viewModel = SignInViewModel(authService: mock)
        viewModel.email = "person@example.com"
        viewModel.password = "wrongpassword"

        let result = await viewModel.submit()

        XCTAssertFalse(result)
        XCTAssertEqual(mock.signInCallCount, 1)
        XCTAssertNotNil(viewModel.errorMessage)
    }
}

private enum TestError: Error, LocalizedError {
    case invalidCredentials
    var errorDescription: String? { "Invalid email or password." }
}

private final class MockAuthService: AuthServicing, @unchecked Sendable {
    private(set) var signInCallCount = 0
    private(set) var lastEmail: String?
    var errorToThrow: Error?

    func signUp(email: String, password: String, tosAcceptedAt: Date) async throws {}

    func signIn(email: String, password: String) async throws {
        signInCallCount += 1
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
