import SwiftUI

struct LibraryView: View {
    @StateObject private var viewModel: LibraryViewModel
    let audioRecorder: AudioRecording
    let alarmCallService: AlarmCallServicing
    let consentService: ConsentServicing
    @State private var isRecording = false
    @State private var pendingDeleteClip: LibraryClip?

    init(audioRecorder: AudioRecording, alarmCallService: AlarmCallServicing, consentService: ConsentServicing) {
        self.audioRecorder = audioRecorder
        self.alarmCallService = alarmCallService
        self.consentService = consentService
        _viewModel = StateObject(wrappedValue: LibraryViewModel(alarmCallService: alarmCallService))
    }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.clips.isEmpty {
                    Text("No clips yet. Record one to get started.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.clips) { clip in
                        HStack {
                            Text(clip.displayTitle)
                            Spacer()
                            Text(clip.sourceLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                pendingDeleteClip = clip
                            }
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isRecording = true
                    } label: {
                        Label("Record", systemImage: "mic.fill")
                    }
                }
            }
        }
        .task { await viewModel.load() }
        .confirmationDialog(
            "Delete this recording?",
            isPresented: Binding(
                get: { pendingDeleteClip != nil },
                set: { if !$0 { pendingDeleteClip = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let clip = pendingDeleteClip {
                    Task { await viewModel.deleteClip(clip) }
                }
                pendingDeleteClip = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteClip = nil
            }
        } message: {
            Text("If an alarm is currently using this recording, that alarm will switch back to its default sound.")
        }
        .sheet(isPresented: $isRecording) {
            RecordAlarmCallView(
                audioRecorder: audioRecorder,
                alarmCallService: alarmCallService,
                consentService: consentService,
                onSaved: { Task { await viewModel.load() } }
            )
        }
    }
}
