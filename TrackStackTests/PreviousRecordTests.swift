import XCTest
import SwiftData
@testable import TrackStack

final class PreviousRecordTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([
            Session.self, Book.self, BookGenre.self, Subject.self,
            Exercise.self, ExerciseLog.self, WorkoutMenu.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    /// 指定日にベンチプレスのセッションを作る
    @discardableResult
    private func makeTraining(
        on date: Date,
        exercise: String,
        sets: [SetRecord]
    ) -> Session {
        let session = Session(category: .training, startedAt: date, durationMinutes: 60)
        context.insert(session)
        let log = ExerciseLog(exerciseName: exercise, bodyPart: .chest, order: 0)
        log.sets = sets
        log.session = session
        context.insert(log)
        return session
    }

    func testReturnsMostRecentRecordForExercise() {
        let older = Date(timeIntervalSince1970: 1_000_000)
        let newer = Date(timeIntervalSince1970: 2_000_000)
        makeTraining(on: older, exercise: "ベンチプレス", sets: [SetRecord(weightKg: 50, reps: 10)])
        makeTraining(on: newer, exercise: "ベンチプレス", sets: [SetRecord(weightKg: 60, reps: 8)])

        let result = PreviousRecord.latest(for: ["ベンチプレス"], excluding: nil, in: context)

        XCTAssertEqual(result["ベンチプレス"]?.detail, "60kg×8")
        XCTAssertEqual(result["ベンチプレス"]?.date, newer)
    }

    /// 編集中のセッション自身は「前回」に含めない
    func testExcludesEditingSession() {
        let older = Date(timeIntervalSince1970: 1_000_000)
        let newer = Date(timeIntervalSince1970: 2_000_000)
        makeTraining(on: older, exercise: "ベンチプレス", sets: [SetRecord(weightKg: 50, reps: 10)])
        let editing = makeTraining(on: newer, exercise: "ベンチプレス", sets: [SetRecord(weightKg: 60, reps: 8)])

        let result = PreviousRecord.latest(for: ["ベンチプレス"], excluding: editing.id, in: context)

        XCTAssertEqual(result["ベンチプレス"]?.detail, "50kg×10")
    }

    func testReturnsNothingForUnknownExercise() {
        makeTraining(on: Date(), exercise: "ベンチプレス", sets: [SetRecord(weightKg: 50, reps: 10)])
        let result = PreviousRecord.latest(for: ["デッドリフト"], excluding: nil, in: context)
        XCTAssertNil(result["デッドリフト"])
    }

    func testSummaryDetailMarksSingleArmSets() {
        let log = ExerciseLog(exerciseName: "ダンベルカール", bodyPart: .biceps, order: 0)
        log.sets = [
            SetRecord(weightKg: 12.5, reps: 10, isSingleArm: true),
            SetRecord(weightKg: -20, reps: 8),
        ]
        XCTAssertEqual(log.summaryDetail, "12.5kg×10(片手), -20kg×8")
    }

    func testSummaryDetailForCardio() {
        let log = ExerciseLog(exerciseName: "ランニング", bodyPart: .cardio, order: 0)
        log.distanceKm = 3
        log.durationMinutes = 20
        XCTAssertEqual(log.summaryDetail, "3.0km 20分")
    }
}

/// 数値入力の先頭ゼロ処理
final class NumberInputTests: XCTestCase {

    func testTrimsLeadingZeros() {
        XCTAssertEqual(trimmedLeadingZeros("075"), "75")
        XCTAssertEqual(trimmedLeadingZeros("07"), "7")
        XCTAssertEqual(trimmedLeadingZeros("0007"), "7")
    }

    func testKeepsSingleZeroAndDecimals() {
        XCTAssertEqual(trimmedLeadingZeros("0"), "0")
        XCTAssertEqual(trimmedLeadingZeros("0.5"), "0.5")
        XCTAssertEqual(trimmedLeadingZeros(""), "")
    }

    func testKeepsNegativeSign() {
        XCTAssertEqual(trimmedLeadingZeros("-020"), "-20")
        XCTAssertEqual(trimmedLeadingZeros("-0.5"), "-0.5")
    }

    func testLeavesNormalInputUnchanged() {
        XCTAssertEqual(trimmedLeadingZeros("75"), "75")
        XCTAssertEqual(trimmedLeadingZeros("12.5"), "12.5")
    }
}
