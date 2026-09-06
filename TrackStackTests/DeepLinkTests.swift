import XCTest
@testable import TrackStack

final class DeepLinkTests: XCTestCase {
    private func parse(_ string: String) -> DeepLink? {
        guard let url = URL(string: string) else { return nil }
        return DeepLink.parse(url)
    }

    func testStartForEachCategory() {
        XCTAssertEqual(parse("hitotsumi://start?category=reading"), .start(.reading))
        XCTAssertEqual(parse("hitotsumi://start?category=training"), .start(.training))
        XCTAssertEqual(parse("hitotsumi://start?category=study"), .start(.study))
    }

    func testRecord() {
        XCTAssertEqual(parse("hitotsumi://record"), .record)
    }

    func testInvalidURLs() {
        // スキーム違い
        XCTAssertNil(parse("https://start?category=reading"))
        // 未知のアクション
        XCTAssertNil(parse("hitotsumi://unknown"))
        // category 指定なし
        XCTAssertNil(parse("hitotsumi://start"))
        // 廃止済みカテゴリ(rawValue が現存しない)
        XCTAssertNil(parse("hitotsumi://start?category=article"))
        // 空 URL
        XCTAssertNil(parse("hitotsumi://"))
    }

    /// ウィジェットの Button(intent:) が書き出す文字列を、アプリ側が解釈できること
    func testStartRecordingIntentDeepLinkIsParsable() {
        for category in ActivityCategory.allCases {
            XCTAssertEqual(
                parse(StartRecordingIntent.deepLinkString(for: category)),
                .start(category),
                "\(category.rawValue) のディープリンクを解釈できない"
            )
        }
    }

    func testSchemeIsCaseInsensitive() {
        XCTAssertEqual(parse("HITOTSUMI://record"), .record)
    }

    // MARK: - ウィジェット(App Intent)からの受け渡し

    /// テスト用の使い捨て UserDefaults
    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "test.StartRecordingIntent.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return defaults
    }

    /// ウィジェットが置いた値をアプリ側が取り出し、DeepLink として解釈できること
    func testPendingDeepLinkRoundTrip() throws {
        let defaults = try makeDefaults()
        for category in ActivityCategory.allCases {
            StartRecordingIntent.storePendingDeepLink(categoryRaw: category.rawValue, in: defaults)
            let url = try XCTUnwrap(StartRecordingIntent.takePendingDeepLink(from: defaults))
            XCTAssertEqual(DeepLink.parse(url), .start(category))
        }
    }

    /// 取り出したら消える(同じリンクを二度処理しない)
    func testPendingDeepLinkIsConsumedOnce() throws {
        let defaults = try makeDefaults()
        StartRecordingIntent.storePendingDeepLink(categoryRaw: ActivityCategory.study.rawValue, in: defaults)

        XCTAssertNotNil(StartRecordingIntent.takePendingDeepLink(from: defaults))
        XCTAssertNil(StartRecordingIntent.takePendingDeepLink(from: defaults))
        XCTAssertNil(defaults.string(forKey: StartRecordingIntent.pendingDeepLinkKey))
    }

    /// 何も置かれていなければ nil
    func testTakePendingDeepLinkWithoutValue() throws {
        let defaults = try makeDefaults()
        XCTAssertNil(StartRecordingIntent.takePendingDeepLink(from: defaults))
    }

    /// 廃止済みカテゴリが置かれていても、解釈段階で弾かれる
    func testPendingDeepLinkWithRemovedCategoryIsIgnored() throws {
        let defaults = try makeDefaults()
        StartRecordingIntent.storePendingDeepLink(categoryRaw: "article", in: defaults)
        let url = try XCTUnwrap(StartRecordingIntent.takePendingDeepLink(from: defaults))
        XCTAssertNil(DeepLink.parse(url))
    }
}
