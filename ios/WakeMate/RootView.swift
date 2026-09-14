import SwiftUI
import Supabase

struct RootView: View {
    @StateObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    private let libraryOverridePlayback: LibraryOverridePlaybackCoordinator

    init(
        authService: AuthServicing,
        friendService: FriendServicing,
        alarmService: AlarmServicing,
        alarmSyncCoordinator: AlarmSyncCoordinating,
        alarmCallService: AlarmCallServicing,
        audioRecorder: AudioRecording,
        consentService: ConsentServicing,
        libraryOverridePlayback: LibraryOverridePlaybackCoordinator
    ) {
        _appState = StateObject(
            wrappedValue: AppState(
                authService: authService,
                friendService: friendService,
                alarmService: alarmService,
                alarmSyncCoordinator: alarmSyncCoordinator,
                alarmCallService: alarmCallService,
                audioRecorder: audioRecorder,
                consentService: consentService
            )
        )
        self.libraryOverridePlayback = libraryOverridePlayback
    }

    var body: some View {
        Group {
            switch appState.flow {
            case .authGate:
                AuthGateView(
                    authService: appState.authService,
                    onSignUpAttempt: appState.markUpcomingSessionAsFreshSignUp,
                    onSignInAttempt: appState.markUpcomingSessionAsReturningUser
                )
            case .friendOnboarding:
                FriendOnboardingView(friendService: appState.friendService, onFinish: appState.finishFriendOnboarding)
            case .home(let session):
                HomeView(
                    session: session,
                    friendService: appState.friendService,
                    alarmService: appState.alarmService,
                    alarmSyncCoordinator: appState.alarmSyncCoordinator,
                    alarmCallService: appState.alarmCallService,
                    audioRecorder: appState.audioRecorder,
                    consentService: appState.consentService,
                    onSignOut: appState.signOut
                )
            }
        }
        .task { await appState.start() }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await libraryOverridePlayback.playIfNeeded() }
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    enum Flow {
        case authGate
        case friendOnboarding
        case home(Session)
    }

    @Published private(set) var flow: Flow = .authGate
    let authService: AuthServicing
    let friendService: FriendServicing
    let alarmService: AlarmServicing
    let alarmSyncCoordinator: AlarmSyncCoordinating
    let alarmCallService: AlarmCallServicing
    let audioRecorder: AudioRecording
    let consentService: ConsentServicing

    private var session: Session?
    // Set before sign-up/sign-in even starts (not after), so it can never
    // race observeAuthState() emitting the new session first — see
    // SignUpView.onSignUpAttempt.
    private var needsFriendOnboarding = false

    init(
        authService: AuthServicing,
        friendService: FriendServicing,
        alarmService: AlarmServicing,
        alarmSyncCoordinator: AlarmSyncCoordinating,
        alarmCallService: AlarmCallServicing,
        audioRecorder: AudioRecording,
        consentService: ConsentServicing
    ) {
        self.authService = authService
        self.friendService = friendService
        self.alarmService = alarmService
        self.alarmSyncCoordinator = alarmSyncCoordinator
        self.alarmCallService = alarmCallService
        self.audioRecorder = audioRecorder
        self.consentService = consentService
    }

    func start() async {
        for await newSession in authService.observeAuthState() {
            session = newSession
            recomputeFlow()
        }
    }

    func markUpcomingSessionAsFreshSignUp() {
        needsFriendOnboarding = true
    }

    func markUpcomingSessionAsReturningUser() {
        needsFriendOnboarding = false
    }

    func finishFriendOnboarding() {
        needsFriendOnboarding = false
        recomputeFlow()
    }

    func signOut() {
        Task { try? await authService.signOut() }
    }

    private func recomputeFlow() {
        guard let session else {
            flow = .authGate
            return
        }
        flow = needsFriendOnboarding ? .friendOnboarding : .home(session)
    }
}
