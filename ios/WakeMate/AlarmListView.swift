import SwiftUI

struct AlarmListView: View {
    @StateObject private var viewModel: AlarmListViewModel
    @State private var isCreating = false
    @State private var editingAlarm: Alarm?

    init(alarmService: AlarmServicing, syncCoordinator: AlarmSyncCoordinating) {
        _viewModel = StateObject(
            wrappedValue: AlarmListViewModel(alarmService: alarmService, syncCoordinator: syncCoordinator)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Alarms")
                    .font(.headline)
                Spacer()
                Button {
                    isCreating = true
                } label: {
                    Label("Add Alarm", systemImage: "plus.circle.fill")
                }
                .disabled(viewModel.isBusy)
            }

            if viewModel.alarms.isEmpty {
                Text("No alarms yet. Add one to get started.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.alarms) { alarm in
                        AlarmRow(alarm: alarm, isBusy: viewModel.isBusy) {
                            editingAlarm = alarm
                        } onDelete: {
                            Task { await viewModel.deleteAlarm(alarm) }
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
        .task { await viewModel.load() }
        .sheet(isPresented: $isCreating) {
            AlarmFormView(mode: .create) { label, wakeTime, repeatDays in
                await viewModel.createAlarm(label: label, wakeTime: wakeTime, repeatDays: repeatDays)
            }
        }
        .sheet(item: $editingAlarm) { alarm in
            AlarmFormView(mode: .edit(alarm)) { label, wakeTime, repeatDays in
                await viewModel.updateAlarm(alarm, label: label, wakeTime: wakeTime, repeatDays: repeatDays)
            }
        }
    }
}

private struct AlarmRow: View {
    let alarm: Alarm
    let isBusy: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeText)
                    .font(.title3.monospacedDigit())
                if let label = alarm.label, !label.isEmpty {
                    Text(label)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text(repeatText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Edit", action: onEdit)
                .buttonStyle(.bordered)
                .disabled(isBusy)
            Button("Delete", role: .destructive, action: onDelete)
                .buttonStyle(.bordered)
                .disabled(isBusy)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var timeText: String {
        String(format: "%02d:%02d", alarm.wakeTime.hour, alarm.wakeTime.minute)
    }

    private var repeatText: String {
        guard !alarm.repeatDays.isEmpty else { return "Once" }
        let symbols = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return alarm.repeatDays.sorted().compactMap { symbols[safe: $0] }.joined(separator: ", ")
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
