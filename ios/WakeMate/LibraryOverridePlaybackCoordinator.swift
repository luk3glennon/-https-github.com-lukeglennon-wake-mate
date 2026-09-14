import Foundation
import AVFoundation

/// Resolves and plays a `library_override` Alarm's chosen clip while it's
/// ringing/snoozed. The full teaser + tap-through + Queue/auto_play
/// playback pipeline is ticket 07's job (blocked by ticket 06's Share/Queue
/// tables); this reuses the activity-tracking seam ticket 04 already built
/// (`AlarmActivityTracking`) to cover this ticket's own scoped requirement
/// ("it plays correctly when that Alarm fires") without inventing new,
/// device-only-verifiable AlarmKit tap-detection mechanics ahead of time.
///
/// Driven by the app coming to the foreground (RootView's scenePhase
/// observer) — this is the only point our process is guaranteed to be
/// running during a ring, since AlarmKit's own alert UI (ticket 04) needs
/// no app process at all.
@MainActor
final class LibraryOverridePlaybackCoordinator: NSObject, ObservableObject {
    private let alarmService: AlarmServicing
    private let alarmCallService: AlarmCallServicing
    private let activityTracking: AlarmActivityTracking
    private var player: AVAudioPlayer?

    init(alarmService: AlarmServicing, alarmCallService: AlarmCallServicing, activityTracking: AlarmActivityTracking) {
        self.alarmService = alarmService
        self.alarmCallService = alarmCallService
        self.activityTracking = activityTracking
    }

    func playIfNeeded() async {
        await activityTracking.refreshActiveAlarms()
        guard let alarms = try? await alarmService.listAlarms() else { return }

        guard
            let ringingOverride = alarms.first(where: { alarm in
                alarm.mode == .libraryOverride
                    && alarm.libraryOverrideAlarmCallID != nil
                    && activityTracking.isActive(alarmID: alarm.id)
            }),
            let clipID = ringingOverride.libraryOverrideAlarmCallID
        else {
            return
        }

        await play(alarmCallID: clipID)
    }

    private func play(alarmCallID: UUID) async {
        guard
            let alarmCall = try? await alarmCallService.fetchAlarmCall(id: alarmCallID),
            let data = try? await alarmCallService.downloadClipData(storagePath: alarmCall.storagePath)
        else {
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        do {
            try data.write(to: tempURL)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            let newPlayer = try AVAudioPlayer(contentsOf: tempURL)
            newPlayer.prepareToPlay()
            newPlayer.play()
            player = newPlayer
        } catch {
            // Best-effort: if local playback fails, the alarm's already
            // ringing via AlarmKit's own bundled-tone alert (ticket 04) —
            // there's no silent-alarm risk here, only a missed override.
        }
    }
}
