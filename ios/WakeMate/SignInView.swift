import SwiftUI

struct SignInView: View {
    @StateObject private var viewModel: SignInViewModel
    /// Called synchronously the moment sign-in is attempted, before the
    /// network call — see SignUpView's onSignUpAttempt for why.
    let onSignInAttempt: () -> Void

    init(authService: AuthServicing, onSignInAttempt: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: SignInViewModel(authService: authService))
        self.onSignInAttempt = onSignInAttempt
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Welcome back")
                .font(.title.bold())

            Spacer()

            VStack(spacing: 12) {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)

                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
            }
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal, 32)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
            }

            Button {
                onSignInAttempt()
                Task { await viewModel.submit() }
            } label: {
                Group {
                    if viewModel.isSubmitting {
                        ProgressView()
                    } else {
                        Text("Sign In")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSubmit)
            .padding(.horizontal, 60)
            .padding(.bottom, 40)
        }
    }
}
