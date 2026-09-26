import Foundation

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var clips: [LibraryClip] = []
    @Published var errorMessage: String?

    private let alarmCallService: AlarmCallServicing
    private let shareService: ShareServicing
    private let friendService: FriendServicing

    init(alarmCallService: AlarmCallServicing, shareService: ShareServicing, friendService: FriendServicing) {
        self.alarmCallService = alarmCallService
        self.shareService = shareService
        self.friendService = friendService
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

    /// Resolves `handle` to a friend, then sends this clip their way.
    /// `createShare` (server-side) is the actual gatekeeper on whether the
    /// two are really connected — this is just a friendlier failure message
    /// for the common "typo'd the handle" case before even trying that.
    @discardableResult
    func share(clip: LibraryClip, toHandle handle: String) async -> Bool {
        do {
            guard let profile = try await friendService.searchProfile(byHandle: handle) else {
                errorMessage = "No one with that handle was found."
                return false
            }
            try await shareService.createShare(alarmCallID: clip.id, recipientID: profile.userID)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
