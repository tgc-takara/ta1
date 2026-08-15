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

    /// 予告音はラスト3秒(3・2・1)だけ。0秒は終了音の担当なので鳴らさない。
    func testBeepsOnlyDuringLastThreeSeconds() {
        XCTAssertTrue(IntervalTimerSection.shouldBeep(remaining: 3))
        XCTAssertTrue(IntervalTimerSection.shouldBeep(remaining: 2))
        XCTAssertTrue(IntervalTimerSection.shouldBeep(remaining: 1))
        XCTAssertFalse(IntervalTimerSection.shouldBeep(remaining: 4))
        XCTAssertFalse(IntervalTimerSection.shouldBeep(remaining: 0))
        XCTAssertFalse(IntervalTimerSection.shouldBeep(remaining: -1))
    }
}
