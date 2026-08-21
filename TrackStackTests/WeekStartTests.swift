import XCTest
@testable import TrackStack

/// 週の始まり設定の読み書きと、AppCalendar への反映を検証する。
final class WeekStartTests: XCTestCase {
    private var original: Int?

    override func setUpWithError() throws {
        if UserDefaults.standard.object(forKey: WeekStart.userDefaultsKey) != nil {
            original = UserDefaults.standard.integer(forKey: WeekStart.userDefaultsKey)
        } else {
            original = nil
        }
    }

    override func tearDownWithError() throws {
        if let original {
            UserDefaults.standard.set(original, forKey: WeekStart.userDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: WeekStart.userDefaultsKey)
        }
    }

    func testDefaultsToSystem() {
        UserDefaults.standard.removeObject(forKey: WeekStart.userDefaultsKey)
        XCTAssertEqual(WeekStart.load(), .system)
    }

    func testSaveAndLoadRoundTrip() {
        WeekStart.save(.monday)
        XCTAssertEqual(WeekStart.load(), .monday)

        WeekStart.save(.sunday)
        XCTAssertEqual(WeekStart.load(), .sunday)
    }

    /// 不明な値(未知の rawValue)が保存されていた場合は .system に読み替える
    func testUnknownRawValueFallsBackToSystem() {
        UserDefaults.standard.set(99, forKey: WeekStart.userDefaultsKey)
        XCTAssertEqual(WeekStart.load(), .system)
    }

    func testAppCalendarUsesMondayWhenSaved() {
        WeekStart.save(.monday)
        XCTAssertEqual(AppCalendar.current.firstWeekday, 2)
    }

    func testAppCalendarMatchesSystemCalendarWhenSystemSelected() {
        WeekStart.save(.system)
        XCTAssertEqual(AppCalendar.current.firstWeekday, Calendar.current.firstWeekday)
    }
}
