import SwiftUI

let maxTripDays = 14

struct PlannerView: View {
    @Environment(AppState.self) private var state
    @State private var destination = ""
    @State private var start = Calendar.current.date(byAdding: .day, value: 14, to: .now)!
    @State private var end = Calendar.current.date(byAdding: .day, value: 17, to: .now)!
    @State private var adults = 2
    @State private var childAges: [Int] = [6]
    @State private var newChildAge = 6
    @State private var pace = "balanced"
    @State private var budget = ""
    @State private var interests = ""
    @State private var adapt: PlannerSeed?

    @State private var working = false
    @State private var error: String?
    @State private var result: PlannerResult?
    @State private var savedTripId: String?
    @State private var change = ""

    private var days: Int {
        (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: start), to: Calendar.current.startOfDay(for: end)).day ?? 0) + 1
    }

    private var valid: Bool {
        destination.trimmingCharacters(in: .whitespaces).count >= 2 && (1...maxTripDays).contains(days)
    }

    var body: some View {
        Group {
            if let result { resultView(result) } else { form }
        }
        .navigationTitle(L("tab_planner"))
        .navigationBarTitleDisplayMode(.inline)
        .appRoutes()
        .onAppear(perform: takeSeed)
        .onChange(of: state.plannerSeed) { _, _ in takeSeed() }
    }

    private func takeSeed() {
        guard let seed = state.plannerSeed else { return }
        state.plannerSeed = nil
        destination = seed.destination
        if let days = seed.days { end = Calendar.current.date(byAdding: .day, value: min(max(days, 1), maxTripDays) - 1, to: start)! }
        adapt = seed.adaptFromId != nil ? seed : nil
        result = nil
        savedTripId = nil
        error = nil
    }

    private var form: some View {
        Form {
            Section {
                Text(L("planner_title")).font(.title3.bold())
                Text(L("planner_subtitle")).foregroundStyle(.secondary)
            }
            if let adapt {
                Section {
                    HStack {
                        Text(L("planner_adapting", adapt.adaptTitle ?? ""))
                        Spacer()
                        Button { self.adapt = nil } label: { Image(systemName: "xmark.circle.fill") }
                            .accessibilityLabel(L("action_clear"))
                    }
                }
            }
            Section(L("planner_destination")) {
                TextField(L("planner_destination"), text: $destination)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(searchCities.prefix(8), id: \.name) { city in
                            ChoiceChip(label: city.name, selected: destination == city.name) { destination = city.name }
                        }
                    }
                }
            }
            Section {
                DatePicker(L("planner_start"), selection: $start, in: Date.now..., displayedComponents: .date)
                    .onChange(of: start) { _, value in if end < value { end = value } }
                DatePicker(L("planner_end"), selection: $end, in: start..., displayedComponents: .date)
                if days > maxTripDays {
                    Text(L("planner_too_long", maxTripDays)).font(.footnote).foregroundStyle(.red)
                }
            }
            Section(L("planner_travellers")) {
                Stepper("\(L("planner_adults")): \(adults)", value: $adults, in: 1...max(1, 10 - childAges.count))
                ForEach(Array(childAges.enumerated()), id: \.offset) { index, age in
                    HStack {
                        Text(L("planner_child_age", age))
                        Spacer()
                        Button(role: .destructive) { childAges.remove(at: index) } label: { Image(systemName: "minus.circle") }
                    }
                }
                HStack {
                    Picker(L("planner_child_age_label"), selection: $newChildAge) {
                        ForEach(0...17, id: \.self) { Text("\($0)").tag($0) }
                    }
                    Button(L("planner_add_child")) { childAges.append(newChildAge) }
                        .disabled(adults + childAges.count >= 10)
                }
            }
            Section(L("planner_pace")) {
                Picker(L("planner_pace"), selection: $pace) {
                    Text(L("pace_relaxed")).tag("relaxed")
                    Text(L("pace_balanced")).tag("balanced")
                    Text(L("pace_packed")).tag("packed")
                }
                .pickerStyle(.segmented)
            }
            Section {
                TextField(L("planner_budget"), text: $budget).keyboardType(.decimalPad)
                TextField(L("planner_interests"), text: $interests, axis: .vertical).lineLimit(2...4)
            }
            if let error {
                Section { Text(error).foregroundStyle(.red) }
            }
            Section {
                Button(action: { generate() }) {
                    HStack {
                        if working { ProgressView().padding(.trailing, 6) }
                        Text(L(working ? "planner_working" : "planner_generate")).frame(maxWidth: .infinity)
                    }
                }
                .disabled(!valid || working)
                if working { Text(L("planner_working_hint")).font(.footnote).foregroundStyle(.secondary) }
            }
        }
    }

    private func resultView(_ result: PlannerResult) -> some View {
        let suggestions = daySuggestions(result.itinerary.days, activities: result.activities, destination: destination)
        return ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(result.itinerary.title).font(.title2.bold())
                Text(result.itinerary.summary)
                Text(L("planner_ai_note")).font(.caption).foregroundStyle(.secondary)
                if let error { Text(error).foregroundStyle(.red) }
                if let savedTripId {
                    NavigationLink(value: Route.myTrip(id: savedTripId)) { Text(L("planner_open_saved")).frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        if state.signedIn { save(result) } else { state.signIn() }
                    } label: {
                        Text(L(state.signedIn ? "planner_save" : "planner_sign_in_to_save")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(working)
                }
                TextField(L("planner_change_label"), text: $change, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .disabled(working)
                HStack {
                    Button(L(working ? "planner_working" : "planner_change")) {
                        generate(change: change.trimmingCharacters(in: .whitespaces))
                        change = ""
                    }
                    .buttonStyle(.bordered)
                    .disabled(change.trimmingCharacters(in: .whitespaces).count < 2 || working)
                    Button(L("planner_start_over")) { self.result = nil }.disabled(working)
                }
            }
            .padding(16)
            ItineraryList(itinerary: result.itinerary, activities: result.activities, suggestions: suggestions) {
                state.book($0, screen: "planner", placement: "planner_day")
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func isoDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func generate(change: String? = nil) {
        let previous = result
        working = true
        error = nil
        let revise = change.flatMap { text in previous.map { PlannerBody.Revise(generationId: $0.generationId, change: text) } }
        let body = PlannerBody(
            destination: destination.trimmingCharacters(in: .whitespaces),
            startDate: isoDate(start),
            endDate: isoDate(end),
            party: Array(repeating: PartyMember(age: 35), count: adults) + childAges.map { PartyMember(age: $0) },
            budget: Double(budget).flatMap { $0 > 0 ? $0 : nil },
            pace: pace,
            interests: interests.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            language: appLanguage(),
            revise: revise,
            adaptFrom: revise == nil ? adapt?.adaptFromId.map { PlannerBody.AdaptFrom(tripId: $0) } : nil
        )
        Task {
            do {
                result = try await state.api.plan(body)
                savedTripId = nil
            } catch {
                self.error = (error as? APIError)?.userMessage ?? L("planner_failed")
            }
            working = false
        }
    }

    private func save(_ result: PlannerResult) {
        working = true
        Task {
            do {
                savedTripId = try await state.api.saveGeneration(result.generationId)
            } catch {
                self.error = userMessage(error)
            }
            working = false
        }
    }
}
