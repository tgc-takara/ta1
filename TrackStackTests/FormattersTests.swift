import XCTest
@testable import TrackStack

final class FormattersTests: XCTestCase {
    private func date(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 8
        components.hour = hour
        components.minute = minute
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    func testDuration() {
        XCTAssertEqual(Formatters.duration(minutes: 45), "45分")
        XCTAssertEqual(Formatters.duration(minutes: 60), "1時間")
        XCTAssertEqual(Formatters.duration(minutes: 90), "1時間30分")
    }

    func testTimeRange() {
        XCTAssertEqual(
            Formatters.timeRange(start: date(hour: 22, minute: 58), minutes: 15),
            "22:58〜23:13"
        )
    }

    func testTimeRangeCrossesMidnight() {
        XCTAssertEqual(
            Formatters.timeRange(start: date(hour: 23, minute: 50), minutes: 30),
            "23:50〜0:20"
        )
    }

    func testCountdownClock() {
        XCTAssertEqual(Formatters.countdownClock(seconds: 90), "1:30")
        XCTAssertEqual(Formatters.countdownClock(seconds: 5), "0:05")
        XCTAssertEqual(Formatters.countdownClock(seconds: 600), "10:00")
    }
}
