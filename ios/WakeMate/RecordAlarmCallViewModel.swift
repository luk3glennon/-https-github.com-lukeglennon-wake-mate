import Foundation

@MainActor
final class RecordAlarmCallViewModel: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isSaving = false
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var didSave = false
    @Published var errorMessage: String?
    /// Set when the mic permission hasn't been determined yet — the view
    /// shows the in-app consent explanation before triggering the real OS
    /// prompt (ticket 15: in-app consent captured alongside, not instead
    /// of, the OS prompt).
    @Published var isPresentingConsentSheet = false

    private let audioRecorder: AudioRecording
    private let alarmCallService: AlarmCallServicing
    private let consentService: ConsentServicing
    private var recordingURL: URL?
    private var timerTask: Task<Void, Never>?

    init(audioRecorder: AudioRecording, alarmCallService: AlarmCallServicing, consentService: ConsentServicing) {
        self.audioRecorder = audioRecorder
        self.alarmCallService = alarmCallService
        self.consentService = consentService
    }

    func startRecording() async {
        errorMessage = nil
        switch audioRecorder.permissionStatus() {
        case .undetermined:
            isPresentingConsentSheet = true
        case .denied:
            errorMessage = "Microphone access is off. Turn it on in Settings to record a clip."
        case .granted:
            await beginRecording()
        }
    }

    /// Called once the user taps "Allow" on the in-app consent sheet.
    /// Logs consent first, then triggers the real OS prompt — the two are
    /// meant to happen alongside each other, per ticket 15.
    func confirmConsentAndRecord() async {
        isPresentingConsentSheet = false
        do {
            try await consentService.logMicRecordingConsent()
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        guard await audioRecorder.requestPermission() else {
            errorMessage = "Microphone access is off. Turn it on in Settings to record a clip."
            return
        }
        await beginRecording()
    }

    func stopRecording() async {
        guard isRecording else { return }
        timerTask?.cancel()
        let duration = audioRecorder.stopRecording()
        isRecording = false
        elapsedSeconds = duration

        guard let recordingURL else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await alarmCallService.upload(fileURL: recordingURL, durationSeconds: duration)
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelRecording() {
        timerTask?.cancel()
        audioRecorder.cancelRecording()
        isRecording = false
        elapsedSeconds = 0
        recordingURL = nil
    }

    private func beginRecording() async {
        do {
            recordingURL = try audioRecorder.startRecording()
            elapsedSeconds = 0
            isRecording = true
            startTimer()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startTimer() {
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)
                if Task.isCancelled { return }
                elapsedSeconds += 0.2
                if elapsedSeconds >= audioRecorder.maxDuration {
                    await stopRecording()
                    return
                }
            }
        }
    }
}
