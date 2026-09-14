import SwiftUI
import Supabase
import Sentry
import TelemetryDeck

@main
struct WakeMateApp: App {
    private let authService: AuthServicing
    private let friendService: FriendServicing
    private let alarmService: AlarmServicing
    private let alarmSyncCoordinator: AlarmSyncCoordinating
    private let alarmCallService: AlarmCallServicing
    private let audioRecorder: AudioRecording
    private let consentService: ConsentServicing
    private let libraryOverridePlayback: LibraryOverridePlaybackCoordinating

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
        alarmService = SupabaseAlarmService(client: client)
        alarmCallService = SupabaseAlarmCallService(client: client)
        let soundPreparer = LibraryOverrideSoundPreparer(alarmCallService: alarmCallService)
        let alarmKitScheduler = AlarmKitScheduler(soundPreparer: soundPreparer)
        alarmSyncCoordinator = AlarmSyncCoordinator(scheduler: alarmKitScheduler, activity: alarmKitScheduler)
        audioRecorder = AVFoundationAudioRecorder()
        consentService = SupabaseConsentService(client: client)
        libraryOverridePlayback = LibraryOverridePlaybackCoordinator(
            alarmService: alarmService,
            alarmCallService: alarmCallService,
            activityTracking: alarmKitScheduler
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                authService: authService,
                friendService: friendService,
                alarmService: alarmService,
                alarmSyncCoordinator: alarmSyncCoordinator,
                alarmCallService: alarmCallService,
                audioRecorder: audioRecorder,
                consentService: consentService,
                libraryOverridePlayback: libraryOverridePlayback
            )
        }
    }
}
