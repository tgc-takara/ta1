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

    // MARK: totalMinutes

    func testTotalMinutesSumsAllSessions() {
        let sessions = [
            Session(category: .reading, startedAt: Date(), durationMinutes: 30),
            Session(category: .reading, startedAt: Date(), durationMinutes: 45),
        ]
        XCTAssertEqual(StatsCalculator.totalMinutes(sessions), 75)
    }

    func testTotalMinutesIsZeroForEmptySessions() {
        XCTAssertEqual(StatsCalculator.totalMinutes([]), 0)
    }

    // MARK: sessions(on:)

    func testSessionsOnDayFiltersOtherDays() {
        let todaySession = Session(category: .study, startedAt: Date(), durationMinutes: 30)
        let oldSession = Session(category: .study, startedAt: day(-3), durationMinutes: 30)
        let result = StatsCalculator.sessions([todaySession, oldSession], on: Date())
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, todaySession.id)
    }

    // MARK: dailyMinutes

    func testDailyMinutesReturnsSevenDaysEndingOnGivenDate() {
        let result = StatsCalculator.dailyMinutes([], days: 7, endingOn: Date())
        XCTAssertEqual(result.count, 7)
        XCTAssertEqual(result.last?.date, calendar.startOfDay(for: Date()))
        XCTAssertEqual(result.first?.date, day(-6))
    }

    func testDailyMinutesFillsMissingDaysWithZero() {
        let sessions = [Session(category: .study, startedAt: day(-1), durationMinutes: 30)]
        let result = StatsCalculator.dailyMinutes(sessions, days: 7, endingOn: Date())
        // 記録がない日は minutesByCategory が空(合計0)であること
        let today = result.last!
        XCTAssertTrue(today.minutesByCategory.isEmpty || today.minutesByCategory.values.allSatisfy { $0 == 0 })
    }

    func testDailyMinutesAggregatesByCategory() {
        let sessions = [
            Session(category: .study, startedAt: Date(), durationMinutes: 30),
            Session(category: .study, startedAt: Date(), durationMinutes: 15),
            Session(category: .reading, startedAt: Date(), durationMinutes: 20),
        ]
        let result = StatsCalculator.dailyMinutes(sessions, days: 7, endingOn: Date())
        let today = result.last!
        XCTAssertEqual(today.minutesByCategory[.study], 45)
        XCTAssertEqual(today.minutesByCategory[.reading], 20)
    }

    // MARK: minutesByDay

    func testMinutesByDaySumsWithinMonth() {
        let now = Date()
        let sessions = [
            Session(category: .study, startedAt: now, durationMinutes: 30),
            Session(category: .reading, startedAt: now, durationMinutes: 20),
        ]
        let result = StatsCalculator.minutesByDay(sessions, in: now)
        XCTAssertEqual(result[calendar.startOfDay(for: now)], 50)
    }

    func testMinutesByDayExcludesSessionsOutsideMonth() {
        let now = Date()
        guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) else {
            return XCTFail("date calculation failed")
        }
        let sessions = [
            Session(category: .study, startedAt: now, durationMinutes: 30),
            Session(category: .study, startedAt: lastMonth, durationMinutes: 99),
        ]
        let result = StatsCalculator.minutesByDay(sessions, in: now)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[calendar.startOfDay(for: now)], 30)
    }

    // MARK: dominantCategoryByDay

    func testDominantCategoryByDayPicksLargestCategory() {
        let now = Date()
        let sessions = [
            Session(category: .study, startedAt: now, durationMinutes: 10),
            Session(category: .reading, startedAt: now, durationMinutes: 50),
        ]
        let result = StatsCalculator.dominantCategoryByDay(sessions, in: now)
        XCTAssertEqual(result[calendar.startOfDay(for: now)], .reading)
    }

    func testDominantCategoryByDayIsDeterministicOnTie() {
        let now = Date()
        // reading と training が同値の場合、ActivityCategory.allCases の順で reading が先勝ち
        let sessions = [
            Session(category: .training, startedAt: now, durationMinutes: 30),
            Session(category: .reading, startedAt: now, durationMinutes: 30),
        ]
        let result = StatsCalculator.dominantCategoryByDay(sessions, in: now)
        XCTAssertEqual(result[calendar.startOfDay(for: now)], .reading)
    }
}
