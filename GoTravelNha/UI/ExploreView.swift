import SwiftUI

struct ExploreView: View {
    @Environment(AppState.self) private var state
    @State private var trending: Load<[CommunityTripCard]> = .loading
    @State private var destinations: [CommunityDestination] = []
    @State private var deals: [DealTemplate] = []
    @State private var openDeal: DealTemplate?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero.padding(16)

                if !destinations.isEmpty {
                    sectionTitle(L("explore_destinations"), nil)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(destinations) { destination in
                                Button {
                                    state.communityDestination = destination.destination
                                    state.tab = .community
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(destination.destination).font(.subheadline.weight(.semibold)).lineLimit(1)
                                        Text(L("trips_count", destination.count)).font(.caption).foregroundStyle(.secondary)
                                    }
                                    .frame(width: 140, alignment: .leading)
                                    .padding(14)
                                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator).opacity(0.5)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                sectionTitle(L("explore_trending"), L("explore_trending_subtitle"))
                LoadView(load: trending, retry: { Task { await loadTrending() } }) { trips in
                    LazyVStack(spacing: 12) {
                        ForEach(trips) { trip in
                            NavigationLink(value: Route.trip(slug: trip.slug)) { TripCardView(trip: trip) }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                if !deals.isEmpty {
                    sectionTitle(L("explore_deals"), L("explore_deals_subtitle"))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(deals) { deal in
                                Button { openDeal = deal } label: { DealCard(deal: deal) }.buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(L("app_name"))
        .navigationBarTitleDisplayMode(.inline)
        .appRoutes()
        .task {
            async let trips: Void = loadTrending()
            async let places = try? state.api.communityDestinations()
            async let offers = try? state.api.deals()
            destinations = await places ?? []
            deals = await offers ?? []
            _ = await trips
        }
        .refreshable { await loadTrending() }
        .sheet(item: $openDeal) { DealSheet(deal: $0) }
    }

    private func loadTrending() async {
        do {
            trending = .ready(try await state.api.communityTrips(["sort": "trending"], cursor: nil, limit: 6).data)
        } catch {
            if case .ready = trending { return }
            trending = .failed(userMessage(error))
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("app_name")).font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.85))
            Text(L("explore_hero_title")).font(.title2.bold()).foregroundStyle(.white)
            Text(L("explore_hero_text")).font(.subheadline).foregroundStyle(.white.opacity(0.9))
            Button { state.tab = .planner } label: {
                Text(L("explore_hero_cta")).font(.headline).padding(.horizontal, 18).padding(.vertical, 10)
                    .background(.white, in: Capsule()).foregroundStyle(Brand.active)
            }
            .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.primary, in: RoundedRectangle(cornerRadius: 22))
    }

    private func sectionTitle(_ title: String, _ subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title3.bold())
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 16)
        .padding(.top, 22)
        .padding(.bottom, 10)
    }
}

private struct DealCard: View {
    let deal: DealTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CoverImage(url: deal.heroImage.isEmpty ? nil : deal.heroImage)
                .frame(width: 260, height: 130)
                .overlay(alignment: .topLeading) {
                    if !deal.badge.isEmpty { Pill(text: deal.badge, background: .white, foreground: .black).padding(10) }
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(deal.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                Text(deal.destination).font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(width: 260, alignment: .leading)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(.separator).opacity(0.5)))
    }
}

private struct DealSheet: View {
    @Environment(AppState.self) private var state
    let deal: DealTemplate

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(deal.title).font(.title2.bold())
                if !deal.description.isEmpty { Text(deal.description) }
                ForEach(deal.summaryBullets, id: \.self) { Text("✓ \($0)").font(.subheadline) }
                if !deal.primaryBaseUrl.isEmpty {
                    Button {
                        state.openPartner(provider: deal.primaryProvider, url: deal.primaryBaseUrl, placement: placement, screen: "explore/\(deal.slug)")
                    } label: {
                        Text(deal.primaryCtaLabel.isEmpty ? L("booking_view") : deal.primaryCtaLabel).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(deal.primaryProvider == "trip" ? Brand.trip : Brand.klook)
                    .controlSize(.large)
                }
                ForEach(deal.comparison.filter { $0.baseUrl != deal.primaryBaseUrl }, id: \.baseUrl) { option in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(option.label).font(.subheadline.weight(.medium))
                            if !option.highlight.isEmpty { Text(option.highlight).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Button(L(option.provider == "trip" ? "booking_view_on_trip" : "booking_view_on_klook")) {
                            state.openPartner(provider: option.provider, url: option.baseUrl, placement: placement, screen: "explore/\(deal.slug)")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                if !deal.tips.isEmpty {
                    Text(L("trip_tips")).font(.headline).padding(.top, 6)
                    ForEach(deal.tips, id: \.self) { Text("• \($0)").font(.subheadline) }
                }
                Text(L("booking_note")).font(.caption).foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .presentationDetents([.medium, .large])
    }

    private var placement: String { deal.placementKey.isEmpty ? "app_deal" : deal.placementKey }
}
