import Foundation

enum GoogleOAuthConfig {
    /// Replace with your OAuth 2.0 Client ID (Desktop app) from Google Cloud Console.
    /// You can also set the `GOOGLE_CLIENT_ID` key in Info.plist.
    static let defaultClientID = "YOUR_CLIENT_ID.apps.googleusercontent.com"

    static let redirectURI = "com.calendarairplane.app:/oauth2redirect"
    static let callbackURLScheme = "com.calendarairplane.app"

    static let scope = "https://www.googleapis.com/auth/calendar.readonly"

    static var clientID: String {
        if let id = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String,
           !id.isEmpty,
           !id.hasPrefix("YOUR_") {
            return id
        }
        return defaultClientID
    }

    static var isConfigured: Bool {
        !clientID.hasPrefix("YOUR_")
    }
}
