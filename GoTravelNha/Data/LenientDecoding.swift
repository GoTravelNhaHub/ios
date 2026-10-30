import Foundation

// Synthesized Decodable ignores default values and fails on a missing key. Itineraries are stored
// JSON written over several versions of the planner, and some response fields are optional in
// practice, so these types fall back to their defaults instead of failing the whole screen.

extension KeyedDecodingContainer {
    func value<T: Decodable>(_ key: Key, default fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }
}

extension ItineraryItem {
    enum CodingKeys: String, CodingKey { case slot, activityId, title, description, familyTip }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        slot = c.value(.slot, default: "morning")
        activityId = c.value(.activityId, default: nil)
        title = c.value(.title, default: "")
        description = c.value(.description, default: "")
        familyTip = c.value(.familyTip, default: nil)
    }
}

extension ItineraryDay {
    enum CodingKeys: String, CodingKey { case date, theme, items }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = c.value(.date, default: nil)
        theme = c.value(.theme, default: "")
        items = c.value(.items, default: [])
    }
}

extension Itinerary {
    enum CodingKeys: String, CodingKey { case title, summary, days, tips }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = c.value(.title, default: "")
        summary = c.value(.summary, default: "")
        days = c.value(.days, default: [])
        tips = c.value(.tips, default: [])
    }
}

extension LiveActivity {
    enum CodingKeys: String, CodingKey { case id, title, image, available, priceFrom, currency, priceText, href, offerId, partnerUrl, provider, verified }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = c.value(.title, default: "")
        image = c.value(.image, default: nil)
        available = c.value(.available, default: false)
        priceFrom = c.value(.priceFrom, default: nil)
        currency = c.value(.currency, default: "SGD")
        priceText = c.value(.priceText, default: nil)
        href = c.value(.href, default: nil)
        offerId = c.value(.offerId, default: nil)
        partnerUrl = c.value(.partnerUrl, default: nil)
        provider = c.value(.provider, default: nil)
        verified = c.value(.verified, default: false)
    }
}

extension CommunityTripCard {
    enum CodingKeys: String, CodingKey { case id, slug, title, destination, country, durationDays, travelStyle, budgetLevel, familyFriendly, coverImage, highlights, description, saveCount, commentCount, author }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        slug = try c.decode(String.self, forKey: .slug)
        title = c.value(.title, default: "")
        destination = c.value(.destination, default: "")
        country = c.value(.country, default: nil)
        durationDays = c.value(.durationDays, default: 0)
        travelStyle = c.value(.travelStyle, default: nil)
        budgetLevel = c.value(.budgetLevel, default: nil)
        familyFriendly = c.value(.familyFriendly, default: false)
        coverImage = c.value(.coverImage, default: nil)
        highlights = c.value(.highlights, default: [])
        description = c.value(.description, default: nil)
        saveCount = c.value(.saveCount, default: 0)
        commentCount = c.value(.commentCount, default: 0)
        author = c.value(.author, default: CommunityAuthor())
    }
}

extension PublishedTripView {
    enum CodingKeys: String, CodingKey { case id, slug, visibility, title, description, destination, country, durationDays, travelStyle, budgetLevel, familyFriendly, itinerary, coverImage, saveCount, commentCount, author, authorStats }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        slug = try c.decode(String.self, forKey: .slug)
        visibility = c.value(.visibility, default: "PUBLIC")
        title = c.value(.title, default: "")
        description = c.value(.description, default: nil)
        destination = c.value(.destination, default: "")
        country = c.value(.country, default: nil)
        durationDays = c.value(.durationDays, default: 0)
        travelStyle = c.value(.travelStyle, default: nil)
        budgetLevel = c.value(.budgetLevel, default: nil)
        familyFriendly = c.value(.familyFriendly, default: false)
        itinerary = c.value(.itinerary, default: Itinerary())
        coverImage = c.value(.coverImage, default: nil)
        saveCount = c.value(.saveCount, default: 0)
        commentCount = c.value(.commentCount, default: 0)
        author = c.value(.author, default: CommunityAuthor())
        authorStats = c.value(.authorStats, default: AuthorStats())
    }
}

extension TripResponse {
    enum CodingKeys: String, CodingKey { case data, viewerIsAuthor, activities }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        data = try c.decode(PublishedTripView.self, forKey: .data)
        viewerIsAuthor = c.value(.viewerIsAuthor, default: false)
        activities = c.value(.activities, default: [:])
    }
}

extension SavedTrip {
    enum CodingKeys: String, CodingKey { case id, title, destination, startDate, endDate, party, itinerary, shareId, published }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = c.value(.title, default: "")
        destination = c.value(.destination, default: "")
        startDate = c.value(.startDate, default: "")
        endDate = c.value(.endDate, default: "")
        party = c.value(.party, default: [])
        itinerary = c.value(.itinerary, default: Itinerary())
        shareId = c.value(.shareId, default: nil)
        published = c.value(.published, default: nil)
    }
}

extension SavedTripResponse {
    enum CodingKeys: String, CodingKey { case data, activities }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        data = try c.decode(SavedTrip.self, forKey: .data)
        activities = c.value(.activities, default: [:])
    }
}

extension PlannerResult {
    enum CodingKeys: String, CodingKey { case generationId, itinerary, activities }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        generationId = try c.decode(String.self, forKey: .generationId)
        itinerary = try c.decode(Itinerary.self, forKey: .itinerary)
        activities = c.value(.activities, default: [:])
    }
}

extension DealTemplate {
    enum CodingKeys: String, CodingKey { case slug, title, description, destination, heroImage, badge, primaryProvider, primaryCtaLabel, primaryBaseUrl, placementKey, summaryBullets, tips, comparison }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        slug = try c.decode(String.self, forKey: .slug)
        title = c.value(.title, default: "")
        description = c.value(.description, default: "")
        destination = c.value(.destination, default: "")
        heroImage = c.value(.heroImage, default: "")
        badge = c.value(.badge, default: "")
        primaryProvider = c.value(.primaryProvider, default: "klook")
        primaryCtaLabel = c.value(.primaryCtaLabel, default: "")
        primaryBaseUrl = c.value(.primaryBaseUrl, default: "")
        placementKey = c.value(.placementKey, default: "")
        summaryBullets = c.value(.summaryBullets, default: [])
        tips = c.value(.tips, default: [])
        comparison = c.value(.comparison, default: [])
    }
}

extension DealComparisonOption {
    enum CodingKeys: String, CodingKey { case provider, label, highlight, baseUrl }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        provider = try c.decode(String.self, forKey: .provider)
        baseUrl = try c.decode(String.self, forKey: .baseUrl)
        label = c.value(.label, default: "")
        highlight = c.value(.highlight, default: "")
    }
}

extension TripMap {
    enum CodingKeys: String, CodingKey { case centre, days, unmapped }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        centre = c.value(.centre, default: nil)
        days = c.value(.days, default: [])
        unmapped = c.value(.unmapped, default: 0)
    }
}

extension AuthUser {
    enum CodingKeys: String, CodingKey { case id, username, email, firstName, lastName }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        username = c.value(.username, default: "")
        email = c.value(.email, default: "")
        firstName = c.value(.firstName, default: nil)
        lastName = c.value(.lastName, default: nil)
    }
}
