import SwiftUI

struct LibraryView: View {
    @StateObject private var viewModel: LibraryViewModel
    let audioRecorder: AudioRecording
    let alarmCallService: AlarmCallServicing
    let consentService: ConsentServicing
    @State private var isRecording = false
    @State private var pendingDeleteClip: LibraryClip?
    @State private var sharingClip: LibraryClip?

    init(
        audioRecorder: AudioRecording,
        alarmCallService: AlarmCallServicing,
        shareService: ShareServicing,
        friendService: FriendServicing,
        consentService: ConsentServicing
    ) {
        self.audioRecorder = audioRecorder
        self.alarmCallService = alarmCallService
        self.consentService = consentService
        _viewModel = StateObject(
            wrappedValue: LibraryViewModel(
                alarmCallService: alarmCallService,
                shareService: shareService,
                friendService: friendService
            )
        )
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
                            Button("Share") {
                                sharingClip = clip
                            }
                            .tint(.blue)
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
        .sheet(item: $sharingClip) { clip in
            ShareClipView(clip: clip, viewModel: viewModel)
        }
    }
}

/// A friend's handle, typed in by hand — matches the "Add a Friend" flow's
/// own exact-handle search (FriendOnboardingView), so a sender only ever
/// needs the one identifier a friend would actually give them out loud.
private struct ShareClipView: View {
    @Environment(\.dismiss) private var dismiss
    let clip: LibraryClip
    @ObservedObject var viewModel: LibraryViewModel
    @State private var handle = ""
    @State private var isSending = false
    @State private var didSend = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Send \"\(clip.displayTitle)\" to") {
                    TextField("Friend's handle", text: $handle)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if didSend {
                    Text("Sent!")
                        .foregroundStyle(.green)
                }
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Share")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        Task {
                            isSending = true
                            didSend = await viewModel.share(clip: clip, toHandle: handle)
                            isSending = false
                            if didSend {
                                try? await Task.sleep(for: .seconds(1))
                                dismiss()
                            }
                        }
                    }
                    .disabled(handle.isEmpty || isSending)
                }
            }
        }
    }
}
