import Foundation
import Observation

/// What the planner starts from: "Customize with AI" on a community trip
struct PlannerSeed: Equatable {
    var destination: String
    var days: Int?
    var adaptFromId: String?
    var adaptTitle: String?
}

enum AppTab: Hashable { case explore, community, planner, trips, profile }

/// What a booking button asks to open
enum BookingAction {
    case offer(LiveActivity)
    case search(query: String, link: MatchedProduct?, search: String?)
    case hotels(HotelSearch)
}

/// App-wide state: the signed-in user and hand-offs between tabs.
@Observable
final class AppState {
    let auth = AuthManager()
    @ObservationIgnored let api: GoTravelNhaAPI
    @ObservationIgnored let partners: PartnerLauncher

    var user: AuthUser?
    var authError: String?
    var tab: AppTab = .explore
    var plannerSeed: PlannerSeed?
    var communityDestination: String?

    var signedIn: Bool { auth.signedIn }

    init() {
        api = GoTravelNhaAPI(client: APIClient(auth: auth))
        partners = PartnerLauncher(api: api)
    }

    func refreshUser() async {
        user = signedIn ? try? await api.me() : nil
    }

    /// Opens Keycloak directly; `then` is the tab to show once sign-in succeeds.
    func signIn(register: Bool = false, then destination: AppTab? = nil) {
        Task {
            do {
                if try await auth.signIn(register: register) {
                    await refreshUser()
                    if let destination { tab = destination }
                }
            } catch {
                authError = error.localizedDescription.isEmpty ? L("signin_unavailable") : error.localizedDescription
            }
        }
    }

    func signOut() {
        Task {
            await auth.signOut()
            user = nil
        }
    }

    func book(_ action: BookingAction, screen: String, placement: String) {
        let locale = klookLocalePath(appLanguage())
        Task {
            switch action {
            case .offer(let activity):
                if let offerId = activity.offerId {
                    await partners.open(placement: placement, screen: screen, provider: activity.provider, url: activity.partnerUrl, offerId: offerId, metadata: ["match": "offer"])
                } else if let href = activity.href {
                    openInBrowser(Config.siteURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + href)
                }
            case .search(let query, let link, let search):
                if let link {
                    await partners.open(placement: placement, screen: screen, provider: link.provider, url: localizedPartnerURL(link, klookLocalePath: locale), metadata: ["match": "product", "searchType": "activity"])
                } else {
                    await partners.open(placement: placement, screen: screen, provider: "klook", url: klookSearchURL(localePath: locale, query: search ?? query), metadata: ["match": search != nil ? "keyword" : "search", "searchType": "activity"])
                }
            case .hotels(let hotels):
                await partners.open(placement: placement, screen: screen, provider: "trip", url: hotels.url, metadata: ["searchType": "hotel"])
            }
        }
    }

    func openPartner(provider: String, url: String, placement: String, screen: String) {
        Task { await partners.open(placement: placement, screen: screen, provider: provider, url: url) }
    }
}
