import XCTest
@testable import TrackStack

/// Session の categoryRaw を ActivityCategory として読むときの挙動を検証する。
final class SessionCategoryTests: XCTestCase {

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
