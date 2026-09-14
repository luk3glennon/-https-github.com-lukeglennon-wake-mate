import SwiftUI

struct RecordAlarmCallView: View {
    @StateObject private var viewModel: RecordAlarmCallViewModel
    @Environment(\.dismiss) private var dismiss
    let onSaved: () -> Void

    init(
        audioRecorder: AudioRecording,
        alarmCallService: AlarmCallServicing,
        consentService: ConsentServicing,
        onSaved: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: RecordAlarmCallViewModel(
                audioRecorder: audioRecorder,
                alarmCallService: alarmCallService,
                consentService: consentService
            )
        )
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Text(timeText)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                Text("Up to 30 seconds")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    Task {
                        if viewModel.isRecording {
                            await viewModel.stopRecording()
                        } else {
                            await viewModel.startRecording()
                        }
                    }
                } label: {
                    Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(viewModel.isRecording ? Color.red : Color.accentColor)
                }
                .disabled(viewModel.isSaving)

                if viewModel.isSaving {
                    ProgressView("Saving...")
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Record Alarm Call")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.cancelRecording()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.isPresentingConsentSheet) {
                MicConsentView(
                    onAllow: { Task { await viewModel.confirmConsentAndRecord() } }
                )
            }
            .onChange(of: viewModel.didSave) { _, didSave in
                guard didSave else { return }
                onSaved()
                dismiss()
            }
        }
    }

    private var timeText: String {
        let totalSeconds = Int(viewModel.elapsedSeconds)
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

/// In-app consent explanation shown alongside (before) the OS mic
/// permission prompt, per ticket 15's GDPR policy — the OS prompt only
/// appears once, but so does this, since it's shown only while permission
/// is still `.undetermined` (see RecordAlarmCallViewModel.startRecording).
private struct MicConsentView: View {
    let onAllow: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("WakeMate uses your microphone to record Alarm Calls — short voice clips you can use for your own alarms or share with friends.")
                Spacer()
                Button("Allow Microphone Access") {
                    onAllow()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                Button("Not Now", role: .cancel) {
                    dismiss()
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .navigationTitle("Microphone Access")
        }
    }
}
