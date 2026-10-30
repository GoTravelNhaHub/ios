import SwiftUI

private struct Filters: Equatable {
    var q: String?
    var destination: String?
    var sort = "recent"
    var duration: String?
    var family = false

    var query: [String: String?] {
        ["q": q, "destination": destination, "sort": sort == "recent" ? nil : sort, "duration": duration, "family": family ? "1" : nil]
    }
}

struct CommunityView: View {
    @Environment(AppState.self) private var state
    @State private var filters = Filters()
    @State private var search = ""
    @State private var trips: [CommunityTripCard] = []
    @State private var saved: Set<String> = []
    @State private var cursor: String?
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("community_title")).font(.title2.bold())
                    Text(L("community_subtitle")).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ChoiceChip(label: L("community_sort_recent"), selected: filters.sort == "recent") { filters.sort = "recent" }
                        ChoiceChip(label: L("community_sort_trending"), selected: filters.sort == "trending") { filters.sort = "trending" }
                        ChoiceChip(label: L("community_sort_saved"), selected: filters.sort == "saved") { filters.sort = "saved" }
                        ChoiceChip(label: L("trip_family_friendly"), selected: filters.family) { filters.family.toggle() }
                        ForEach([("short", "community_duration_short"), ("medium", "community_duration_medium"), ("long", "community_duration_long")], id: \.0) { key, label in
                            ChoiceChip(label: L(label), selected: filters.duration == key) { filters.duration = filters.duration == key ? nil : key }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                ForEach(trips) { trip in
                    NavigationLink(value: Route.trip(slug: trip.slug)) {
                        TripCardView(trip: trip, saved: saved.contains(trip.id)) { toggleSave(trip) }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .onAppear { if trip.id == trips.last?.id, cursor != nil, !loading { Task { await loadPage(reset: false) } } }
                }

                if loading {
                    ProgressView().frame(maxWidth: .infinity).padding(32)
                } else if let error {
                    ErrorStateView(message: error) { Task { await loadPage(reset: trips.isEmpty) } }
                } else if trips.isEmpty {
                    EmptyStateView(title: L("community_empty_title"), text: L("community_empty_text"))
                }
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(L("tab_community"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: L("community_search_placeholder"))
        .onSubmit(of: .search) { filters.q = search.trimmingCharacters(in: .whitespaces).nilIfEmpty; filters.destination = nil }
        .onChange(of: search) { _, value in
            if value.isEmpty, filters.q != nil || filters.destination != nil { filters.q = nil; filters.destination = nil }
        }
        .appRoutes()
        .onAppear(perform: takeDestination)
        .onChange(of: state.communityDestination) { _, _ in takeDestination() }
        .task(id: filters) { await loadPage(reset: true) }
        .task(id: state.signedIn) { await refreshSaved(trips.map(\.id)) }
        .refreshable { await loadPage(reset: true) }
    }

    /// A destination tapped on Home narrows the list once
    private func takeDestination() {
        guard let destination = state.communityDestination else { return }
        state.communityDestination = nil
        search = destination
        filters = Filters(destination: destination)
    }

    private func loadPage(reset: Bool) async {
        loading = true
        error = nil
        do {
            let page = try await state.api.communityTrips(filters.query, cursor: reset ? nil : cursor)
            trips = reset ? page.data : trips + page.data
            cursor = page.nextCursor
            await refreshSaved(page.data.map(\.id))
        } catch is CancellationError {
            return
        } catch let failure as URLError where failure.code == .cancelled {
            return
        } catch {
            self.error = userMessage(error)
        }
        loading = false
    }

    private func refreshSaved(_ ids: [String]) async {
        guard state.signedIn else { saved = []; return }
        if let ids = try? await state.api.savedState(ids) { saved.formUnion(ids) }
    }

    private func toggleSave(_ trip: CommunityTripCard) {
        guard state.signedIn else { state.signIn(); return }
        let now = !saved.contains(trip.id)
        if now { saved.insert(trip.id) } else { saved.remove(trip.id) }
        Task {
            do { _ = try await state.api.setSaved(trip.slug, now) } catch { if now { saved.remove(trip.id) } else { saved.insert(trip.id) } }
        }
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
