import SwiftUI

/// Shared create/edit sheet for an Alarm. Snooze settings aren't editable
/// here — ADR-0003 fixes snooze duration/count to a single global default
/// for the MVP, so there's nothing per-Alarm to expose yet. Library-override
/// mode isn't editable here either: it depends on a chosen Library clip,
/// which doesn't exist until ticket 05.
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
    let onSave: (_ label: String?, _ wakeTime: WakeTime, _ repeatDays: [Int]) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var label: String
    @State private var time: Date
    @State private var selectedDays: Set<Int>
    @State private var isSaving = false

    init(mode: Mode, onSave: @escaping (String?, WakeTime, [Int]) async -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .create:
            _label = State(initialValue: "")
            _time = State(initialValue: Date())
            _selectedDays = State(initialValue: [])
        case .edit(let alarm):
            _label = State(initialValue: alarm.label ?? "")
            _time = State(initialValue: Self.date(from: alarm.wakeTime))
            _selectedDays = State(initialValue: Set(alarm.repeatDays))
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
        await onSave(trimmedLabel.isEmpty ? nil : trimmedLabel, wakeTime, selectedDays.sorted())
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
