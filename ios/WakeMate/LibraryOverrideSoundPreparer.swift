import Foundation

/// Ensures a `library_override` Alarm's chosen clip is available as a named
/// sound file AlarmKit can load directly into its own alert — the mechanism
/// noted in .scratch/wake-mate/research/alarmkit-api.md §4:
/// `AlertConfiguration.AlertSound.named(_:)` resolves a file from either the
/// app's main bundle *or* `Library/Sounds`, and the latter is writable at
/// runtime. Materializing the clip there before scheduling is what lets it
/// play as AlarmKit's own alert sound at the actual fire time — phone
/// locked, app never reopened — instead of only ever being reachable once
/// the app happens to be foregrounded while ringing (see
/// `LibraryOverridePlaybackCoordinator`, which now only exists to cover the
/// case where this preparation didn't happen in time).
protocol LibraryOverrideSoundPreparing: Sendable {
    /// Returns the sound file name to pass to `.named(_:)` for `alarm`, or
    /// `nil` if `alarm` isn't a library_override alarm with a clip, or if
    /// preparing the file failed — callers should fall back to the app's
    /// default alert tone in either case.
    func prepareSoundFileName(for alarm: Alarm) async -> String?
}

final class LibraryOverrideSoundPreparer: LibraryOverrideSoundPreparing {
    private let alarmCallService: AlarmCallServicing
    private let soundsDirectory: URL

    init(
        alarmCallService: AlarmCallServicing,
        soundsDirectory: URL = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sounds", isDirectory: true)
    ) {
        self.alarmCallService = alarmCallService
        self.soundsDirectory = soundsDirectory
    }

    func prepareSoundFileName(for alarm: Alarm) async -> String? {
        guard alarm.mode == .libraryOverride, let clipID = alarm.libraryOverrideAlarmCallID else {
            return nil
        }

        let fileName = "library-override-\(clipID.uuidString).m4a"
        let fileURL = soundsDirectory.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileName
        }

        do {
            try FileManager.default.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)
            let alarmCall = try await alarmCallService.fetchAlarmCall(id: clipID)
            let data = try await alarmCallService.downloadClipData(storagePath: alarmCall.storagePath)
            try data.write(to: fileURL)
            return fileName
        } catch {
            return nil
        }
    }
}
