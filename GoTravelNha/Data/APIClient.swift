import Foundation

/// An API error: `message` is the backend's user-facing text when it sent one.
struct APIError: LocalizedError {
    let status: Int
    let message: String?
    var errorDescription: String? { message }

    /// Text worth showing as-is; network failures and server crashes get the generic message
    var userMessage: String? { status < 500 || status == 502 || status == 503 ? message : nil }
}

func userMessage(_ error: Error) -> String {
    (error as? APIError)?.userMessage ?? L("error_generic")
}

/// api.gotravelnha.com client. Paths are the same `/api/...` the website calls. Signed-in requests
/// carry the Keycloak access token; a 401 refreshes it once and retries.
final class APIClient {
    private let auth: AuthManager
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(auth: AuthManager) {
        self.auth = auth
        let configuration = URLSessionConfiguration.default
        // The AI planner answers in up to two minutes
        configuration.timeoutIntervalForRequest = 150
        session = URLSession(configuration: configuration)
    }

    private struct Envelope<T: Decodable>: Decodable { let data: T }
    private struct Empty: Encodable {}
    private struct ErrorBody: Decodable { let message: String? }

    func get<T: Decodable>(_ path: String, query: [String: String?] = [:]) async throws -> T {
        try await request("GET", path, query: query, body: Optional<Empty>.none)
    }

    func data<T: Decodable>(_ path: String, query: [String: String?] = [:]) async throws -> T {
        let envelope: Envelope<T> = try await get(path, query: query)
        return envelope.data
    }

    func send<B: Encodable, T: Decodable>(_ method: String, _ path: String, body: B?) async throws -> T {
        try await request(method, path, query: [:], body: body)
    }

    func sendData<B: Encodable, T: Decodable>(_ method: String, _ path: String, body: B?) async throws -> T {
        let envelope: Envelope<T> = try await send(method, path, body: body)
        return envelope.data
    }

    private func request<B: Encodable, T: Decodable>(_ method: String, _ path: String, query: [String: String?], body: B?) async throws -> T {
        var components = URLComponents(url: Config.apiBaseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        let items = query.compactMap { key, value in value.flatMap { $0.isEmpty ? nil : URLQueryItem(name: key, value: $0) } }
        if !items.isEmpty { components.queryItems = items }

        func attempt(forceRefresh: Bool) async throws -> (Data, HTTPURLResponse) {
            var request = URLRequest(url: components.url!)
            request.httpMethod = method
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("GoTravelNha-iOS/\(Config.appVersion)", forHTTPHeaderField: "User-Agent")
            if let token = await auth.accessToken(forceRefresh: forceRefresh) {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            if let body {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try encoder.encode(body)
            } else if method != "GET" && method != "DELETE" {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = Data("{}".utf8)
            }
            let (data, response) = try await session.data(for: request)
            return (data, response as! HTTPURLResponse)
        }

        var (data, response) = try await attempt(forceRefresh: false)
        if response.statusCode == 401, auth.signedIn {
            (data, response) = try await attempt(forceRefresh: true)
        }
        guard (200..<300).contains(response.statusCode) else {
            throw APIError(status: response.statusCode, message: (try? decoder.decode(ErrorBody.self, from: data))?.message)
        }
        return try decoder.decode(T.self, from: data.isEmpty ? Data("{}".utf8) : data)
    }
}

/// Every endpoint the app uses.
final class GoTravelNhaAPI {
    let client: APIClient
    init(client: APIClient) { self.client = client }

    private struct UserEnvelope: Decodable { let user: AuthUser }
    private struct Ok: Decodable {}
    private struct ShareBody: Encodable { let enabled: Bool }
    private struct ShareResponse: Decodable { let shareId: String? }
    private struct SaveTripBody: Encodable { let generationId: String }
    private struct IdRef: Decodable { let id: String }
    private struct ClickResponse: Decodable { let outboundUrl: String? }

    struct ClickBody: Encodable {
        var provider: String?
        var baseUrl: String?
        var offerId: String?
        var placementKey: String
        var pagePath: String
        var sessionId: String
        var metadata: [String: String]
    }

    func me() async throws -> AuthUser {
        let envelope: UserEnvelope = try await client.get("/api/auth/me")
        return envelope.user
    }

    func communityTrips(_ filters: [String: String?], cursor: String?, limit: Int = 12) async throws -> TripPage {
        try await client.get("/api/community/trips", query: filters.merging(["cursor": cursor, "limit": String(limit)]) { $1 })
    }

    func communityDestinations() async throws -> [CommunityDestination] { try await client.data("/api/community/destinations") }
    func communityTrip(_ slug: String) async throws -> TripResponse { try await client.get("/api/community/trips/\(slug)") }
    func partnerLinks(_ slug: String) async throws -> PartnerLinksResponse { try await client.get("/api/community/trips/\(slug)/partner-links") }
    func tripMap(_ slug: String) async throws -> TripMap { try await client.data("/api/community/trips/\(slug)/map") }
    func comments(_ slug: String) async throws -> CommentPage { try await client.get("/api/community/trips/\(slug)/comments") }

    func setSaved(_ slug: String, _ saved: Bool) async throws -> SaveState {
        try await client.sendData(saved ? "PUT" : "DELETE", "/api/community/trips/\(slug)/save", body: Optional<ShareBody>.none)
    }

    /// Which of these community trip ids the user saved (empty when signed out)
    func savedState(_ tripIds: [String]) async throws -> Set<String> {
        guard !tripIds.isEmpty else { return [] }
        let ids: [String] = try await client.data("/api/community/saved/state", query: ["ids": tripIds.joined(separator: ",")])
        return Set(ids)
    }

    func saved(cursor: String?) async throws -> TripPage { try await client.get("/api/community/saved", query: ["cursor": cursor]) }
    func deals() async throws -> [DealTemplate] { try await client.data("/api/deal-templates") }
    func myTrips() async throws -> [TripSummary] { try await client.data("/api/trips") }
    func myTrip(_ id: String) async throws -> SavedTripResponse { try await client.get("/api/trips/\(id)") }

    func deleteTrip(_ id: String) async throws {
        let _: Ok = try await client.send("DELETE", "/api/trips/\(id)", body: Optional<ShareBody>.none)
    }

    func shareTrip(_ id: String, enabled: Bool) async throws -> String? {
        let response: ShareResponse = try await client.send("POST", "/api/trips/\(id)/share", body: ShareBody(enabled: enabled))
        return response.shareId
    }

    func plan(_ body: PlannerBody) async throws -> PlannerResult { try await client.send("POST", "/api/planner/itinerary", body: body) }

    func saveGeneration(_ generationId: String) async throws -> String {
        let ref: IdRef = try await client.sendData("POST", "/api/trips", body: SaveTripBody(generationId: generationId))
        return ref.id
    }

    func click(_ body: ClickBody) async throws -> String? {
        let response: ClickResponse = try await client.send("POST", "/api/affiliate/click", body: body)
        return response.outboundUrl
    }
}
