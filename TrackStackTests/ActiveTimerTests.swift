import XCTest
@testable import TrackStack

final class ActiveTimerTests: XCTestCase {
    private let now = Date()

    // MARK: elapsedSeconds

    func testElapsedSecondsWithoutPause() {
        let started = now.addingTimeInterval(-120)
        let state = ActiveTimerState(
            categoryRaw: ActivityCategory.study.rawValue,
            startedAt: started,
            accumulatedPauseSeconds: 0,
            pauseStartedAt: nil
        )
        XCTAssertEqual(ActiveTimer.elapsedSeconds(now: now, state: state), 120)
    }

    func testElapsedSecondsWithResolvedPause() {
        // 200 秒前に開始し、途中で 50 秒一時停止して再開済み(累積済み)のケース
        let started = now.addingTimeInterval(-200)
        let state = ActiveTimerState(
            categoryRaw: ActivityCategory.training.rawValue,
            startedAt: started,
            accumulatedPauseSeconds: 50,
            pauseStartedAt: nil
        )
        XCTAssertEqual(ActiveTimer.elapsedSeconds(now: now, state: state), 150)
    }

    func testElapsedSecondsWhileCurrentlyPaused() {
        // 300 秒前に開始し、過去に 20 秒一時停止済み、さらに今 30 秒前から再度一時停止中
        let started = now.addingTimeInterval(-300)
        let pauseStartedAt = now.addingTimeInterval(-30)
        let state = ActiveTimerState(
            categoryRaw: ActivityCategory.reading.rawValue,
            startedAt: started,
            accumulatedPauseSeconds: 20,
            pauseStartedAt: pauseStartedAt
        )
        // 300 - 20(過去の一時停止) - 30(現在一時停止中の経過分) = 250
        XCTAssertEqual(ActiveTimer.elapsedSeconds(now: now, state: state), 250)
    }

    func testElapsedSecondsNeverNegative() {
        // 一時停止の累積が経過時間を上回るような異常値でも 0 未満にならない
        let started = now.addingTimeInterval(-10)
        let state = ActiveTimerState(
            categoryRaw: ActivityCategory.study.rawValue,
            startedAt: started,
            accumulatedPauseSeconds: 100,
            pauseStartedAt: nil
        )
        XCTAssertEqual(ActiveTimer.elapsedSeconds(now: now, state: state), 0)
    }

    // MARK: minutes(fromSeconds:)

    func testMinutesRoundsToNearest() {
        XCTAssertEqual(ActiveTimer.minutes(fromSeconds: 89), 1) // 1分29秒 → 1分
        XCTAssertEqual(ActiveTimer.minutes(fromSeconds: 90), 2) // 1分30秒 → 四捨五入で2分
        XCTAssertEqual(ActiveTimer.minutes(fromSeconds: 150), 3) // 2分30秒 → 3分
    }

    func testMinutesHasMinimumOfOne() {
        XCTAssertEqual(ActiveTimer.minutes(fromSeconds: 0), 1)
        XCTAssertEqual(ActiveTimer.minutes(fromSeconds: 10), 1)
    }

    // MARK: finish() の統合的な確認(状態遷移とクリアの確認)

    func testFinishReturnsResultAndClearsState() {
        let defaults = UserDefaults(suiteName: "ActiveTimerTests.\(UUID().uuidString)")!
        let timer = ActiveTimer(defaults: defaults)
        timer.start(category: .training)
        XCTAssertTrue(timer.isRunning)

        let result = timer.finish(now: now.addingTimeInterval(180))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.category, .training)
        XCTAssertFalse(timer.isRunning)
        XCTAssertNil(defaults.data(forKey: "activeTimerState"))
    }
}
