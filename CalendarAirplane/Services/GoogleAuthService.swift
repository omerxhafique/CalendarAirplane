import AppKit
import Foundation

@MainActor
final class GoogleAuthService: ObservableObject {
    static let shared = GoogleAuthService()

    @Published private(set) var isSignedIn = false
    @Published private(set) var userEmail: String?
    @Published var lastError: String?

    private var accessToken: String?
    private var accessExpiry: Date?
    private var codeVerifier: String?

    private init() {
        isSignedIn = KeychainHelper.load(account: "refresh_token") != nil
    }

    func signIn() {
        guard GoogleOAuthConfig.isConfigured else {
            lastError = "Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in Info.plist (Desktop OAuth client in Google Cloud)."
            return
        }
        lastError = nil
        let verifier = PKCE.generateVerifier()
        codeVerifier = verifier
        let challenge = PKCE.challenge(for: verifier)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: GoogleOAuthConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: GoogleOAuthConfig.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: GoogleOAuthConfig.scope),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]
        guard let authURL = components.url else { return }

        Task {
            do {
                async let redirectURL = LoopbackOAuthReceiver.waitForRedirect(
                    port: GoogleOAuthConfig.loopbackPort,
                    path: "/oauth2redirect"
                )
                NSWorkspace.shared.open(authURL)
                let callbackURL = try await redirectURL
                guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "code" })?
                    .value
                else {
                    lastError = "Missing authorization code."
                    return
                }
                await exchangeCode(code)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func signOut() {
        KeychainHelper.deleteAll()
        accessToken = nil
        accessExpiry = nil
        isSignedIn = false
        userEmail = nil
    }

    func getValidAccessToken() async throws -> String {
        if let accessToken, let accessExpiry, accessExpiry > Date().addingTimeInterval(60) {
            return accessToken
        }
        guard let refresh = KeychainHelper.load(account: "refresh_token") else {
            throw AuthError.notSignedIn
        }
        try await refreshAccessToken(refreshToken: refresh)
        guard let accessToken, let accessExpiry, accessExpiry > Date() else {
            throw AuthError.refreshFailed
        }
        return accessToken
    }

    private func exchangeCode(_ code: String) async {
        guard let verifier = codeVerifier else {
            lastError = "Missing PKCE verifier."
            return
        }
        do {
            var body: [String: String] = [
                "client_id": GoogleOAuthConfig.clientID,
                "code": code,
                "code_verifier": verifier,
                "grant_type": "authorization_code",
                "redirect_uri": GoogleOAuthConfig.redirectURI,
            ]
            body.merge(tokenClientCredentials()) { _, new in new }
            let token = try await postTokenRequest(body: body)
            try store(token: token)
            isSignedIn = true
            await fetchUserEmail()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func refreshAccessToken(refreshToken: String) async throws {
        var body: [String: String] = [
            "client_id": GoogleOAuthConfig.clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
        ]
        body.merge(tokenClientCredentials()) { _, new in new }
        let token = try await postTokenRequest(body: body)
        try store(token: token)
    }

    private func store(token: TokenResponse) throws {
        if let access = token.access_token {
            accessToken = access
            try? KeychainHelper.save(access, account: "access_token")
        }
        if let expiresIn = token.expires_in {
            let expiry = Date().addingTimeInterval(TimeInterval(expiresIn))
            accessExpiry = expiry
            try? KeychainHelper.save(String(expiry.timeIntervalSince1970), account: "access_expiry")
        }
        if let refresh = token.refresh_token {
            try KeychainHelper.save(refresh, account: "refresh_token")
        }
    }

    private func tokenClientCredentials() -> [String: String] {
        guard let secret = GoogleOAuthConfig.clientSecret else { return [:] }
        return ["client_secret": secret]
    }

    private func postTokenRequest(body: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = body.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            if let apiError = try? JSONDecoder().decode(GoogleTokenErrorResponse.self, from: data),
               let description = apiError.error_description ?? apiError.error {
                throw AuthError.server(description)
            }
            let message = String(data: data, encoding: .utf8) ?? "Token request failed"
            throw AuthError.server(message)
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func fetchUserEmail() async {
        do {
            let token = try await getValidAccessToken()
            var request = URLRequest(url: URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, _) = try await URLSession.shared.data(for: request)
            if let info = try? JSONDecoder().decode(UserInfo.self, from: data) {
                userEmail = info.email
            }
        } catch {
            userEmail = nil
        }
    }
}

private struct GoogleTokenErrorResponse: Decodable {
    let error: String?
    let error_description: String?
}

private struct TokenResponse: Decodable {
    let access_token: String?
    let expires_in: Int?
    let refresh_token: String?
    let token_type: String?
}

private struct UserInfo: Decodable {
    let email: String?
}

enum AuthError: LocalizedError {
    case notSignedIn
    case refreshFailed
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Not signed in to Google."
        case .refreshFailed: return "Could not refresh access token."
        case .server(let msg): return msg
        }
    }
}
