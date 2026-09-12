import SwiftUI

/// Everything shown while there's no session: sign-up and sign-in are
/// peers here, reachable from one another, per ticket 03.
struct AuthGateView: View {
    private enum Mode {
        case signUp
        case signIn
    }

    @State private var mode: Mode = .signUp
    let authService: AuthServicing
    let onSignUpAttempt: () -> Void
    let onSignInAttempt: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            switch mode {
            case .signUp:
                SignUpView(authService: authService, onSignUpAttempt: onSignUpAttempt)
            case .signIn:
                SignInView(authService: authService, onSignInAttempt: onSignInAttempt)
            }

            Button {
                mode = mode == .signUp ? .signIn : .signUp
            } label: {
                switch mode {
                case .signUp:
                    Text("Already have an account? Sign In")
                case .signIn:
                    Text("New here? Sign Up")
                }
            }
            .font(.footnote)
            .padding(.bottom, 24)
        }
    }
}
