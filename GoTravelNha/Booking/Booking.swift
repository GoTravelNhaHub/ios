import Foundation

// Per-day booking suggestions on a trip, ported from web/utils/community-booking.ts (and the
// Android app's booking/Booking.kt). Keep them in step: the partner-links API keys its answers by
// the exact query klookQuery() builds. Honesty rules as on the site: a price or a specific product
// appears only for a verified catalogue activity or a product page found by search.

struct SearchCity { let name: String; let hotelCityId: Int }

/// Trip.com hotel city ids (web/utils/trip-search.ts)
let searchCities: [SearchCity] = [
    .init(name: "Singapore", hotelCityId: 73), .init(name: "Bangkok", hotelCityId: 359), .init(name: "Kuala Lumpur", hotelCityId: 315),
    .init(name: "Hong Kong", hotelCityId: 58), .init(name: "Bali", hotelCityId: 723), .init(name: "Phuket", hotelCityId: 725),
    .init(name: "Ho Chi Minh City", hotelCityId: 301), .init(name: "Hanoi", hotelCityId: 286), .init(name: "Taipei", hotelCityId: 617),
    .init(name: "Seoul", hotelCityId: 274), .init(name: "Tokyo", hotelCityId: 228), .init(name: "Osaka", hotelCityId: 219), .init(name: "Sydney", hotelCityId: 501),
]

enum Suggestion: Hashable {
    case offer(LiveActivity)
    /// `link`: a product page found for the stop; `search`: better Klook search wording
    case search(query: String, label: String, link: MatchedProduct?, search: String?)
}

struct HotelSearch: Hashable { let city: String; let url: String }

struct DaySuggestions: Hashable {
    let day: Int
    let hotels: HotelSearch?
    var activities: [Suggestion]
}

private let maxActivitiesPerDay = 3
private let maxQueryWords = 6

// Stops that are not things to book: meals, rest, hotel, transfers, free time
private let notBookable = try! NSRegularExpression(
    pattern: "\\b(breakfast|brunch|lunch|dinner|supper|meal|snack|coffee|caf[eé]|hawker|food court|rest|nap|relax|hotel|check[- ]?in|check[- ]?out|airport|arriv|depart|transfer|flight|free time|downtime|stroll|walk around|pack)\\b",
    options: .caseInsensitive
)

// Words that describe the visit rather than name the place
private let leadingWords = try! NSRegularExpression(
    pattern: "^(?:(?:morning|afternoon|evening|half[- ]day|full[- ]day|day trip|explore|visit|discover|tour|see|enjoy|experience|stroll|relax)\\b[\\s:,-]*(?:at|in|around|to|the)?\\s+)+",
    options: .caseInsensitive
)

private extension String {
    func replacing(_ pattern: String, with template: String, options: NSRegularExpression.Options = []) -> String {
        let regex = try! NSRegularExpression(pattern: pattern, options: options)
        return regex.stringByReplacingMatches(in: self, range: NSRange(startIndex..., in: self), withTemplate: template)
    }

