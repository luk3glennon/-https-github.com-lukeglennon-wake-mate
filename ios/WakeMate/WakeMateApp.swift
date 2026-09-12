import SwiftUI
import Supabase
import Sentry
import TelemetryDeck

@main
struct WakeMateApp: App {
    private let authService: AuthServicing
    private let friendService: FriendServicing

    init() {
        SentrySDK.start { options in
            options.dsn = AppConfig.sentryDSN
            options.tracesSampleRate = 1.0
        }
        // Smoke-test event so the Sentry project shows real traffic as
        // soon as this is wired up, without waiting for an actual crash.
        SentrySDK.capture(message: "WakeMate launched")

        TelemetryDeck.initialize(config: TelemetryDeck.Config(appID: AppConfig.telemetryDeckAppID))
        TelemetryDeck.signal("appLaunched")

        let client = SupabaseClient(supabaseURL: AppConfig.supabaseURL, supabaseKey: AppConfig.supabaseAnonKey)
        authService = SupabaseAuthService(client: client)
        friendService = SupabaseFriendService(client: client)
    }

    var body: some Scene {
        WindowGroup {
            RootView(authService: authService, friendService: friendService)
        }
    }
}
