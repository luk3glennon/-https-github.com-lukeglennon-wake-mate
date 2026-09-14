import Foundation

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var clips: [LibraryClip] = []
    @Published var errorMessage: String?

    private let alarmCallService: AlarmCallServicing

    init(alarmCallService: AlarmCallServicing) {
        self.alarmCallService = alarmCallService
    }

    func load() async {
        do {
            clips = try await alarmCallService.listLibrary()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
