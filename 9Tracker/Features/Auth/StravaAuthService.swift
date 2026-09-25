import AuthenticationServices
import Foundation
import Observation

/// Owns Strava OAuth state: login, token refresh, logout.
/// Injected app-wide via `.environment(StravaAuthService())`.
@Observable
@MainActor
final class StravaAuthService: NSObject {
    private(set) var isAuthenticated = false

    // Injected at build time from Config/Secrets.xcconfig (gitignored) via
    // Info.plist — never hardcoded, never committed. See Config/Secrets.xcconfig.example.
    private let clientID: String = Bundle.main.infoDictionary?["StravaClientID"] as? String ?? ""
    private let clientSecret: String = Bundle.main.infoDictionary?["StravaClientSecret"] as? String ?? ""
    // Strava validates redirect_uri by its HOST matching the app's registered
    // "Authorization Callback Domain" (localhost) — a bare custom scheme like
    // "ninetracker://oauth-callback" has no host and gets rejected with
    // "redirect_uri invalid". Host must literally be "localhost".
    private let redirectURI = "ninetracker://localhost/oauth-callback"

    private var webAuthSession: ASWebAuthenticationSession?

    override init() {
        super.init()
        isAuthenticated = (try? KeychainStore.read(.stravaAccessToken)) != nil
    }

    func login() async throws {
        var components = URLComponents(string: "https://www.strava.com/oauth/mobile/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "scope", value: "activity:read_all"),
        ]

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: components.url!,
                callbackURLScheme: "ninetracker"
            ) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.webAuthSession = session
            session.start()
        }

        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value
        else {
            throw URLError(.badServerResponse)
        }

        try await exchangeCodeForToken(code)
        isAuthenticated = true
    }

    func logout() throws {
        try KeychainStore.delete(.stravaAccessToken)
        try KeychainStore.delete(.stravaRefreshToken)
        try KeychainStore.delete(.stravaExpiresAt)
        isAuthenticated = false
    }

    /// Returns a valid access token, refreshing first if expired.
    /// Called by StravaAPIClient before every request — never call the Strava
    /// API with a token you haven't run through this first.
    func validAccessToken() async throws -> String {
        if let expiresAtRaw = try KeychainStore.read(.stravaExpiresAt),
           let expiresAt = Double(expiresAtRaw),
           Date().timeIntervalSince1970 < expiresAt - 60,
           let token = try KeychainStore.read(.stravaAccessToken) {
            return token
        }
        return try await refreshToken()
    }

    // MARK: - Private

    private struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String
        let expiresAt: Double

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresAt = "expires_at"
        }
    }

    private func exchangeCodeForToken(_ code: String) async throws {
        var request = URLRequest(url: URL(string: "https://www.strava.com/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code",
        ]
        request.httpBody = body
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let token = try await APIClient.send(request, decodeAs: TokenResponse.self)
        try persist(token)
    }

    private func refreshToken() async throws -> String {
        guard let refreshToken = try KeychainStore.read(.stravaRefreshToken) else {
            throw URLError(.userAuthenticationRequired)
        }

        var request = URLRequest(url: URL(string: "https://www.strava.com/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
        ]
        request.httpBody = body
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let token = try await APIClient.send(request, decodeAs: TokenResponse.self)
        try persist(token)
        return token.accessToken
    }

    private func persist(_ token: TokenResponse) throws {
        try KeychainStore.save(token.accessToken, for: .stravaAccessToken)
        try KeychainStore.save(token.refreshToken, for: .stravaRefreshToken)
        try KeychainStore.save(String(token.expiresAt), for: .stravaExpiresAt)
    }
}

extension StravaAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}
