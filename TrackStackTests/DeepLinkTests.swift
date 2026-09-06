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

    func testSchemeIsCaseInsensitive() {
        XCTAssertEqual(parse("HITOTSUMI://record"), .record)
    }
}
