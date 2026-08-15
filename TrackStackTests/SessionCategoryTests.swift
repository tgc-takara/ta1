import XCTest
@testable import TrackStack

/// カテゴリ統合(新聞→記事 / ポッドキャスト→動画・音声)後も、
/// 統合前に保存された記録が正しいカテゴリとして読めることを検証する。
final class SessionCategoryTests: XCTestCase {

    func testLegacyNewspaperRawValueReadsAsArticle() {
        let session = Session(category: .reading, startedAt: Date(), durationMinutes: 20)
        session.categoryRaw = "newspaper"
        XCTAssertEqual(session.category, .article)
    }

    func testLegacyPodcastRawValueReadsAsMedia() {
        let session = Session(category: .reading, startedAt: Date(), durationMinutes: 55)
        session.categoryRaw = "podcast"
        XCTAssertEqual(session.category, .media)
    }

    /// 未知の値は既定(勉強)に倒す。カテゴリ不明で記録が消えるのを防ぐため。
    func testUnknownRawValueFallsBackToStudy() {
        let session = Session(category: .reading, startedAt: Date(), durationMinutes: 10)
        session.categoryRaw = "unknown-category"
        XCTAssertEqual(session.category, .study)
    }

    func testCurrentRawValuesRoundTrip() {
        for category in ActivityCategory.allCases {
            let session = Session(category: category, startedAt: Date(), durationMinutes: 5)
            XCTAssertEqual(session.category, category)
        }
    }
}
