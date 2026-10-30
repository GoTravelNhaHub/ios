import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import UIKit

/// Keycloak sign-in (realm gotravelnha, public client gotravelnha-mobile): Authorization Code +
/// PKCE in ASWebAuthenticationSession. Access tokens (aud gotravelnha-api) go to the API as
/// `Authorization: Bearer`; the offline refresh token, kept in the Keychain, keeps the user signed in.
@Observable
final class AuthManager: NSObject {
    private struct Tokens: Codable {
        var accessToken: String
        var refreshToken: String?
        var idToken: String?
        var expiresAt: Date
    }

    private struct Discovery: Decodable {
        let authorization_endpoint: URL
        let token_endpoint: URL
        let end_session_endpoint: URL?
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let id_token: String?
        let expires_in: Double?
    }

    enum AuthError: LocalizedError {
        case failed(String)
        var errorDescription: String? {
            if case .failed(let message) = self { return message }
            return nil
        }
    }

    private(set) var signedIn: Bool
    private var tokens: Tokens? {
        didSet {
            signedIn = tokens != nil
            if let tokens, let data = try? JSONEncoder().encode(tokens) { Keychain.write(data, "tokens") } else { Keychain.delete("tokens") }
        }
    }
    @ObservationIgnored private var discovery: Discovery?
    @ObservationIgnored private var refreshTask: Task<String?, Never>?
    @ObservationIgnored private var session: ASWebAuthenticationSession?

    override init() {
        let stored = Keychain.read("tokens").flatMap { try? JSONDecoder().decode(Tokens.self, from: $0) }
        tokens = stored
        signedIn = stored != nil
        super.init()
    }

    private func loadDiscovery() async throws -> Discovery {
        if let discovery { return discovery }
        let url = Config.oidcIssuer.appendingPathComponent(".well-known/openid-configuration")
        let (data, _) = try await URLSession.shared.data(from: url)
        let value = try JSONDecoder().decode(Discovery.self, from: data)
        discovery = value
        return value
    }

    /// Opens the Keycloak page. Returns false when the user cancelled.
    func signIn(register: Bool) async throws -> Bool {
        let config = try await loadDiscovery()
        let verifier = Self.randomToken()
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URL
        let state = Self.randomToken()
        var components = URLComponents(url: config.authorization_endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "client_id", value: Config.oidcClientID),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid profile email offline_access"),
            .init(name: "redirect_uri", value: Config.oidcRedirectURI),
            .init(name: "state", value: state),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "ui_locales", value: ["vi": "vi", "zh": "zh-CN"][appLanguage()] ?? "en"),
        ] + (register ? [.init(name: "prompt", value: "create")] : [])

        let callback: URL
        do {
            callback = try await browse(components.url!)
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            return false
        }
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let error = items.first(where: { $0.name == "error" })?.value {
            if error == "access_denied" { return false }
            throw AuthError.failed(error)
        }
        guard items.first(where: { $0.name == "state" })?.value == state, let code = items.first(where: { $0.name == "code" })?.value else {
            throw AuthError.failed("The sign-in response was not valid.")
        }
        tokens = try await tokenRequest([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": Config.oidcRedirectURI,
            "client_id": Config.oidcClientID,
            "code_verifier": verifier,
        ], previous: nil)
        return true
    }

    private func browse(_ url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: Config.oidcRedirectScheme) { callback, error in
                if let callback { continuation.resume(returning: callback) } else { continuation.resume(throwing: error ?? AuthError.failed("Sign-in did not finish.")) }
            }
            session.presentationContextProvider = self
            // Share Keycloak's SSO cookie with Safari so "remember me" and Google sign-in work as on the site
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            session.start()
        }
    }

    /// A current access token, refreshed when about to expire; nil when signed out.
    func accessToken(forceRefresh: Bool = false) async -> String? {
        guard let current = tokens else { return nil }
        if !forceRefresh, current.expiresAt.timeIntervalSinceNow > 30 { return current.accessToken }
        if let refreshTask { return await refreshTask.value }
        let task = Task<String?, Never> { [weak self] in
            guard let self else { return nil }
            defer { self.refreshTask = nil }
            guard let refresh = current.refreshToken else { self.tokens = nil; return nil }
            do {
                let fresh = try await self.tokenRequest(["grant_type": "refresh_token", "refresh_token": refresh, "client_id": Config.oidcClientID], previous: current)
                self.tokens = fresh
                return fresh.accessToken
            } catch AuthError.failed {
                // Refresh token expired or revoked (Keycloak offline session ended): sign out locally
                self.tokens = nil
                return nil
            } catch {
                // Offline: keep the session, the request fails as a network error
                return current.accessToken
            }
        }
        refreshTask = task
        return await task.value
    }

    private func tokenRequest(_ form: [String: String], previous: Tokens?) async throws -> Tokens {
        let config = try await loadDiscovery()
        var request = URLRequest(url: config.token_endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = form.map { "\($0.key)=\($0.value.formEncoded)" }.joined(separator: "&").data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthError.failed("Keycloak refused the token request.")
        }
        let body = try JSONDecoder().decode(TokenResponse.self, from: data)
        return Tokens(
            accessToken: body.access_token,
            refreshToken: body.refresh_token ?? previous?.refreshToken,
            idToken: body.id_token ?? previous?.idToken,
            expiresAt: Date().addingTimeInterval(body.expires_in ?? 300)
        )
    }

    /// Ends the local session, then the Keycloak session in the browser (best effort).
    func signOut() async {
        let idToken = tokens?.idToken
        tokens = nil
        guard let idToken, let endpoint = try? await loadDiscovery().end_session_endpoint else { return }
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "id_token_hint", value: idToken),
            .init(name: "post_logout_redirect_uri", value: Config.oidcRedirectURI),
        ]
        _ = try? await browse(components.url!)
    }

    private static func randomToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URL
    }
}

extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}

extension Data {
    var base64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}

extension String {
    var formEncoded: String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}
