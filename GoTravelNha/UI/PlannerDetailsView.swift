import SwiftUI

/// Every brief field by hand, for people who would rather tap than type.
struct PlannerDetailsView: View {
    @Bindable var chat: PlannerChat
    @Environment(\.dismiss) private var dismiss
    @State private var newChildAge = 6
    @State private var budget = ""

    private var parser: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private func dateBinding(_ keyPath: ReferenceWritableKeyPath<PlannerChat, PlannerBrief>, _ field: WritableKeyPath<PlannerBrief, String?>) -> Binding<Date> {
        Binding(
            get: { chat[keyPath: keyPath][keyPath: field].flatMap(parser.date) ?? .now },
            set: { chat[keyPath: keyPath][keyPath: field] = isoDate($0) }
        )
    }

    private var startDate: Binding<Date> {
        Binding(
            get: { dateBinding(\.brief, \.startDate).wrappedValue },
            set: { value in
                let previous = dateBinding(\.brief, \.endDate).wrappedValue
                chat.brief.startDate = isoDate(value)
                // Keep the trip inside the allowed length
                let latest = Calendar.current.date(byAdding: .day, value: maxTripDays - 1, to: value)!
                chat.brief.endDate = isoDate(min(max(previous, value), latest))
            }
        )
    }

    private var lastDay: Date {
        Calendar.current.date(byAdding: .day, value: maxTripDays - 1, to: startDate.wrappedValue)!
    }

    var body: some View {
        NavigationStack {
            Form {
                if let adapt = chat.adapt {
                    Section {
                        HStack {
                            Text(L("planner_adapting", adapt.adaptTitle ?? ""))
                            Spacer()
                            Button { chat.adapt = nil } label: { Image(systemName: "xmark.circle.fill") }
                                .accessibilityLabel(L("action_clear"))
                        }
                    }
                }
                Section(L("planner_destination")) {
                    TextField(L("planner_destination"), text: $chat.brief.destination)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(searchCities.prefix(8), id: \.name) { city in
                                ChoiceChip(label: city.name, selected: chat.brief.destination == city.name) { chat.brief.destination = city.name }
                            }
                        }
                    }
                }
                Section {
                    if chat.brief.startDate != nil && chat.brief.endDate != nil {
                        DatePicker(L("planner_start"), selection: startDate, in: Calendar.current.startOfDay(for: .now)..., displayedComponents: .date)
                        DatePicker(L("planner_end"), selection: dateBinding(\.brief, \.endDate), in: startDate.wrappedValue...lastDay, displayedComponents: .date)
                        Text(L("planner_too_long", maxTripDays)).font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Button(L("brief_add_dates")) {
                            let start = Calendar.current.date(byAdding: .day, value: 14, to: .now)!
                            chat.brief.startDate = chat.brief.startDate ?? isoDate(start)
                            chat.brief.endDate = isoDate(Calendar.current.date(byAdding: .day, value: 3, to: parser.date(from: chat.brief.startDate!) ?? start)!)
                        }
                    }
                }
                Section(L("planner_travellers")) {
                    Stepper(
                        "\(L("planner_adults")): \(chat.brief.adults)",
                        value: Binding(get: { chat.brief.adults }, set: { chat.brief = chat.brief.withAdults($0) }),
                        in: 0...max(chat.brief.adults, 10 - chat.brief.children.count)
                    )
                    ForEach(Array(chat.brief.children.enumerated()), id: \.offset) { index, child in
                        HStack {
                            Text(L("planner_child_age", child.age))
                            Spacer()
                            Button(role: .destructive) { chat.brief = chat.brief.withoutChild(at: index) } label: { Image(systemName: "minus.circle") }
                        }
                    }
                    HStack {
                        Picker(L("planner_child_age_label"), selection: $newChildAge) {
                            ForEach(0...17, id: \.self) { Text("\($0)").tag($0) }
                        }
                        Button(L("planner_add_child")) { chat.brief = chat.brief.withChild(age: newChildAge) }
                            .disabled(chat.brief.party.count >= 10)
                    }
                }
                Section(L("planner_pace")) {
                    Picker(L("planner_pace"), selection: $chat.brief.pace) {
                        Text(L("pace_relaxed")).tag("relaxed")
                        Text(L("pace_balanced")).tag("balanced")
                        Text(L("pace_packed")).tag("packed")
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    TextField(L("planner_budget"), text: $budget)
                        .keyboardType(.numberPad)
                        .onChange(of: budget) { _, value in chat.brief.budget = Double(value).flatMap { $0 > 0 ? $0 : nil } }
                    TextField(L("planner_interests"), text: $chat.brief.interests, axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle(L("chat_edit_details"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L("action_ok")) { dismiss() } }
            }
            .onAppear { budget = chat.brief.budget.map { String(Int($0)) } ?? "" }
        }
    }
}
