import SwiftUI
import Supabase
import Sentry
import TelemetryDeck
import UserNotifications

@main
struct WakeMateApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let authService: AuthServicing
    private let friendService: FriendServicing
    private let alarmService: AlarmServicing
    private let alarmSyncCoordinator: AlarmSyncCoordinating
    private let alarmCallService: AlarmCallServicing
    private let shareService: ShareServicing
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
        shareService = SupabaseShareService(client: client)
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

        let deviceTokenService = SupabaseDeviceTokenService(client: client)
        appDelegate.deviceTokenService = deviceTokenService
        requestPushRegistration()
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                authService: authService,
                friendService: friendService,
                alarmService: alarmService,
                alarmSyncCoordinator: alarmSyncCoordinator,
                alarmCallService: alarmCallService,
                shareService: shareService,
                audioRecorder: audioRecorder,
                consentService: consentService,
                libraryOverridePlayback: libraryOverridePlayback
            )
        }
    }

    // Registration only completes a round trip to device_tokens (ticket 06)
    // once the Push Notifications capability/entitlement is in place (see
    // AppDelegate) — requesting it now regardless means that follow-up needs
    // no further app-code change, only the signing-side setup.
    private func requestPushRegistration() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            Task { @MainActor in
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}
