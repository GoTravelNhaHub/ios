import Foundation

enum BriefField: Equatable { case destination, dates, ages }

/// One field the agent changed, shown under its reply
enum BriefChange: Equatable {
    case destination(String)
    case dates(start: String, end: String)
    case travellers(ages: [Int])
    case budget(Double)
    case pace(String)
    case interests(String)
}

/// What the planner knows about the trip. Filled by the agent and by the details sheet.
struct PlannerBrief: Equatable {
    private static let adultAge = 18
    private static let defaultAdultAge = 35

    var destination = ""
    var startDate: String?
    var endDate: String?
    var party: [PartyMember] = []
    var budget: Double?
    var pace = "balanced"
    var interests = ""

    var adults: Int { party.filter { $0.age >= Self.adultAge }.count }
    var children: [PartyMember] { party.filter { $0.age < Self.adultAge } }

    /// What the itinerary call still needs
    var missing: [BriefField] {
        var fields: [BriefField] = []
        if destination.trimmingCharacters(in: .whitespaces).count < 2 { fields.append(.destination) }
        if startDate == nil || endDate == nil { fields.append(.dates) }
        if party.isEmpty { fields.append(.ages) }
        return fields
    }

    func withAdults(_ count: Int) -> PlannerBrief {
        var next = self
        let current = party.filter { $0.age >= Self.adultAge }
        let added = Array(repeating: PartyMember(age: Self.defaultAdultAge), count: max(count - current.count, 0))
        next.party = current.prefix(count) + added + children
        return next
    }

    func withChild(age: Int) -> PlannerBrief {
        var next = self
        next.party.append(PartyMember(age: age))
        return next
    }

    func withoutChild(at index: Int) -> PlannerBrief {
        var next = self
        var remaining = children
        remaining.remove(at: index)
        next.party = party.filter { $0.age >= Self.adultAge } + remaining
        return next
    }

    /// Applies the agent's updates and lists what actually changed.
    func applying(_ updates: AgentUpdates) -> (brief: PlannerBrief, changes: [BriefChange]) {
        var next = self
        var changes: [BriefChange] = []
        if let value = updates.destination, value != destination {
            next.destination = value
            changes.append(.destination(value))
        }
        let start = updates.startDate ?? startDate
        var end = updates.endDate ?? endDate
        if let from = start, let to = end, to < from { end = nil }
        if start != startDate || end != endDate {
            next.startDate = start
            next.endDate = end
            if let start, let end { changes.append(.dates(start: start, end: end)) }
        }
        if let people = updates.travellers, !people.isEmpty {
            next.party = people.map { PartyMember(name: $0.label, age: $0.age) }
            changes.append(.travellers(ages: people.map(\.age)))
        }
        if let value = updates.budget, value != budget {
            next.budget = value
            changes.append(.budget(value))
        }
        if let value = updates.pace, value != pace {
            next.pace = value
            changes.append(.pace(value))
        }
        if let value = updates.interests, value != interests {
            next.interests = value
            changes.append(.interests(value))
        }
        return (next, changes)
    }

    var agentBrief: ChatBody.Brief {
        ChatBody.Brief(
            destination: destination.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            startDate: startDate,
            endDate: endDate,
            travellers: party.map { ChatBody.Traveller(age: $0.age) },
            budget: budget,
            pace: pace,
            interests: interests.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
    }
}
