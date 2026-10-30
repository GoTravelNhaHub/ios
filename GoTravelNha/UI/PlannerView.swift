import SwiftUI

struct PlannerView: View {
    @Environment(AppState.self) private var state
    @State private var chat = PlannerChat()
    @State private var editing = false
    @State private var confirmStartOver = false

    var body: some View {
        VStack(spacing: 0) {
            briefStrip
            if chat.result != nil {
                Picker("", selection: $chat.showingPlan) {
                    Text(L("chat_tab_chat")).tag(false)
                    Text(L("chat_tab_plan")).tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            if let result = chat.result, chat.showingPlan {
                planView(result)
            } else {
                conversation
            }
        }
        .navigationTitle(L("tab_planner"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if chat.started {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { confirmStartOver = true } label: { Image(systemName: "arrow.counterclockwise") }
                        .accessibilityLabel(L("planner_start_over"))
                        .disabled(chat.busy)
                }
            }
        }
        .confirmationDialog(L("planner_start_over"), isPresented: $confirmStartOver, titleVisibility: .visible) {
            Button(L("planner_start_over"), role: .destructive) { chat.startOver() }
        } message: {
            Text(L("chat_start_over_confirm"))
        }
        .sheet(isPresented: $editing) { PlannerDetailsView(chat: chat) }
        .appRoutes()
        .onAppear(perform: takeSeed)
        .onChange(of: state.plannerSeed) { _, _ in takeSeed() }
    }

    private func takeSeed() {
        guard let seed = state.plannerSeed else { return }
        state.plannerSeed = nil
        chat.apply(seed)
    }

    /// The trip so far. The agent fills it in; tapping any part opens the details sheet.
    private var briefStrip: some View {
        let brief = chat.brief
        var dates: String?
        if let start = brief.startDate, let end = brief.endDate { dates = dateRange(start, end) }
        let destination = brief.destination.nilIfEmpty
        let travellers = brief.party.isEmpty ? nil : L("travellers", brief.party.count)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ChoiceChip(label: destination ?? L("brief_add_destination"), selected: destination != nil) { editing = true }
                ChoiceChip(label: dates ?? L("brief_add_dates"), selected: dates != nil) { editing = true }
                ChoiceChip(label: travellers ?? L("brief_add_travellers"), selected: travellers != nil) { editing = true }
                ChoiceChip(label: brief.budget.map(budgetLabel) ?? L("brief_add_budget"), selected: brief.budget != nil) { editing = true }
                ChoiceChip(label: paceLabel(brief.pace), selected: false) { editing = true }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(chat.notes) { note in
                        bubble(note, showReplies: note.id == chat.notes.last?.id && !chat.busy)
                    }
                    if chat.busy { busyBubble }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: chat.notes.count) { _, _ in scrollToEnd(proxy) }
            .onChange(of: chat.busy) { _, _ in scrollToEnd(proxy) }
            .safeAreaInset(edge: .bottom) { composer }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
    }

    private func bubble(_ note: ChatNote, showReplies: Bool) -> some View {
        VStack(alignment: note.fromUser ? .trailing : .leading, spacing: 6) {
            if !note.text.isEmpty {
                Text(note.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(note.fromUser ? Brand.primary : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                    .foregroundStyle(note.fromUser ? Color.white : Color.primary)
                    .frame(maxWidth: 310, alignment: note.fromUser ? .trailing : .leading)
            }
            ForEach(note.changes, id: \.self) { change in
                Label(change, systemImage: "checkmark").font(.caption).foregroundStyle(.secondary)
            }
            if note.showsPlan {
                Button(L("chat_view_plan")) { chat.showingPlan = true }.buttonStyle(.bordered)
            }
            if showReplies && !note.replies.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(note.replies, id: \.self) { reply in
                            ChoiceChip(label: reply, selected: false) { chat.send(reply, state: state) }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: note.fromUser ? .trailing : .leading)
    }

    private var busyBubble: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(L(chat.generating ? "planner_working_hint" : "chat_thinking"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if chat.result == nil && chat.brief.missing.isEmpty && !chat.busy {
                Button { chat.plan(state: state) } label: { Text(L("planner_generate")).frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField(L("chat_placeholder"), text: $chat.draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22))
                Button { chat.send(chat.draft, state: state) } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 34))
                }
                .accessibilityLabel(L("chat_send"))
                .disabled(chat.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chat.busy)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func planView(_ result: PlannerResult) -> some View {
        let suggestions = daySuggestions(result.itinerary.days, activities: result.activities, destination: chat.brief.destination)
        return ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(result.itinerary.title).font(.title2.bold())
                Text(result.itinerary.summary)
                Text(L("planner_ai_note")).font(.caption).foregroundStyle(.secondary)
                if let error = chat.error { Text(error).foregroundStyle(.red) }
                if let savedTripId = chat.savedTripId {
                    NavigationLink(value: Route.myTrip(id: savedTripId)) { Text(L("planner_open_saved")).frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        if state.signedIn { chat.save(state: state) } else { state.signIn() }
                    } label: {
                        Text(L(state.signedIn ? "planner_save" : "planner_sign_in_to_save")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(chat.working || chat.busy)
                }
                Button { chat.showingPlan = false } label: { Text(L("chat_change_plan")).frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered)
            }
            .padding(16)
            ItineraryList(itinerary: result.itinerary, activities: result.activities, suggestions: suggestions) {
                state.book($0, screen: "planner", placement: "planner_day")
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }
}
