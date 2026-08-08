import XCTest
@testable import TrackStack

final class StatsCalculatorTests: XCTestCase {
    private let calendar = Calendar.current

    private func day(_ offset: Int, from base: Date = Date()) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: base))!
    }

    // MARK: streak

    func testStreakIsZeroWithNoRecords() {
        XCTAssertEqual(StatsCalculator.streak(recordedDays: [], today: Date()), 0)
    }

    func testStreakCountsConsecutiveDaysIncludingToday() {
        let days: Set<Date> = [day(0), day(-1), day(-2)]
        XCTAssertEqual(StatsCalculator.streak(recordedDays: days, today: Date()), 3)
    }

    func testStreakSurvivesWhenTodayNotYetRecorded() {
        let days: Set<Date> = [day(-1), day(-2)]
        XCTAssertEqual(StatsCalculator.streak(recordedDays: days, today: Date()), 2)
    }

    func testStreakBreaksOnGap() {
        let days: Set<Date> = [day(0), day(-2), day(-3)]
        XCTAssertEqual(StatsCalculator.streak(recordedDays: days, today: Date()), 1)
    }

    func testStreakZeroWhenLastRecordIsTwoDaysAgo() {
        let days: Set<Date> = [day(-2), day(-3)]
        XCTAssertEqual(StatsCalculator.streak(recordedDays: days, today: Date()), 0)
    }

    // MARK: minutesByCategory

    func testMinutesByCategory() {
        let sessions = [
            Session(category: .study, startedAt: Date(), durationMinutes: 30),
            Session(category: .study, startedAt: Date(), durationMinutes: 15),
            Session(category: .reading, startedAt: Date(), durationMinutes: 20),
        ]
        let result = StatsCalculator.minutesByCategory(sessions)
        XCTAssertEqual(result[.study], 45)
        XCTAssertEqual(result[.reading], 20)
        XCTAssertNil(result[.training])
    }

    // MARK: sessions(on:)

    func testSessionsOnDayFiltersOtherDays() {
        let todaySession = Session(category: .study, startedAt: Date(), durationMinutes: 30)
        let oldSession = Session(category: .study, startedAt: day(-3), durationMinutes: 30)
        let result = StatsCalculator.sessions([todaySession, oldSession], on: Date())
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, todaySession.id)
    }
}
