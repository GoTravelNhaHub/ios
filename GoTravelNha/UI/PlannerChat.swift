import Foundation
import Observation

let maxTripDays = 10

/// A chat bubble. Local notes come from the app, so they are not sent to the agent.
struct ChatNote: Identifiable {
    let id: Int
    let fromUser: Bool
    let text: String
    var local = false
    var changes: [String] = []
    var replies: [String] = []
    var showsPlan = false
}

func budgetLabel(_ value: Double) -> String {
    "S$\(Int(value).formatted())"
}

func isoDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

/// The conversation with the trip agent: the agent updates the brief and picks the next step.
@MainActor
@Observable
final class PlannerChat {
    /// Limits of /api/planner/chat
    private static let maxMessages = 40
    private static let maxMessageLength = 800

    var brief = PlannerBrief()
    var adapt: PlannerSeed?
    var notes: [ChatNote] = []
    var draft = ""
    var showingPlan = false

    private(set) var thinking = false
    private(set) var generating = false
    private(set) var working = false
    var error: String?
    private(set) var result: PlannerResult?
    private(set) var savedTripId: String?

    @ObservationIgnored private var nextNoteId = 0

    var busy: Bool { thinking || generating }
    var started: Bool { notes.contains(where: \.fromUser) || result != nil || brief != PlannerBrief() }

    init() { welcome() }

    private func welcome() {
        addNote(fromUser: false, text: L("chat_welcome"), local: true, replies: [L("chat_welcome_reply_1"), L("chat_welcome_reply_2")])
    }

    private func addNote(fromUser: Bool, text: String, local: Bool = false, changes: [String] = [], replies: [String] = [], showsPlan: Bool = false) {
        notes.append(ChatNote(id: nextNoteId, fromUser: fromUser, text: text, local: local, changes: changes, replies: replies, showsPlan: showsPlan))
        nextNoteId += 1
    }

    func startOver() {
        brief = PlannerBrief()
        adapt = nil
        result = nil
        savedTripId = nil
        error = nil
        draft = ""
        showingPlan = false
        notes = []
        welcome()
    }

    func apply(_ seed: PlannerSeed) {
        startOver()
        notes = []
        brief.destination = seed.destination
        if let days = seed.days {
            let start = Calendar.current.date(byAdding: .day, value: 14, to: .now)!
            brief.startDate = isoDate(start)
            brief.endDate = isoDate(Calendar.current.date(byAdding: .day, value: min(max(days, 1), maxTripDays) - 1, to: start)!)
        }
        adapt = seed.adaptFromId != nil ? seed : nil
        addNote(fromUser: false, text: adapt.map { L("chat_adapt_ready", $0.adaptTitle ?? "") } ?? L("chat_destination_ready", seed.destination), local: true)
    }

    /// One message from the family.
    func send(_ message: String, state: AppState) {
        let spoken = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !busy, !spoken.isEmpty else { return }
        draft = ""
        addNote(fromUser: true, text: spoken)
        let sentId = notes[notes.count - 1].id
        thinking = true
        Task {
            do {
                let turn = try await state.api.plannerChat(chatBody())
                thinking = false
                handle(turn, spoken: spoken, state: state)
            } catch {
                thinking = false
                // Give the message back so nothing is typed twice
                notes.removeAll { $0.id == sentId }
                draft = spoken
                addNote(fromUser: false, text: failureText(error, fallback: "chat_failed"), local: true)
            }
        }
    }

    private func chatBody() -> ChatBody {
        let history = notes.filter { !$0.local && !$0.text.isEmpty }.suffix(Self.maxMessages)
        return ChatBody(
            messages: history.map { ChatBody.Message(role: $0.fromUser ? "user" : "assistant", text: String($0.text.prefix(Self.maxMessageLength))) },
            brief: brief.agentBrief,
            language: appLanguage(),
            plan: result.map { ChatBody.Plan(title: String($0.itinerary.title.prefix(200)), days: $0.itinerary.days.map { String($0.theme.prefix(200)) }) }
        )
    }

    private func handle(_ turn: AgentTurn, spoken: String, state: AppState) {
        let destinationChanged = turn.updates.destination.map { $0 != brief.destination } ?? false
        let applied = brief.applying(turn.updates)
        brief = applied.brief
        addNote(fromUser: false, text: turn.reply, changes: applied.changes.map(describe), replies: turn.quickReplies ?? [])
        switch turn.action {
        case "plan":
            plan(state: state)
        case "revise":
            // A new city is a new trip, not an edit of the old one
            if destinationChanged { plan(state: state) } else { generate(change: turn.change ?? spoken, state: state) }
        default:
            break
        }
    }

    private func describe(_ change: BriefChange) -> String {
        switch change {
        case .destination(let value): L("chat_update_destination", value)
        case .dates(let start, let end): L("chat_update_dates", dateRange(start, end))
        case .travellers(let ages): L("chat_update_travellers", ages.count, ages.map(String.init).joined(separator: ", "))
        case .budget(let value): L("chat_update_budget", budgetLabel(value))
        case .pace(let value): L("chat_update_pace", paceLabel(value))
        case .interests(let value): L("chat_update_interests", value)
        }
    }

    /// Builds the plan, or asks for what is still missing.
    func plan(state: AppState) {
        guard !busy else { return }
        switch brief.missing.first {
        case .destination: addNote(fromUser: false, text: L("chat_ask_city"), local: true)
        case .dates: addNote(fromUser: false, text: L("chat_ask_dates"), local: true)
        case .ages: addNote(fromUser: false, text: L("chat_ask_ages"), local: true)
        case nil: generate(change: nil, state: state)
        }
    }

    private func generate(change: String?, state: AppState) {
        guard let startDate = brief.startDate, let endDate = brief.endDate else { return }
        let previous = result
        let revise = change.flatMap { text in previous.map { PlannerBody.Revise(generationId: $0.generationId, change: String(text.prefix(300))) } }
        let body = PlannerBody(
            destination: brief.destination.trimmingCharacters(in: .whitespaces),
            startDate: startDate,
            endDate: endDate,
            party: brief.party,
            budget: brief.budget,
            pace: brief.pace,
            interests: brief.interests.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            language: appLanguage(),
            revise: revise,
            adaptFrom: revise == nil ? adapt?.adaptFromId.map { PlannerBody.AdaptFrom(tripId: $0) } : nil
        )
        generating = true
        error = nil
        Task {
            do {
                let plan = try await state.api.plan(body)
                result = plan
                savedTripId = nil
                let days = plan.itinerary.days.count
                addNote(
                    fromUser: false,
                    text: L(revise != nil ? "chat_plan_updated" : "chat_plan_ready", days, body.destination),
                    replies: revise != nil ? [] : [L("chat_plan_reply_1"), L("chat_plan_reply_2"), L("chat_plan_reply_3")],
                    showsPlan: true
                )
                // Show a first plan straight away; changes stay in the conversation
                if previous == nil { showingPlan = true }
            } catch let failure as APIError where failure.status == 429 {
                addNote(fromUser: false, text: L(state.signedIn ? "chat_limit_user" : "chat_limit_guest"), local: true)
            } catch {
                addNote(fromUser: false, text: failureText(error, fallback: "planner_failed"), local: true)
            }
            generating = false
        }
    }

    /// Backend messages are in English, so other languages get the translated fallback.
    private func failureText(_ error: Error, fallback: String) -> String {
        if appLanguage() == "en", let message = (error as? APIError)?.userMessage { return message }
        return L(fallback)
    }

    func save(state: AppState) {
        guard let result else { return }
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
