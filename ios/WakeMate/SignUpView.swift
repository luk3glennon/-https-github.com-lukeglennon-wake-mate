import SwiftUI

struct SignUpView: View {
    @StateObject private var viewModel: SignUpViewModel
    @State private var showingTerms = false
    /// Called synchronously the moment sign-up is attempted, before the
    /// network call — not on success. This lets AppState mark "the next
    /// session that appears came from a fresh sign-up" without racing
    /// AuthServicing's auth-state stream, which can emit the new session
    /// before this view's own `submit()` call returns.
    let onSignUpAttempt: () -> Void

    init(authService: AuthServicing, onSignUpAttempt: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: SignUpViewModel(authService: authService))
        self.onSignUpAttempt = onSignUpAttempt
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Wake Mate")
                .font(.title.bold())
            Text("Wake up to a friend's voice.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(spacing: 12) {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)

                SecureField("Password", text: $viewModel.password)
                    .textContentType(.newPassword)
            }
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 4) {
                Toggle("I agree to the Terms of Service", isOn: $viewModel.hasAcceptedTerms)
                    .font(.footnote)
                Button("Read the Terms of Service") { showingTerms = true }
                    .font(.footnote)
            }
            .padding(.horizontal, 32)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
            }

            Button {
                onSignUpAttempt()
                Task { await viewModel.submit() }
            } label: {
                Group {
                    if viewModel.isSubmitting {
                        ProgressView()
                    } else {
                        Text("Sign Up")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSubmit)
            .padding(.horizontal, 60)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showingTerms) {
            TermsOfServiceView()
        }
    }
}
