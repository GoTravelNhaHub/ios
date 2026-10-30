import XCTest
@testable import GoTravelNha

// The same cases run on Android (PlannerBriefTest.kt)
final class PlannerBriefTests: XCTestCase {
    func testEmptyBriefNeedsDestinationDatesAndAges() {
        XCTAssertEqual(PlannerBrief().missing, [.destination, .dates, .ages])
    }

    func testCompleteBriefNeedsNothing() {
        let brief = PlannerBrief(destination: "Tokyo", startDate: "2027-01-02", endDate: "2027-01-05", party: [PartyMember(age: 35)])
        XCTAssertTrue(brief.missing.isEmpty)
    }

    func testUpdatesAreAppliedAndListed() {
        let (brief, changes) = PlannerBrief().applying(AgentUpdates(
            destination: "Tokyo", startDate: "2027-01-02", endDate: "2027-01-05",
            travellers: [.init(age: 35), .init(age: 6, label: "Mia")], budget: 2000, pace: "relaxed", interests: "trains"
        ))
        XCTAssertEqual(brief.destination, "Tokyo")
        XCTAssertEqual(brief.party, [PartyMember(age: 35), PartyMember(name: "Mia", age: 6)])
        XCTAssertEqual(changes, [
            .destination("Tokyo"), .dates(start: "2027-01-02", end: "2027-01-05"), .travellers(ages: [35, 6]),
            .budget(2000), .pace("relaxed"), .interests("trains"),
        ])
    }

    func testUnchangedValuesAreNotListed() {
        let before = PlannerBrief(destination: "Tokyo", startDate: "2027-01-02", endDate: "2027-01-05", pace: "packed")
        let (brief, changes) = before.applying(AgentUpdates(destination: "Tokyo", startDate: "2027-01-02", pace: "packed"))
        XCTAssertEqual(brief, before)
        XCTAssertTrue(changes.isEmpty)
    }

    func testNewStartAfterEndClearsTheEnd() {
        let (brief, changes) = PlannerBrief(startDate: "2027-01-02", endDate: "2027-01-05").applying(AgentUpdates(startDate: "2027-02-01"))
        XCTAssertEqual(brief.startDate, "2027-02-01")
        XCTAssertNil(brief.endDate)
        XCTAssertTrue(changes.isEmpty)
    }

    func testAdultCountKeepsChildren() {
        let brief = PlannerBrief(party: [PartyMember(age: 40), PartyMember(age: 6)]).withAdults(2)
        XCTAssertEqual(brief.adults, 2)
        XCTAssertEqual(brief.children.map(\.age), [6])
        XCTAssertEqual(brief.withAdults(1).adults, 1)
    }

    func testRemovingAChildKeepsEveryoneElse() {
        let brief = PlannerBrief(party: [PartyMember(age: 40), PartyMember(age: 6), PartyMember(age: 9)]).withoutChild(at: 0)
        XCTAssertEqual(brief.party.map(\.age), [40, 9])
    }
}
