import Foundation
import AVFoundation

enum MicPermissionStatus: Sendable {
    case granted
    case denied
    case undetermined
}

/// Thin seam over AVAudioRecorder — see AuthServicing for why this pattern
/// exists (view-model unit testing without touching a real microphone).
protocol AudioRecording: Sendable {
    func permissionStatus() -> MicPermissionStatus
    /// Triggers the OS mic permission prompt if not yet determined. Returns
    /// whether recording is currently permitted.
    func requestPermission() async -> Bool
    /// Starts recording to a fresh temporary file and returns its URL.
    func startRecording() throws -> URL
    /// Stops recording (a no-op if not recording) and returns the elapsed
    /// duration in seconds.
    @discardableResult
    func stopRecording() -> TimeInterval
    /// Stops (if needed) and deletes the in-progress recording.
    func cancelRecording()
}

/// Recording format is locked by ticket 13: AAC-HE, mono, 44.1kHz, .m4a,
/// 32kbps, capped at 30 seconds. `record(forDuration:)` enforces the cap at
/// the AVAudioRecorder level as a hard backstop; the view model also runs
/// its own timer so the UI can show elapsed time and stop early.
///
/// Not thread-safe by design — every call is expected to come from the
/// view model driving the record button, which is `@MainActor`. Marked
/// `@unchecked Sendable` on that basis, matching AlarmKitScheduler's own
/// note about where its thread-safety guarantees actually come from.
final class AVFoundationAudioRecorder: NSObject, AudioRecording, @unchecked Sendable {
    static let maxDuration: TimeInterval = 30

    private var recorder: AVAudioRecorder?

    func permissionStatus() -> MicPermissionStatus {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return .granted
        case .denied: return .denied
        case .undetermined: return .undetermined
        @unknown default: return .denied
        }
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording() throws -> URL {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC_HE,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 32_000,
        ]

        let newRecorder = try AVAudioRecorder(url: url, settings: settings)
        newRecorder.record(forDuration: Self.maxDuration)
        recorder = newRecorder
        return url
    }

    @discardableResult
    func stopRecording() -> TimeInterval {
        let duration = recorder?.currentTime ?? 0
        recorder?.stop()
        recorder = nil
        return duration
    }

    func cancelRecording() {
        recorder?.stop()
        recorder?.deleteRecording()
        recorder = nil
    }
}
