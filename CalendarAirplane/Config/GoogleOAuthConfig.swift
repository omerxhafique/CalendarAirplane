import Foundation

enum GoogleOAuthConfig {
    static let defaultClientID = "YOUR_CLIENT_ID.apps.googleusercontent.com"

    static let loopbackPort: UInt16 = 8765
    static var redirectURI: String { "http://127.0.0.1:\(loopbackPort)/oauth2redirect" }
    static let scope = "https://www.googleapis.com/auth/calendar.readonly"

    static var clientID: String {
        oauthValue(for: "GOOGLE_CLIENT_ID") ?? defaultClientID
    }

    static var clientSecret: String? {
        oauthValue(for: "GOOGLE_CLIENT_SECRET")
    }

    static var isConfigured: Bool {
        guard let id = oauthValue(for: "GOOGLE_CLIENT_ID"),
              let secret = oauthValue(for: "GOOGLE_CLIENT_SECRET") else {
            return false
        }
        return !id.hasPrefix("YOUR_") && !secret.hasPrefix("YOUR_")
    }

    /// Prefer external local config, then bundled local plist (dev), then Info.plist placeholders.
    private static func oauthValue(for key: String) -> String? {
        if let local = localOAuthPlist()[key] as? String,
           !local.isEmpty,
           !local.hasPrefix("YOUR_") {
            return local
        }
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
           !value.isEmpty,
           !value.hasPrefix("YOUR_") {
            return value
        }
        return nil
    }

    private static func localOAuthPlist() -> [String: Any] {
        for url in localOAuthCandidateURLs() {
            guard let data = try? Data(contentsOf: url),
                  let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
                  let dict = plist as? [String: Any] else {
                continue
            }
            return dict
        }
        return [:]
    }

    private static func localOAuthCandidateURLs() -> [URL] {
        var urls: [URL] = []
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            urls.append(appSupport.appendingPathComponent("CalendarAirplane/GoogleOAuth.local.plist"))
        }
        if let bundled = Bundle.main.url(forResource: "GoogleOAuth.local", withExtension: "plist") {
            urls.append(bundled)
        }
        return urls
    }
}
