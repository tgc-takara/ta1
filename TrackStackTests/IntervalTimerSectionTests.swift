import XCTest
@testable import TrackStack

final class IntervalTimerSectionTests: XCTestCase {
    private let now = Date()

    func testRemainingSecondsWithTimeLeft() {
        let endDate = now.addingTimeInterval(45)
        XCTAssertEqual(IntervalTimerSection.remainingSeconds(now: now, endDate: endDate), 45)
    }

    func testRemainingSecondsExactlyZero() {
        XCTAssertEqual(IntervalTimerSection.remainingSeconds(now: now, endDate: now), 0)
    }

    func testRemainingSecondsPastEndDate() {
        let endDate = now.addingTimeInterval(-10)
        XCTAssertEqual(IntervalTimerSection.remainingSeconds(now: now, endDate: endDate), 0)
    }
}
