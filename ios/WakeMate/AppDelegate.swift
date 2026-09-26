import UIKit

/// Bridges UIKit's remote-notification registration callbacks into
/// DeviceTokenServicing (ticket 06). Registering here only produces a
/// working push once the app has the Push Notifications capability enabled
/// on the Apple Developer Portal and is re-signed with a matching
/// entitlement — a manual, one-time setup step this project hasn't done yet
/// (see PROGRESS.md), not a permanent limitation of this code.
final class AppDelegate: NSObject, UIApplicationDelegate {
    var deviceTokenService: DeviceTokenServicing?

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { try? await deviceTokenService?.register(apnsToken: token) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Expected until the capability/entitlement above is in place —
        // nothing for the user to act on, so this is intentionally silent.
    }
}