    func matches(_ regex: NSRegularExpression) -> Bool {
        regex.firstMatch(in: self, range: NSRange(startIndex..., in: self)) != nil
    }

    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

func queryEncoded(_ value: String) -> String {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
}

func klookSearchURL(localePath: String, query: String) -> String {
    "https://www.klook.com/\(localePath)/search/result/?query=\(queryEncoded(query))"
}

func tripHotelURL(cityId: Int) -> String {
    "https://www.trip.com/hotels/list?city=\(cityId)&adult=2&children=0&crn=1&locale=en-SG&curr=SGD"
}

/// Klook search wording for a stop: keep the place after the last "at", drop notes in brackets
/// and visit words, then add the city when missing.
func klookQuery(_ title: String, destination: String) -> String {
    var clean = title.replacing("\\([^)]*\\)", with: " ").replacing("\\s+", with: " ").trimmed
    clean = clean.components(separatedBy: try! NSRegularExpression(pattern: "\\s+[–—-]\\s+")).first ?? clean
    if let colon = clean.lastIndex(of: ":") { clean = String(clean[clean.index(after: colon)...]) }
    let at = try! NSRegularExpression(pattern: "^.*\\s(?:at|@)\\s+(.+)$", options: .caseInsensitive)
    if let match = at.firstMatch(in: clean, range: NSRange(clean.startIndex..., in: clean)), let range = Range(match.range(at: 1), in: clean) {
        clean = String(clean[range])
    }
    clean = leadingWords.stringByReplacingMatches(in: clean, range: NSRange(clean.startIndex..., in: clean), withTemplate: "").trimmed
    if clean.isEmpty { clean = title.trimmed }
    clean = String(clean.components(separatedBy: " ").prefix(maxQueryWords).joined(separator: " ").prefix(80))
    return clean.lowercased().contains(destination.lowercased()) ? clean : "\(clean) \(destination)"
}

private extension String {
    func components(separatedBy regex: NSRegularExpression) -> [String] {
        var parts: [String] = []
        var last = startIndex
        for match in regex.matches(in: self, range: NSRange(startIndex..., in: self)) {
            guard let range = Range(match.range, in: self) else { continue }
            parts.append(String(self[last..<range.lowerBound]))
            last = range.upperBound
        }
        parts.append(String(self[last...]))
        return parts
    }
}

func daySuggestions(_ days: [ItineraryDay], activities: [String: LiveActivity], destination: String) -> [DaySuggestions] {
    let needle = destination.trimmed.lowercased()
    let city = searchCities.first { needle.contains($0.name.lowercased()) }
    var seenQueries = Set<String>()
    var seenOffers = Set<String>()

    return days.enumerated().map { index, day in
        var offers: [Suggestion] = []
        var searches: [Suggestion] = []
        for item in day.items {
            if let id = item.activityId, let activity = activities[id], activity.verified, activity.offerId != nil || activity.href != nil, !seenOffers.contains(activity.id) {
                seenOffers.insert(activity.id)
                offers.append(.offer(activity))
                continue
            }
            if item.title.matches(notBookable) { continue }
            let query = klookQuery(item.title, destination: destination)
            if !seenQueries.insert(query.lowercased()).inserted { continue }
            searches.append(.search(query: query, label: item.title, link: nil, search: nil))
        }
        return DaySuggestions(
            day: index + 1,
            hotels: index == 0 ? city.map { HotelSearch(city: $0.name, url: tripHotelURL(cityId: $0.hotelCityId)) } : nil,
            activities: Array((offers + searches).prefix(maxActivitiesPerDay))
        )
    }
}

/// Apply what AI web search found: a product page replaces the search, a better keyword replaces
/// the search text, and a stop Klook has nothing for loses its button. Stops not looked up yet keep their search.
func withMatchedProducts(_ days: [DaySuggestions], links: [String: StopMatch]) -> [DaySuggestions] {
    days.map { day in
        var copy = day
        copy.activities = day.activities.flatMap { entry -> [Suggestion] in
            guard case let .search(query, label, _, _) = entry, let match = links[query] else { return [entry] }
            if let product = match.product { return [.search(query: query, label: label, link: product, search: match.search)] }
            if let search = match.search { return [.search(query: query, label: label, link: nil, search: search)] }
            return []
        }
        return copy
    }
}

/// Klook product pages are stored without a locale; open them in the user's language
func localizedPartnerURL(_ link: MatchedProduct, klookLocalePath: String) -> String {
    guard link.provider == "klook", link.url.hasPrefix("https://www.klook.com/") else { return link.url }
    return "https://www.klook.com/\(klookLocalePath)/" + link.url.dropFirst("https://www.klook.com/".count)
}

/// App language → Klook locale path, as on the site
func klookLocalePath(_ language: String) -> String {
    switch language {
    case "vi": return "vi"
    case "zh": return "zh-CN"
    default: return "en-SG"
    }
}

private let approvedPartnerHosts = ["trip.com", "klook.com", "agoda.com", "booking.com"]

func isApprovedPartnerURL(_ value: String) -> Bool {
    guard let url = URL(string: value), url.scheme == "https", let host = url.host?.lowercased() else { return false }
    return approvedPartnerHosts.contains { host == $0 || host.hasSuffix(".\($0)") }
}

/// Affiliate ids added on the device only when /api/affiliate/click could not be reached
func withFallbackAffiliateIDs(_ url: String, provider: String) -> String {
    let separator = url.contains("?") ? "&" : "?"
    switch provider {
    case "klook": return url.contains("aid=") ? url : "\(url)\(separator)aid=\(Config.klookAid)"
    case "trip": return url.contains("Allianceid=") ? url : "\(url)\(separator)Allianceid=\(Config.tripAllianceID)&SID=\(Config.tripSID)"
    default: return url
    }
}
