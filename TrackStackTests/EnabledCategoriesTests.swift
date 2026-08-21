import XCTest
@testable import TrackStack

/// 表示カテゴリ設定の読み書きと、内訳に出すカテゴリの決まり方を検証する。
final class EnabledCategoriesTests: XCTestCase {
    private var original: [String]?

    override func setUpWithError() throws {
        original = UserDefaults.standard.stringArray(forKey: EnabledCategories.userDefaultsKey)
    }

    override func tearDownWithError() throws {
        if let original {
            UserDefaults.standard.set(original, forKey: EnabledCategories.userDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: EnabledCategories.userDefaultsKey)
        }
    }

    func testDefaultsToAllCategories() {
        UserDefaults.standard.removeObject(forKey: EnabledCategories.userDefaultsKey)
        XCTAssertEqual(EnabledCategories.load(), ActivityCategory.allCases)
    }

    /// 保存順に関わらず allCases の並びに揃える(選択肢の順序を安定させるため)
    func testLoadKeepsCanonicalOrder() {
        EnabledCategories.save([.study, .reading])
        XCTAssertEqual(EnabledCategories.load(), [.reading, .study])
    }

    func testEmptySelectionFallsBackToAllCategories() {
        EnabledCategories.save([])
        XCTAssertEqual(EnabledCategories.load(), ActivityCategory.allCases)
    }

    /// オフにしていても、その期間に記録があるカテゴリは内訳に残す(合計と内訳を一致させるため)
    func testForDisplayIncludesDisabledCategoryThatHasMinutes() {
        EnabledCategories.save([.reading])
        let display = EnabledCategories.forDisplay(minutes: [.training: 30])
        XCTAssertEqual(display, [.reading, .training])
    }

    func testForDisplayExcludesDisabledCategoryWithoutMinutes() {
        EnabledCategories.save([.reading])
        let display = EnabledCategories.forDisplay(minutes: [.training: 0])
        XCTAssertEqual(display, [.reading])
    }

    /// 編集中の記録のカテゴリは、非表示でも選択肢から消さない
    func testForPickerAlwaysIncludesCurrentCategory() {
        EnabledCategories.save([.reading])
        XCTAssertEqual(EnabledCategories.forPicker(including: .study), [.reading, .study])
        XCTAssertEqual(EnabledCategories.forPicker(including: nil), [.reading])
    }
}
