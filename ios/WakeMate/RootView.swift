import SwiftUI
import Supabase

struct RootView: View {
    @StateObject private var appState: AppState

    init(authService: AuthServicing) {
        _appState = StateObject(wrappedValue: AppState(authService: authService))
    }

    var body: some View {
        Group {
            if let session = appState.session {
                HomeView(session: session, onSignOut: appState.signOut)
            } else {
                SignUpView(authService: appState.authService)
            }
        }
        .task { await appState.start() }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var session: Session?
    let authService: AuthServicing

    init(authService: AuthServicing) {
        self.authService = authService
    }

    func start() async {
        // observeAuthState() emits the current session immediately (see
        // AuthServicing's doc comment), so a separate initial fetch would
        // just duplicate that first emission.
        for await newSession in authService.observeAuthState() {
            session = newSession
        }
    }

    func signOut() {
        Task { try? await authService.signOut() }
    }
}
