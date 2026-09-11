import SwiftUI
import Supabase

/// Home stub — ticket 01 only requires landing here after signup with a
/// real account behind it. Real home-screen content (alarms, queue) is
/// later tickets.
struct HomeView: View {
    let session: Session
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            Text("You're all set")
                .font(.title2.bold())
            Text(session.user.email ?? "")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Sign Out", role: .destructive, action: onSignOut)
                .padding(.top, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
