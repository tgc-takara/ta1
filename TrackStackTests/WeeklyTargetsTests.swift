import XCTest
@testable import TrackStack

/// 週の目標時間設定の読み書きを検証する。
final class WeeklyTargetsTests: XCTestCase {
    private var original: [String: Any]?

    override func setUpWithError() throws {
        original = UserDefaults.standard.dictionary(forKey: WeeklyTargets.userDefaultsKey)
    }

    override func tearDownWithError() throws {
        if let original {
            UserDefaults.standard.set(original, forKey: WeeklyTargets.userDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: WeeklyTargets.userDefaultsKey)
        }
    }

    func testSaveAndLoadRoundTrip() {
        WeeklyTargets.save([.reading: 300, .training: 120])
        XCTAssertEqual(WeeklyTargets.load(), [.reading: 300, .training: 120])
    }

    /// 0を保存したカテゴリはエントリごと消える(「目標なし」に戻る)
    func testSavingZeroRemovesEntry() {
        WeeklyTargets.save([.reading: 300])
        WeeklyTargets.save([.reading: 0])
        XCTAssertEqual(WeeklyTargets.load(), [:])
    }

    func testDefaultsToEmptyDictionary() {
        UserDefaults.standard.removeObject(forKey: WeeklyTargets.userDefaultsKey)
        XCTAssertEqual(WeeklyTargets.load(), [:])
    }

    /// 出鱈目なキーが混ざっていても無視して読める
    func testUnknownKeysAreIgnored() {
        UserDefaults.standard.set(
            ["reading": 300, "bogus": 45],
            forKey: WeeklyTargets.userDefaultsKey
        )
        XCTAssertEqual(WeeklyTargets.load(), [.reading: 300])
    }
}
