import SwiftUI

struct SignUpView: View {
    @StateObject private var viewModel: SignUpViewModel
    @State private var showingTerms = false

    init(authService: AuthServicing) {
        _viewModel = StateObject(wrappedValue: SignUpViewModel(authService: authService))
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
