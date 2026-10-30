import Foundation

/// Server addresses. Production by default; for a local backend and Keycloak, pass launch
/// arguments in the scheme (they land in UserDefaults), e.g.
/// `-GTNApiBaseURL http://localhost:3002 -GTNOidcIssuer http://localhost:8080/realms/gotravelnha`.
enum Config {
    static let apiBaseURL = URL(string: override("GTNApiBaseURL") ?? "https://api.gotravelnha.com")!
    static let oidcIssuer = URL(string: override("GTNOidcIssuer") ?? "https://auth.gotravelnha.com/realms/gotravelnha")!
    static let siteURL = URL(string: override("GTNSiteURL") ?? "https://www.gotravelnha.com")!

    /// Keycloak public client for the mobile apps (keycloak/realm/gotravelnha-realm.json)
    static let oidcClientID = "gotravelnha-mobile"
    static let oidcRedirectScheme = "com.gotravelnha.app"
    static let oidcRedirectURI = "com.gotravelnha.app:/oauth2redirect"

    /// Used only when the click API cannot be reached, so a booking still carries our ids
    static let klookAid = "89020"
    static let tripAllianceID = "3883416"
    static let tripSID = "22874365"

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private static func override(_ key: String) -> String? {
        UserDefaults.standard.string(forKey: key).flatMap { $0.isEmpty ? nil : $0 }
    }
}

/// App content language (en, vi or zh) from the per-app or system language
func appLanguage() -> String {
    let code = Bundle.main.preferredLocalizations.first ?? Locale.preferredLanguages.first ?? "en"
    if code.hasPrefix("vi") { return "vi" }
    if code.hasPrefix("zh") { return "zh" }
    return "en"
}

/// Localized text from Localizable.xcstrings; `args` fill %@ / %lld placeholders (plurals included)
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    return args.isEmpty ? format : String.localizedStringWithFormat(format, args)
}
