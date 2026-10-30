import MapKit
import SwiftUI

/// Each stop pinned (places named by AI, coordinates from OpenStreetMap; api: /community/trips/:slug/map)
struct TripMapView: View {
    @Environment(AppState.self) private var state
    let slug: String
    let initialDay: Int?
    @State private var load: Load<TripMap> = .loading
    @State private var selectedDay: Int?
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        // The first request for a trip may take a while: places are geocoded one a second
        LoadView(load: load, retry: { Task { await fetch() } }) { map in
            if map.days.allSatisfy(\.stops.isEmpty) {
                EmptyStateView(title: L("trip_map_title"), text: L("trip_map_failed"))
            } else {
                mapContent(map)
            }
        }
        .navigationTitle(L("trip_map_title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await fetch() }
    }

    private func fetch() async {
        do {
            let map = try await state.api.tripMap(slug)
            if let initialDay, map.days.contains(where: { $0.day == initialDay }) { selectedDay = initialDay }
            load = .ready(map)
        } catch {
            load = .failed(userMessage(error))
        }
    }

    private func mapContent(_ map: TripMap) -> some View {
        let visible = map.days.filter { selectedDay == nil || $0.day == selectedDay }
        return VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ChoiceChip(label: L("trip_map_all_days"), selected: selectedDay == nil) { select(nil) }
                    ForEach(map.days) { day in
                        ChoiceChip(label: L("day_number", day.day), selected: selectedDay == day.day, dot: Brand.day(day.day)) { select(day.day) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            Map(position: $camera) {
                ForEach(visible) { day in
                    if day.stops.count > 1 {
                        MapPolyline(coordinates: day.stops.map(\.coordinate))
                            .stroke(Brand.day(day.day).opacity(0.7), style: StrokeStyle(lineWidth: 3, dash: [6, 8]))
                    }
                    ForEach(Array(day.stops.enumerated()), id: \.offset) { index, stop in
                        Annotation(stop.title, coordinate: stop.coordinate) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(Brand.day(day.day), in: Circle())
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .shadow(radius: 2)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)

            List {
                ForEach(visible) { day in
                    Section(L("day_title", day.day, day.theme)) {
                        if day.stops.isEmpty { Text(L("trip_map_no_stops")).foregroundStyle(.secondary) }
                        ForEach(Array(day.stops.enumerated()), id: \.offset) { index, stop in
                            Button {
                                withAnimation { camera = .region(MKCoordinateRegion(center: stop.coordinate, latitudinalMeters: 1200, longitudinalMeters: 1200)) }
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)").font(.caption.bold()).foregroundStyle(.white)
                                        .frame(width: 24, height: 24).background(Brand.day(day.day), in: Circle())
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(stop.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                        Text(slotLabel(stop.slot) + (stop.place != stop.title ? " · \(stop.place)" : ""))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                if map.unmapped > 0 {
                    Text(L("trip_map_unmapped", map.unmapped)).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .listStyle(.plain)
            .frame(maxHeight: .infinity)
        }
    }

    private func select(_ day: Int?) {
        selectedDay = day
        withAnimation { camera = .automatic }
    }
}

extension MapStop {
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }
}
