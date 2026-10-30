import SwiftUI

struct TripDetailView: View {
    @Environment(AppState.self) private var state
    let slug: String
    @State private var load: Load<TripResponse> = .loading
    @State private var links: [String: StopMatch] = [:]
    @State private var saved = false
    @State private var saveCount = 0
    @State private var comments: [Comment] = []

    var body: some View {
        ScrollView {
            LoadView(load: load, retry: { Task { await fetch() } }) { response in
                content(response)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(load.value?.data.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: Config.siteURL.appendingPathComponent("community/trips/\(slug)")) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(L("action_share"))
            }
        }
        .task(id: state.signedIn) { await fetch() }
    }

    private func fetch() async {
        do {
            let response = try await state.api.communityTrip(slug)
            load = .ready(response)
            saveCount = response.data.saveCount
            if state.signedIn { saved = (try? await state.api.savedState([response.data.id]))?.contains(response.data.id) ?? false }
            comments = (try? await state.api.comments(slug).data) ?? []
            if response.data.visibility != "PRIVATE" { await loadPartnerLinks() }
        } catch {
            if load.value == nil { load = .failed(userMessage(error)) }
        }
    }

    /// Partner product pages found by AI web search; the first visit may still be looking them up
    private func loadPartnerLinks() async {
        for attempt in 0..<2 {
            guard let result = try? await state.api.partnerLinks(slug) else { return }
            links.merge(result.data) { $1 }
            if !result.pending || attempt == 1 { return }
            try? await Task.sleep(for: .seconds(20))
        }
    }

    @ViewBuilder
    private func content(_ response: TripResponse) -> some View {
        let view = response.data
        let suggestions = withMatchedProducts(daySuggestions(view.itinerary.days, activities: response.activities, destination: view.destination), links: links)

        VStack(alignment: .leading, spacing: 0) {
            CoverImage(url: view.coverImage).aspectRatio(16 / 9, contentMode: .fit).frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 10) {
                Text(view.title).font(.title2.bold())
                Text(placeLine(view.destination, view.country) + " · " + daysLabel(view.durationDays)).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    if view.familyFriendly { Pill(text: L("trip_family_friendly"), background: Brand.soft, foreground: Brand.active) }
                    if let pace = view.travelStyle { Pill(text: paceLabel(pace)) }
                    if let budget = view.budgetLevel { Pill(text: budgetLabel(budget)) }
                }
                HStack(spacing: 10) {
                    Avatar(name: view.author.displayName, url: view.author.avatarUrl, size: 36)
                    VStack(alignment: .leading) {
                        Text(view.author.displayName).font(.subheadline.weight(.semibold))
                        Text(L("trips_count", view.authorStats.publicTrips)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let text = (view.description ?? view.itinerary.summary).nilIfEmpty { Text(text) }
                HStack(spacing: 8) {
                    Button(action: { toggleSave(view.slug) }) {
                        Label(L("saves", saveCount), systemImage: saved ? "heart.fill" : "heart")
                    }
                    .tint(saved ? Brand.heart : .primary)
                    .buttonStyle(.bordered)
                    NavigationLink(value: Route.tripMap(slug: slug, day: nil)) {
                        Label(L("trip_view_map"), systemImage: "map")
                    }
                    .buttonStyle(.bordered)
                }
                if !response.viewerIsAuthor {
                    Button {
                        state.plannerSeed = PlannerSeed(destination: view.destination, days: view.durationDays, adaptFromId: view.id, adaptTitle: view.title)
                        state.tab = .planner
                    } label: {
                        Text(L("trip_customize")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(16)

            ItineraryList(
                itinerary: view.itinerary,
                activities: response.activities,
                suggestions: view.visibility == "PRIVATE" ? nil : suggestions,
                onBook: { state.book($0, screen: "community/trips/\(slug)", placement: "community_trip_day") },
                mapRoute: { Route.tripMap(slug: slug, day: $0) }
            )

            if !comments.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("comments", view.commentCount)).font(.headline)
                    ForEach(comments) { comment in
                        HStack(alignment: .top, spacing: 10) {
                            Avatar(name: comment.author?.displayName ?? "?", url: comment.author?.avatarUrl, size: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(comment.author?.displayName ?? L("comment_deleted_author")).font(.subheadline.weight(.semibold))
                                    Pill(text: L(comment.kind == "QUESTION" ? "comment_question" : "comment_tip"))
                                }
                                Text(comment.body).font(.subheadline)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .padding(.bottom, 24)
    }

    private func toggleSave(_ slug: String) {
        guard state.signedIn else { state.signIn(); return }
        let target = !saved
        saved = target
        Task {
            do {
                let result = try await state.api.setSaved(slug, target)
                saved = result.saved
                saveCount = result.saveCount
            } catch {
                saved = !target
            }
        }
    }
}
