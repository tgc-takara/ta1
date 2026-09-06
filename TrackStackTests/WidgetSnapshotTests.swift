import XCTest
@testable import TrackStack

final class WidgetSnapshotTests: XCTestCase {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    /// activeCategoryRaw / activeStartedAt を持たない旧データも読めること(後方互換)
    func testDecodesLegacyJSONWithoutActiveFields() throws {
        let json = """
        {
          "date": 700000000,
          "totalMinutes": 75,
          "minutesByCategory": {"reading": 30, "study": 45},
          "streak": 3
        }
        """
        let snapshot = try decoder.decode(WidgetSnapshot.self, from: Data(json.utf8))

        XCTAssertEqual(snapshot.totalMinutes, 75)
        XCTAssertEqual(snapshot.minutesByCategory["reading"], 30)
        XCTAssertEqual(snapshot.streak, 3)
        XCTAssertNil(snapshot.activeCategoryRaw)
        XCTAssertNil(snapshot.activeStartedAt)
        XCTAssertNil(snapshot.activeCategory)
    }

    func testRoundTripWithoutActive() throws {
        let original = WidgetSnapshot(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            totalMinutes: 40,
            minutesByCategory: ["training": 40],
            streak: 1
        )
        let decoded = try decoder.decode(WidgetSnapshot.self, from: encoder.encode(original))

        XCTAssertEqual(decoded, original)
        XCTAssertNil(decoded.activeCategory)
    }

    func testRoundTripWithActive() throws {
        let startedAt = Date(timeIntervalSince1970: 1_700_003_600)
        let original = WidgetSnapshot(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            totalMinutes: 40,
            minutesByCategory: ["training": 40],
            streak: 1,
            activeCategoryRaw: ActivityCategory.study.rawValue,
            activeStartedAt: startedAt
        )
        let decoded = try decoder.decode(WidgetSnapshot.self, from: encoder.encode(original))

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.activeCategory, .study)
        XCTAssertEqual(decoded.activeStartedAt, startedAt)
    }

    /// 開始時刻が欠けている中途半端な状態は「計測中ではない」とみなす
    func testActiveCategoryNeedsStartedAt() {
        let snapshot = WidgetSnapshot(
            date: Date(),
            totalMinutes: 0,
            minutesByCategory: [:],
            streak: 0,
            activeCategoryRaw: ActivityCategory.reading.rawValue,
            activeStartedAt: nil
        )
        XCTAssertNil(snapshot.activeCategory)
    }

    /// 廃止済みカテゴリの rawValue が残っていても落ちない
    func testActiveCategoryIgnoresRemovedRawValue() {
        let snapshot = WidgetSnapshot(
            date: Date(),
            totalMinutes: 0,
            minutesByCategory: [:],
            streak: 0,
            activeCategoryRaw: "article",
            activeStartedAt: Date()
        )
        XCTAssertNil(snapshot.activeCategory)
    }
}
