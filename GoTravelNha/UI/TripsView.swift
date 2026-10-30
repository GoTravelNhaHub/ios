import SwiftUI

struct TripsView: View {
    @Environment(AppState.self) private var state
    @State private var tab = 0
    @State private var mine: Load<[TripSummary]> = .loading
    @State private var saved: Load<[CommunityTripCard]> = .loading

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text(L("trips_mine")).tag(0)
                Text(L("trips_saved")).tag(1)
            }
            .pickerStyle(.segmented)
            .padding(16)

            if !state.signedIn {
                Spacer()
            } else if tab == 0 {
                LoadView(load: mine, retry: { Task { await loadMine() } }) { trips in
                    if trips.isEmpty {
                        EmptyStateView(title: L("trips_empty_title"), text: L("trips_empty_text")) {
                            Button(L("explore_hero_cta")) { state.tab = .planner }.buttonStyle(.borderedProminent)
                        }
                        Spacer()
                    } else {
                        List(trips) { trip in
                            NavigationLink(value: Route.myTrip(id: trip.id)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(trip.title).font(.headline)
                                    Text("\(trip.destination) · \(dateRange(trip.startDate, trip.endDate))").font(.subheadline).foregroundStyle(.secondary)
                                    Text(L("travellers", trip.party.count)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .refreshable { await loadMine() }
                    }
                }
            } else {
                LoadView(load: saved, retry: { Task { await loadSaved() } }) { trips in
                    if trips.isEmpty {
                        EmptyStateView(title: L("saved_empty_title"), text: L("saved_empty_text"))
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(trips) { trip in
                                    NavigationLink(value: Route.trip(slug: trip.slug)) { TripCardView(trip: trip) }.buttonStyle(.plain)
                                }
                            }
                            .padding(16)
                        }
                        .refreshable { await loadSaved() }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .navigationTitle(L("tab_trips"))
        .navigationBarTitleDisplayMode(.inline)
        .appRoutes()
        // Reload on every visit: plans saved in the planner and hearts tapped elsewhere show up here
        .onAppear(perform: refresh)
        .onChange(of: state.signedIn) { _, _ in refresh() }
    }

    private func refresh() {
        guard state.signedIn else { return }
        Task {
            async let a: Void = loadMine()
            async let b: Void = loadSaved()
            _ = await (a, b)
        }
    }

    private func loadMine() async {
        do { mine = .ready(try await state.api.myTrips()) } catch { if mine.value == nil { mine = .failed(userMessage(error)) } }
    }

    private func loadSaved() async {
        do { saved = .ready(try await state.api.saved(cursor: nil).data) } catch { if saved.value == nil { saved = .failed(userMessage(error)) } }
    }
}

struct MyTripDetailView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let id: String
    @State private var load: Load<SavedTripResponse> = .loading
    @State private var shareId: String?
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            LoadView(load: load, retry: { Task { await fetch() } }) { response in
                let trip = response.data
                VStack(alignment: .leading, spacing: 8) {
                    Text(trip.title).font(.title2.bold())
                    Text("\(trip.destination) · \(dateRange(trip.startDate, trip.endDate))").foregroundStyle(.secondary)
                    Text(L("travellers", trip.party.count)).font(.footnote)
                    if !trip.itinerary.summary.isEmpty { Text(trip.itinerary.summary) }
                    Toggle(isOn: Binding(get: { shareId != nil }, set: { enabled in
                        Task { if let result = try? await state.api.shareTrip(trip.id, enabled: enabled) { shareId = result } else if !enabled { shareId = nil } }
                    })) {
                        VStack(alignment: .leading) {
                            Text(L("mytrip_share")).font(.subheadline.weight(.semibold))
                            Text(L("mytrip_share_text")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let shareId {
                        ShareLink(item: Config.siteURL.appendingPathComponent("share/trip/\(shareId)")) { Text(L("mytrip_share_link")) }
                            .buttonStyle(.bordered)
                    }
                    if let published = trip.published, published.status == "ACTIVE" {
                        NavigationLink(value: Route.trip(slug: published.slug)) { Text(L("mytrip_view_published")) }.buttonStyle(.bordered)
                    }
                }
                .padding(16)
                ItineraryList(
                    itinerary: trip.itinerary,
                    activities: response.activities,
                    suggestions: daySuggestions(trip.itinerary.days, activities: response.activities, destination: trip.destination)
                ) { state.book($0, screen: "mytrip", placement: "mytrip_day") }
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(load.value?.data.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) { confirmDelete = true } label: { Image(systemName: "trash") }
                    .accessibilityLabel(L("mytrip_delete"))
            }
        }
        .confirmationDialog(L("mytrip_delete_title"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L("mytrip_delete"), role: .destructive) {
                Task {
                    if (try? await state.api.deleteTrip(id)) != nil { dismiss() }
                }
            }
        } message: {
            Text(L("mytrip_delete_text"))
        }
        .task { await fetch() }
    }

    private func fetch() async {
        do {
            let response = try await state.api.myTrip(id)
            shareId = response.data.shareId
            load = .ready(response)
        } catch {
            load = .failed(userMessage(error))
        }
    }
}
