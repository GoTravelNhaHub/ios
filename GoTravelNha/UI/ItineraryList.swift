import SwiftUI

/// Day-by-day plan with booking suggestions under each day (nil: no booking buttons).
struct ItineraryList: View {
    let itinerary: Itinerary
    let activities: [String: LiveActivity]
    let suggestions: [DaySuggestions]?
    let onBook: (BookingAction) -> Void
    var mapRoute: ((Int) -> Route)?

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(itinerary.days.enumerated()), id: \.offset) { index, day in
                DayCard(
                    number: index + 1,
                    day: day,
                    activities: activities,
                    suggestions: suggestions?.indices.contains(index) == true ? suggestions?[index] : nil,
                    onBook: onBook,
                    mapRoute: mapRoute?(index + 1)
                )
            }
            if !itinerary.tips.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("trip_tips")).font(.headline)
                    ForEach(itinerary.tips, id: \.self) { Text("• \($0)").font(.subheadline) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
    }
}

private struct DayCard: View {
    let number: Int
    let day: ItineraryDay
    let activities: [String: LiveActivity]
    let suggestions: DaySuggestions?
    let onBook: (BookingAction) -> Void
    let mapRoute: Route?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("\(number)").font(.subheadline.bold()).foregroundStyle(.white)
                    .frame(width: 30, height: 30).background(Brand.day(number), in: Circle())
                VStack(alignment: .leading, spacing: 0) {
                    Text(L("day_number", number)).font(.caption).foregroundStyle(.secondary)
                    Text(day.theme).font(.headline)
                }
                Spacer()
                if let mapRoute {
                    NavigationLink(value: mapRoute) { Text(L("trip_map_short")) }.buttonStyle(.bordered)
                }
            }
            ForEach(Array(day.items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 3) {
                    Text(slotLabel(item.slot).uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(Brand.primary)
                    Text(item.title).font(.body.weight(.semibold))
                    if !item.description.isEmpty { Text(item.description).font(.subheadline) }
                    if let tip = item.familyTip, !tip.isEmpty {
                        Text(L("trip_family_tip", tip)).font(.footnote).foregroundStyle(.secondary)
                    }
                    if let id = item.activityId, let activity = activities[id], !activity.verified {
                        Text(L("trip_not_listed")).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let suggestions, !(suggestions.activities.isEmpty && suggestions.hotels == nil) {
                DayBooking(day: suggestions, onBook: onBook)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(.separator).opacity(0.5)))
    }
}

private struct DayBooking: View {
    let day: DaySuggestions
    let onBook: (BookingAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("booking_title")).font(.subheadline.weight(.semibold))
            if let hotels = day.hotels {
                row(title: L("booking_hotels", hotels.city), hint: nil, button: L("booking_view_on_trip"), trip: true) { onBook(.hotels(hotels)) }
            }
            ForEach(Array(day.activities.enumerated()), id: \.offset) { _, entry in
                switch entry {
                case .offer(let activity):
                    row(title: activity.title, hint: activity.priceLabel.map { L("booking_from_price", $0) }, button: L("booking_view"), trip: activity.provider == "trip") {
                        onBook(.offer(activity))
                    }
                case .search(let query, let label, let link, let search):
                    row(
                        title: link?.title ?? label,
                        hint: link != nil ? L("booking_matched_hint") : nil,
                        button: link?.provider == "trip" ? L("booking_view_on_trip") : link != nil ? L("booking_view_on_klook") : L("booking_search_klook"),
                        trip: link?.provider == "trip"
                    ) { onBook(.search(query: query, link: link, search: search)) }
                }
            }
            Text(L("booking_note")).font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func row(title: String, hint: String?, button: String, trip: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium)).lineLimit(2)
                if let hint { Text(hint).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 4)
            Button(button, action: action)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(trip ? Brand.trip : Brand.klook)
        }
    }
}
