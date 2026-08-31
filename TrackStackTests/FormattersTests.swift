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

    func testPresetLabel() {
        XCTAssertEqual(Formatters.presetLabel(seconds: 45), "45秒")
        XCTAssertEqual(Formatters.presetLabel(seconds: 120), "2分")
        XCTAssertEqual(Formatters.presetLabel(seconds: 90), "1分30秒")
        XCTAssertEqual(Formatters.presetLabel(seconds: 600), "10分")
    }

    func testWeekRange() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1 // 日曜始まり
        // 2026-08-08(土) を含む週(日曜始まり) = 8/2(日)〜8/8(土)
        let anchor = date(hour: 12, minute: 0)
        let interval = calendar.dateInterval(of: .weekOfYear, for: anchor)!
        XCTAssertEqual(Formatters.weekRange(interval), "8/2〜8/8")
    }

    func testWeekRangeLastDayIsOneDayBeforeIntervalEnd() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        let anchor = date(hour: 12, minute: 0)
        let interval = calendar.dateInterval(of: .weekOfYear, for: anchor)!
        let expectedLastDay = calendar.date(byAdding: .day, value: -1, to: interval.end)!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
        let expected = "\(formatter.string(from: interval.start))〜\(formatter.string(from: expectedLastDay))"
        XCTAssertEqual(Formatters.weekRange(interval), expected)
    }
}
