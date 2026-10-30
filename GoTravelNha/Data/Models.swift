import Foundation

// Shapes of the api.gotravelnha.com responses the app reads (see ../../backend and web/types).
// Decoding ignores unknown fields; optional fields default when missing.

struct ItineraryItem: Codable, Hashable {
    var slot: String = "morning"
    var activityId: String?
    var title: String = ""
    var description: String = ""
    var familyTip: String?
}

struct ItineraryDay: Codable, Hashable {
    var date: String?
    var theme: String = ""
    var items: [ItineraryItem] = []
}

struct Itinerary: Codable, Hashable {
    var title: String = ""
    var summary: String = ""
    var days: [ItineraryDay] = []
    var tips: [String] = []
}

/// Live supplier data for a catalogue id. Prices never come from the model.
struct LiveActivity: Codable, Hashable {
    var id: String
    var title: String = ""
    var image: String?
    var available: Bool = false
    var priceFrom: Double?
    var currency: String = "SGD"
    var priceText: String?
    var href: String?
    var offerId: String?
    var partnerUrl: String?
    var provider: String?
    var verified: Bool = false

    var priceLabel: String? {
        if let priceText { return priceText }
        guard let priceFrom else { return nil }
        return priceFrom.rounded() == priceFrom ? "\(currency) \(Int(priceFrom))" : String(format: "%@ %.2f", currency, priceFrom)
    }
}

struct CommunityAuthor: Codable, Hashable {
    var handle: String = ""
    var displayName: String = ""
    var avatarUrl: String?
}

struct CommunityTripCard: Codable, Hashable, Identifiable {
    var id: String
    var slug: String
    var title: String
    var destination: String
    var country: String?
    var durationDays: Int = 0
    var travelStyle: String?
    var budgetLevel: String?
    var familyFriendly: Bool = false
    var coverImage: String?
    var highlights: [String] = []
    var description: String?
    var saveCount: Int = 0
    var commentCount: Int = 0
    var author: CommunityAuthor = CommunityAuthor()
}

struct TripPage: Codable {
    var data: [CommunityTripCard] = []
    var nextCursor: String?
}

struct CommunityDestination: Codable, Hashable, Identifiable {
    var destination: String
    var country: String?
    var count: Int = 0
    var id: String { destination }
}

struct AuthorStats: Codable, Hashable {
    var publicTrips: Int = 0
    var followers: Int = 0
}

struct PublishedTripView: Codable, Hashable {
    var id: String
    var slug: String
    var visibility: String = "PUBLIC"
    var title: String
    var description: String?
    var destination: String
    var country: String?
    var durationDays: Int = 0
    var travelStyle: String?
    var budgetLevel: String?
    var familyFriendly: Bool = false
    var itinerary: Itinerary = Itinerary()
    var coverImage: String?
    var saveCount: Int = 0
    var commentCount: Int = 0
    var author: CommunityAuthor = CommunityAuthor()
    var authorStats: AuthorStats = AuthorStats()
}

struct TripResponse: Codable {
    var data: PublishedTripView
    var viewerIsAuthor: Bool = false
    var activities: [String: LiveActivity] = [:]
}

struct SaveState: Codable {
    var saved: Bool
    var saveCount: Int
}

struct MatchedProduct: Codable, Hashable {
    var provider: String
    var url: String
    var title: String?
}

/// What AI web search found for a stop's Klook search query
struct StopMatch: Codable, Hashable {
    var product: MatchedProduct?
    var search: String?
}

struct PartnerLinksResponse: Codable {
    var data: [String: StopMatch] = [:]
    var pending: Bool = false
}

struct MapStop: Codable, Hashable {
    var slot: String
    var title: String
    var place: String
    var lat: Double
    var lon: Double
}

struct MapDay: Codable, Hashable, Identifiable {
    var day: Int
    var theme: String = ""
    var stops: [MapStop] = []
    var id: Int { day }
}

