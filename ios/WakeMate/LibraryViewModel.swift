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

    func deleteClip(_ clip: LibraryClip) async {
        do {
            try await alarmCallService.deleteClip(id: clip.id, storagePath: clip.storagePath)
            clips.removeAll { $0.id == clip.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
