import XCTest
import SwiftData
@testable import TrackStack

/// 種目名を変えたとき、名前のスナップショットを持つ側(過去の記録・メニュー)も
/// 一緒に書き換わることを確認する。
final class ExerciseRenameTests: XCTestCase {
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

    func testRenamePropagatesToLogsAndMenus() throws {
        let session = Session(category: .training, startedAt: Date(), durationMinutes: 60)
        context.insert(session)
        let target = ExerciseLog(exerciseName: "ベンチプレス", bodyPart: .chest, order: 0)
        target.session = session
        context.insert(target)
        let other = ExerciseLog(exerciseName: "スクワット", bodyPart: .legs, order: 1)
        other.session = session
        context.insert(other)

        let menu = WorkoutMenu(name: "胸の日", items: [
            MenuItem(exerciseName: "ベンチプレス", kindRaw: BodyPart.chest.rawValue, defaultSets: []),
            MenuItem(exerciseName: "スクワット", kindRaw: BodyPart.legs.rawValue, defaultSets: []),
        ])
        context.insert(menu)

        Exercise.propagateRename(from: "ベンチプレス", to: "バーベルベンチプレス", in: context)

        XCTAssertEqual(target.exerciseName, "バーベルベンチプレス")
        // 対象外の種目名は変えない
        XCTAssertEqual(other.exerciseName, "スクワット")
        XCTAssertEqual(menu.items.map(\.exerciseName), ["バーベルベンチプレス", "スクワット"])
    }

    /// 名前が変わっていなければ何もしない
    func testRenameDoesNothingWhenNameIsUnchanged() throws {
        let session = Session(category: .training, startedAt: Date(), durationMinutes: 60)
        context.insert(session)
        let log = ExerciseLog(exerciseName: "ベンチプレス", bodyPart: .chest, order: 0)
        log.session = session
        context.insert(log)

        Exercise.propagateRename(from: "ベンチプレス", to: "ベンチプレス", in: context)

        XCTAssertEqual(log.exerciseName, "ベンチプレス")
    }
}
