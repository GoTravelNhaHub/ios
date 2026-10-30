import SafariServices
import UIKit

/// Opens a partner page through /api/affiliate/click, so the click is recorded and the URL
/// carries our affiliate ids (added on the server). If the API cannot be reached, the partner URL
/// still opens with the ids added here, so the booking is not blocked.
///
/// When the Klook or Trip.com app is installed and claims the link (universal links), it opens
/// there, so travellers keep their partner account and saved details; otherwise in a Safari sheet.
final class PartnerLauncher {
    private let api: GoTravelNhaAPI

    /// Anonymous id for click attribution, like the site's visitor session
    private lazy var sessionId: String = {
        if let stored = UserDefaults.standard.string(forKey: "gtn_session_id") { return stored }
        let id = "app-\(UUID().uuidString.lowercased())"
        UserDefaults.standard.set(id, forKey: "gtn_session_id")
        return id
    }()

    init(api: GoTravelNhaAPI) { self.api = api }

    func open(placement: String, screen: String, provider: String? = nil, url: String? = nil, offerId: String? = nil, metadata: [String: String] = [:]) async {
        let body = GoTravelNhaAPI.ClickBody(
            provider: provider, baseUrl: url, offerId: offerId, placementKey: placement, pagePath: "app:\(screen)",
            sessionId: sessionId, metadata: metadata.merging(["platform": "ios"]) { $1 }
        )
        let tracked = try? await api.click(body)
        let target: String
        if let tracked, isApprovedPartnerURL(tracked) {
            target = tracked
        } else if let url, let provider, isApprovedPartnerURL(url) {
            target = withFallbackAffiliateIDs(url, provider: provider)
        } else {
            return
        }
        openInPartnerApp(target)
    }
}

/// Opens a partner page in its installed app when the app claims the link, else in a Safari sheet.
@MainActor
func openInPartnerApp(_ value: String) {
    guard let url = URL(string: value) else { return }
    UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { opened in
        if !opened { openInBrowser(value) }
    }
}

/// Shows a web page in an in-app Safari sheet.
@MainActor
func openInBrowser(_ value: String) {
    guard let url = URL(string: value) else { return }
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    guard var top = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController else {
        UIApplication.shared.open(url)
        return
    }
    while let presented = top.presentedViewController { top = presented }
    top.present(SFSafariViewController(url: url), animated: true)
}
