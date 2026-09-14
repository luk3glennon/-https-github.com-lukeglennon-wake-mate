import SwiftUI

/// Shared create/edit sheet for an Alarm. Snooze settings aren't editable
/// here — ADR-0003 fixes snooze duration/count to a single global default
/// for the MVP, so there's nothing per-Alarm to expose yet.
struct AlarmFormView: View {
    enum Mode {
        case create
        case edit(Alarm)

        fileprivate var isCreate: Bool {
            if case .create = self { return true }
            return false
        }
    }

    let mode: Mode
    let libraryClips: [LibraryClip]
    let onSave: (
        _ label: String?,
        _ wakeTime: WakeTime,
        _ repeatDays: [Int],
        _ alarmMode: AlarmMode,
        _ libraryOverrideAlarmCallID: UUID?
    ) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var label: String
    @State private var time: Date
    @State private var selectedDays: Set<Int>
    @State private var alarmMode: AlarmMode
    @State private var selectedClipID: UUID?
    @State private var isSaving = false

    init(
        mode: Mode,
        libraryClips: [LibraryClip] = [],
        onSave: @escaping (String?, WakeTime, [Int], AlarmMode, UUID?) async -> Void
    ) {
        self.mode = mode
        self.libraryClips = libraryClips
        self.onSave = onSave
        switch mode {
        case .create:
            _label = State(initialValue: "")
            _time = State(initialValue: Date())
            _selectedDays = State(initialValue: [])
            _alarmMode = State(initialValue: .autoPlay)
            _selectedClipID = State(initialValue: nil)
        case .edit(let alarm):
            _label = State(initialValue: alarm.label ?? "")
            _time = State(initialValue: Self.date(from: alarm.wakeTime))
            _selectedDays = State(initialValue: Set(alarm.repeatDays))
            _alarmMode = State(initialValue: alarm.mode)
            _selectedClipID = State(initialValue: alarm.libraryOverrideAlarmCallID)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Label") {
                    TextField("e.g. Weekdays", text: $label)
                }
                Section("Wake time") {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
                Section("Repeat") {
                    HStack(spacing: 8) {
                        ForEach(Self.weekdays, id: \.day) { weekday in
                            dayToggle(weekday)
                        }
                    }
                }
                Section("Wake sound") {
                    Picker("Wake sound", selection: $alarmMode) {
                        Text("Default").tag(AlarmMode.autoPlay)
                        Text("Library clip").tag(AlarmMode.libraryOverride)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    if alarmMode == .libraryOverride {
                        if libraryClips.isEmpty {
                            Text("Record a clip in your Library first to use it here.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Clip", selection: $selectedClipID) {
                                Text("Choose a clip").tag(UUID?.none)
                                ForEach(libraryClips) { clip in
                                    Text(clip.displayTitle).tag(UUID?.some(clip.id))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(mode.isCreate ? "New Alarm" : "Edit Alarm")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isSaving)
                }
            }
        }
    }

    private func dayToggle(_ weekday: (day: Int, symbol: String)) -> some View {
        let isSelected = selectedDays.contains(weekday.day)
        return Button {
            if isSelected {
                selectedDays.remove(weekday.day)
            } else {
                selectedDays.insert(weekday.day)
            }
        } label: {
            Text(weekday.symbol)
                .font(.footnote.bold())
                .frame(width: 32, height: 32)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let wakeTime = WakeTime(hour: components.hour ?? 0, minute: components.minute ?? 0)
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        // A library_override mode with no chosen clip isn't a valid combination
        // (see LibraryOverridePlaybackCoordinator, which requires a non-nil
        // clip id) — falling back to autoPlay keeps that invariant true here
        // rather than at every downstream reader.
        let resolvedMode: AlarmMode = (alarmMode == .libraryOverride && selectedClipID != nil) ? .libraryOverride : .autoPlay
        let resolvedClipID = resolvedMode == .libraryOverride ? selectedClipID : nil
        await onSave(trimmedLabel.isEmpty ? nil : trimmedLabel, wakeTime, selectedDays.sorted(), resolvedMode, resolvedClipID)
        dismiss()
    }

    private static func date(from wakeTime: WakeTime) -> Date {
        var components = DateComponents()
        components.hour = wakeTime.hour
        components.minute = wakeTime.minute
        return Calendar.current.date(from: components) ?? Date()
    }

    /// (Calendar.Component.weekday, single-letter symbol), Sunday first.
    private static let weekdays: [(day: Int, symbol: String)] = [
        (1, "S"), (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S"),
    ]
}
