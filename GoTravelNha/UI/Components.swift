import SwiftUI

// Palette of the site's community design (web/tailwind.config.js, `cm` colours)
enum Brand {
    static let primary = Color(red: 0, green: 0x66 / 255, blue: 0xE4 / 255)
    static let active = Color(red: 6 / 255, green: 0x42 / 255, blue: 0xD2 / 255)
    static let heart = Color(red: 0xE0 / 255, green: 0x47 / 255, blue: 0x6A / 255)
    static let klook = Color(red: 1, green: 0x5B / 255, blue: 0)
    static let trip = Color(red: 0x28 / 255, green: 0x7D / 255, blue: 0xFA / 255)
    static let soft = Color.accentColor.opacity(0.12)

    private static let dayHex: [UInt32] = [0x0060FC, 0xFC6008, 0x0CA678, 0xC2255C, 0x7048E8, 0xE67700, 0x1098AD, 0x5C940D, 0xD6336C, 0x495057]
    static func day(_ day: Int) -> Color {
        let hex = dayHex[((day - 1) % dayHex.count + dayHex.count) % dayHex.count]
        return Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// Screens pushed inside each tab's NavigationStack
enum Route: Hashable {
    case trip(slug: String)
    case tripMap(slug: String, day: Int?)
    case myTrip(id: String)
}

extension View {
    func appRoutes() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .trip(let slug): TripDetailView(slug: slug)
            case .tripMap(let slug, let day): TripMapView(slug: slug, initialDay: day)
            case .myTrip(let id): MyTripDetailView(id: id)
            }
        }
    }
}

/// A screen's remote data
enum Load<T> {
    case loading
    case ready(T)
    case failed(String)

    var value: T? {
        if case .ready(let value) = self { return value }
        return nil
    }
}

/// Loads with `task`, shows a spinner, an error with retry, or the content.
struct LoadView<T, Content: View>: View {
    let load: Load<T>
    let retry: () -> Void
    @ViewBuilder let content: (T) -> Content

    var body: some View {
        switch load {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, minHeight: 200)
        case .failed(let message):
            ErrorStateView(message: message, retry: retry)
        case .ready(let value):
            content(value)
        }
    }
}

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button(L("action_retry"), action: retry).buttonStyle(.bordered)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

struct EmptyStateView<Action: View>: View {
    let title: String
    let text: String
    @ViewBuilder var action: () -> Action

    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(.headline).multilineTextAlignment(.center)
            Text(text).multilineTextAlignment(.center).foregroundStyle(.secondary)
            action().padding(.top, 8)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

extension EmptyStateView where Action == EmptyView {
    init(title: String, text: String) {
        self.init(title: title, text: text) { EmptyView() }
    }
}

struct SignInPrompt: View {
    @Environment(AppState.self) private var state
    let text: String

    var body: some View {
        EmptyStateView(title: L("signin_required_title"), text: text) {
            Button(L("action_sign_in")) { state.signIn() }.buttonStyle(.borderedProminent)
        }
    }
}

struct Pill: View {
    let text: String
    var background: Color = Color(.secondarySystemBackground)
    var foreground: Color = .primary

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(background, in: Capsule())
            .foregroundStyle(foreground)
    }
}

struct ChoiceChip: View {
    let label: String
    let selected: Bool
    var dot: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let dot { Circle().fill(dot).frame(width: 9, height: 9) }
                Text(label).font(.subheadline.weight(.semibold)).lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selected ? Color.primary : Color(.secondarySystemBackground), in: Capsule())
            .foregroundStyle(selected ? Color(.systemBackground) : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

struct Avatar: View {
    let name: String
    let url: String?
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Circle().fill(Brand.soft)
            if let url, let parsed = URL(string: url) {
                AsyncImage(url: parsed) { image in image.resizable().scaledToFill() } placeholder: { initial }
            } else {
                initial
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initial: some View {
        Text(String(name.prefix(1)).uppercased()).font(.system(size: size / 2.3, weight: .bold)).foregroundStyle(Brand.active)
    }
}

struct CoverImage: View {
    let url: String?

    var body: some View {
        ZStack {
            Brand.primary.opacity(0.85)
            if let url, let parsed = URL(string: url) {
                AsyncImage(url: parsed) { image in image.resizable().scaledToFill() } placeholder: { Color.clear }
            } else {
                Image(systemName: "mappin.and.ellipse").font(.largeTitle).foregroundStyle(.white.opacity(0.8))
            }
        }
        .clipped()
    }
}

func daysLabel(_ days: Int) -> String { L("days", days) }

struct TripCardView: View {
    let trip: CommunityTripCard
    var saved: Bool?
    var onToggleSave: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CoverImage(url: trip.coverImage)
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .topTrailing) {
                    if let saved, let onToggleSave {
                        Button(action: onToggleSave) {
                            Image(systemName: saved ? "heart.fill" : "heart")
                                .foregroundStyle(saved ? Brand.heart : .black)
                                .frame(width: 38, height: 38)
                                .background(.white.opacity(0.92), in: Circle())
                        }
                        .accessibilityLabel(L(saved ? "trip_unsave" : "trip_save"))
                        .padding(10)
                    }
                }
            VStack(alignment: .leading, spacing: 6) {
                Text(trip.title).font(.headline).lineLimit(2).foregroundStyle(.primary)
                Text(placeLine(trip.destination, trip.country) + " · " + daysLabel(trip.durationDays))
                    .font(.subheadline).foregroundStyle(.secondary)
                if !trip.highlights.isEmpty {
                    Text(trip.highlights.joined(separator: " · ")).font(.footnote).lineLimit(2).foregroundStyle(.primary)
                }
                HStack(spacing: 8) {
                    Avatar(name: trip.author.displayName, url: trip.author.avatarUrl, size: 22)
                    Text(trip.author.displayName).font(.subheadline.weight(.medium)).lineLimit(1).foregroundStyle(.primary)
                    Spacer(minLength: 4)
                    if trip.familyFriendly { Pill(text: L("trip_family_friendly"), background: Brand.soft, foreground: Brand.active) }
                    Text(L("saves", trip.saveCount)).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(14)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(.separator).opacity(0.5)))
    }
}

func placeLine(_ destination: String, _ country: String?) -> String {
    guard let country, !destination.contains(country) else { return destination }
    return "\(destination), \(country)"
}

func slotLabel(_ slot: String) -> String {
    switch slot {
    case "afternoon": return L("slot_afternoon")
    case "evening": return L("slot_evening")
    default: return L("slot_morning")
    }
}

func paceLabel(_ pace: String) -> String {
    switch pace {
    case "relaxed": return L("pace_relaxed")
    case "packed": return L("pace_packed")
    default: return L("pace_balanced")
    }
}

func budgetLabel(_ budget: String) -> String {
    switch budget {
    case "budget": return L("budget_budget")
    case "premium": return L("budget_premium")
    default: return L("budget_mid")
    }
}

/// "12 Jan 2027 – 15 Jan 2027" from API dates (yyyy-MM-dd or ISO timestamps)
func dateRange(_ start: String, _ end: String) -> String {
    let parser = DateFormatter()
    parser.dateFormat = "yyyy-MM-dd"
    parser.timeZone = TimeZone(identifier: "UTC")
    guard let from = parser.date(from: String(start.prefix(10))), let to = parser.date(from: String(end.prefix(10))) else { return "" }
    var format = Date.FormatStyle(date: .abbreviated, time: .omitted)
    format.timeZone = TimeZone(identifier: "UTC")!
    return "\(from.formatted(format)) – \(to.formatted(format))"
}
