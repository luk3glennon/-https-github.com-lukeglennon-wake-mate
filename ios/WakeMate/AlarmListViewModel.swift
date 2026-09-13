import Foundation

@MainActor
final class AlarmListViewModel: ObservableObject {
    @Published private(set) var alarms: [Alarm] = []
    @Published var errorMessage: String?
    @Published private(set) var isBusy = false

    private let alarmService: AlarmServicing
    private let syncCoordinator: AlarmSyncCoordinating

    init(alarmService: AlarmServicing, syncCoordinator: AlarmSyncCoordinating) {
        self.alarmService = alarmService
        self.syncCoordinator = syncCoordinator
    }

    func load() async {
        do {
            alarms = try await alarmService.listAlarms()
            await syncCoordinator.sync(alarms: alarms)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createAlarm(label: String?, wakeTime: WakeTime, repeatDays: [Int]) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let created = try await alarmService.createAlarm(label: label, wakeTime: wakeTime, repeatDays: repeatDays)
            alarms.append(created)
            resort()
            await syncCoordinator.sync(alarms: alarms)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateAlarm(_ alarm: Alarm, label: String?, wakeTime: WakeTime, repeatDays: [Int]) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let updated = try await alarmService.updateAlarm(
                id: alarm.id,
                label: label,
                wakeTime: wakeTime,
                repeatDays: repeatDays
            )
            if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
                alarms[index] = updated
            }
            resort()
            await syncCoordinator.sync(alarms: alarms)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAlarm(_ alarm: Alarm) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await alarmService.deleteAlarm(id: alarm.id)
            alarms.removeAll { $0.id == alarm.id }
            await syncCoordinator.sync(alarms: alarms)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resort() {
        alarms.sort { $0.wakeTime < $1.wakeTime }
    }
}
