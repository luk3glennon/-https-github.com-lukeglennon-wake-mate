import Foundation

/// Typed access to the values injected via `Secrets.xcconfig` -> Info.plist.
/// Crashing on a missing/invalid key is deliberate: these are required for
/// the app to function at all, and failing loudly at launch (in
/// development or CI) beats a silent misconfiguration surfacing later as a
/// confusing network error.
enum AppConfig {
    static let supabaseURL: URL = requiredURL("SUPABASE_URL")
    static let supabaseAnonKey: String = requiredString("SUPABASE_ANON_KEY")
    static let sentryDSN: String = requiredString("SENTRY_DSN")
    static let telemetryDeckAppID: String = requiredString("TELEMETRYDECK_APP_ID")

    private static func requiredString(_ key: String) -> String {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
            !value.isEmpty
        else {
            fatalError("Missing Info.plist key '\(key)' — did you copy Secrets.xcconfig.example to Secrets.xcconfig?")
        }
        return value
    }

    private static func requiredURL(_ key: String) -> URL {
        let raw = requiredString(key)
        guard let url = URL(string: raw) else {
            fatalError("Info.plist key '\(key)' is not a valid URL: \(raw)")
        }
        return url
    }
}