struct LatLon: Codable, Hashable {
    var lat: Double
    var lon: Double
}

struct TripMap: Codable {
    var centre: LatLon?
    var days: [MapDay] = []
    var unmapped: Int = 0
}

struct CommentAuthor: Codable, Hashable {
    var handle: String
    var displayName: String
    var avatarUrl: String?
}

struct Comment: Codable, Hashable, Identifiable {
    var id: String
    var body: String
    var kind: String = "TIP"
    var createdAt: String
    var author: CommentAuthor?
}

struct CommentPage: Codable {
    var data: [Comment] = []
    var nextCursor: String?
}

struct DealComparisonOption: Codable, Hashable {
    var provider: String
    var label: String = ""
    var highlight: String = ""
    var baseUrl: String
}

struct DealTemplate: Codable, Hashable, Identifiable {
    var slug: String
    var title: String
    var description: String = ""
    var destination: String = ""
    var heroImage: String = ""
    var badge: String = ""
    var primaryProvider: String = "klook"
    var primaryCtaLabel: String = ""
    var primaryBaseUrl: String = ""
    var placementKey: String = ""
    var summaryBullets: [String] = []
    var tips: [String] = []
    var comparison: [DealComparisonOption] = []
    var id: String { slug }
}

struct PartyMember: Codable, Hashable {
    var name: String?
    var age: Int
}

struct TripSummary: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var destination: String
    var startDate: String
    var endDate: String
    var party: [PartyMember] = []
}

struct PublishedRef: Codable, Hashable {
    var id: String
    var slug: String
    var visibility: String
    var status: String
}

struct SavedTrip: Codable, Hashable {
    var id: String
    var title: String
    var destination: String
    var startDate: String
    var endDate: String
    var party: [PartyMember] = []
    var itinerary: Itinerary = Itinerary()
    var shareId: String?
    var published: PublishedRef?
}

struct SavedTripResponse: Codable {
    var data: SavedTrip
    var activities: [String: LiveActivity] = [:]
}

struct PlannerBody: Encodable {
    struct Revise: Encodable { var generationId: String; var change: String }
    struct AdaptFrom: Encodable { var tripId: String }
    var destination: String
    var startDate: String
    var endDate: String
    var party: [PartyMember]
    var budget: Double?
    var currency = "SGD"
    var pace: String
    var interests: String?
    var language: String
    var revise: Revise?
    var adaptFrom: AdaptFrom?
}

struct PlannerResult: Codable, Hashable {
    var generationId: String
    var itinerary: Itinerary
    var activities: [String: LiveActivity] = [:]
}

struct ChatBody: Encodable {
    struct Message: Encodable { var role: String; var text: String }
    struct Traveller: Encodable { var age: Int }
    struct Brief: Encodable {
        var destination: String?
        var startDate: String?
        var endDate: String?
        var travellers: [Traveller]
        var budget: Double?
        var pace: String
        var interests: String?
    }
    struct Plan: Encodable { var title: String; var days: [String] }
    var messages: [Message]
    var brief: Brief
    var language: String
    var plan: Plan?
}

struct AgentUpdates: Decodable {
    struct Traveller: Decodable { var age: Int; var label: String? }
    var destination: String?
    var startDate: String?
    var endDate: String?
    var travellers: [Traveller]?
    var budget: Double?
    var pace: String?
    var interests: String?
}

struct AgentTurn: Decodable {
    var reply: String
    var updates: AgentUpdates
    var action: String
    var change: String?
    var quickReplies: [String]?
}

struct AuthUser: Codable, Hashable {
    var id: String
    var username: String = ""
    var email: String = ""
    var firstName: String?
    var lastName: String?

    var displayName: String {
        let name = [firstName, lastName].compactMap { $0 }.joined(separator: " ")
        return name.isEmpty ? (username.isEmpty ? email : username) : name
    }
}
