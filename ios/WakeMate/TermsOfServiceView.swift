import SwiftUI

/// Placeholder copy only — drafting the real Terms of Service/Privacy
/// Policy is a legal deliverable, not an engineering one (see map.md's
/// out-of-scope note). This view exists so the signup flow has something
/// real to link to.
struct TermsOfServiceView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                Text(Self.placeholderText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private static let placeholderText = """
    Placeholder Terms of Service.

    Replace this with the actual Wake Mate Terms of Service and Privacy \
    Policy text once drafted.
    """
}
