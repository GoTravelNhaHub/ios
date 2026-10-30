import XCTest
@testable import GoTravelNha

// Same cases as backend/test/partner-link-resolver.test.ts and the Android BookingTest, so every
// client builds the keys the partner-links API answers with.
@MainActor
final class BookingTests: XCTestCase {
    func testKlookQueryKeepsTheBookablePlace() {
        XCTAssertEqual(klookQuery("Jacob Ballas Children's Garden at Singapore Botanic Gardens", destination: "Singapore"), "Singapore Botanic Gardens")
        XCTAssertEqual(klookQuery("Lunch at Lau Pa Sat", destination: "Singapore"), "Lau Pa Sat Singapore")
        XCTAssertEqual(klookQuery("Morning at Gardens by the Bay (Flower Dome)", destination: "Singapore"), "Gardens by the Bay Singapore")
    }

    private let days = [
        ItineraryDay(theme: "Gardens", items: [
            ItineraryItem(slot: "morning", title: "Jacob Ballas Children's Garden at Singapore Botanic Gardens"),
            ItineraryItem(slot: "afternoon", title: "Night Safari"),
            ItineraryItem(slot: "evening", title: "Dinner at the hotel"),
        ]),
    ]

    func testSuggestionsSkipMealsAndAddHotelsOnDayOne() {
        let result = daySuggestions(days, activities: [:], destination: "Singapore")
        XCTAssertEqual(result[0].activities.count, 2)
        XCTAssertTrue(result[0].hotels?.url.contains("city=73") == true)
    }

    func testMatchesReplaceDropOrKeepSearches() {
        let product = MatchedProduct(provider: "klook", url: "https://www.klook.com/activity/123-night-safari/", title: "Night Safari")
        let result = withMatchedProducts(daySuggestions(days, activities: [:], destination: "Singapore"), links: [
            "Singapore Botanic Gardens": StopMatch(product: nil, search: nil),
            "Night Safari Singapore": StopMatch(product: product, search: "Night Safari"),
        ])
        XCTAssertEqual(result[0].activities.count, 1)
        guard case let .search(_, _, link, _) = result[0].activities[0] else { return XCTFail("expected a search entry") }
        XCTAssertEqual(link, product)
    }

    func testPartnerURLs() {
        let link = MatchedProduct(provider: "klook", url: "https://www.klook.com/activity/123-x/", title: nil)
        XCTAssertEqual(localizedPartnerURL(link, klookLocalePath: "vi"), "https://www.klook.com/vi/activity/123-x/")
        XCTAssertTrue(isApprovedPartnerURL("https://www.trip.com/hotels/list?city=73"))
        XCTAssertFalse(isApprovedPartnerURL("http://www.trip.com/"))
        XCTAssertFalse(isApprovedPartnerURL("https://evil-klook.com/"))
        XCTAssertEqual(withFallbackAffiliateIDs("https://www.klook.com/a?x=1", provider: "klook"), "https://www.klook.com/a?x=1&aid=\(Config.klookAid)")
    }

    func testItineraryDecodingToleratesMissingFields() throws {
        let json = #"{"title":"T","days":[{"theme":"D","items":[{"title":"A"}]}]}"#
        let itinerary = try JSONDecoder().decode(Itinerary.self, from: Data(json.utf8))
        XCTAssertEqual(itinerary.days[0].items[0].slot, "morning")
        XCTAssertEqual(itinerary.tips, [])
    }
}
