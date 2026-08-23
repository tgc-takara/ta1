import XCTest
@testable import TrackStack

final class PomodoroTests: XCTestCase {
    private let now = Date()

    /// テスト用に既定と同じ設定(作業25分 / 休憩5分 / 長い休憩15分 / 4回ごと)
    private let settings = PomodoroSettings()

    // MARK: remainingSeconds

    func testRemainingSecondsRoundsUp() {
        let state = Pomodoro.start(settings: settings, now: now)
        // 開始 0.5 秒後 → 残り 1499.5 秒 → 切り上げて 1500
        XCTAssertEqual(Pomodoro.remainingSeconds(now: now.addingTimeInterval(0.5), state: state), 1500)
        XCTAssertEqual(Pomodoro.remainingSeconds(now: now.addingTimeInterval(60), state: state), 1440)
    }

    func testRemainingSecondsClampsToZero() {
        let state = Pomodoro.start(settings: settings, now: now)
        XCTAssertEqual(Pomodoro.remainingSeconds(now: now.addingTimeInterval(1500), state: state), 0)
        XCTAssertEqual(Pomodoro.remainingSeconds(now: now.addingTimeInterval(9999), state: state), 0)
    }

    // MARK: phaseEndDate

    func testPhaseEndDate() {
        let state = Pomodoro.start(settings: settings, now: now)
        XCTAssertEqual(Pomodoro.phaseEndDate(state: state), now.addingTimeInterval(1500))
    }

    // MARK: advancedIfNeeded

    func testAdvancedIfNeededKeepsStateWhileRunning() {
        let state = Pomodoro.start(settings: settings, now: now)
        let advanced = Pomodoro.advancedIfNeeded(state: state, now: now.addingTimeInterval(100))
        XCTAssertEqual(advanced, state)
    }

    func testWorkAdvancesToShortBreak() {
        let state = Pomodoro.start(settings: settings, now: now)
        let advanced = Pomodoro.advancedIfNeeded(state: state, now: now.addingTimeInterval(1500))
        XCTAssertEqual(advanced.phase, .shortBreak)
        XCTAssertEqual(advanced.completedWorkCycles, 1)
        XCTAssertEqual(advanced.accumulatedWorkSeconds, 1500)
        XCTAssertEqual(advanced.phaseDurationSeconds, 300)
        // 次局面の開始は実時刻ではなく前局面の終了予定時刻
        XCTAssertEqual(advanced.phaseStartedAt, now.addingTimeInterval(1500))
    }

    func testShortBreakAdvancesBackToWork() {
        let state = Pomodoro.start(settings: settings, now: now)
        // 作業25分 + 休憩5分 = 1800 秒経過
        let advanced = Pomodoro.advancedIfNeeded(state: state, now: now.addingTimeInterval(1800))
        XCTAssertEqual(advanced.phase, .work)
        XCTAssertEqual(advanced.completedWorkCycles, 1)
        XCTAssertEqual(advanced.accumulatedWorkSeconds, 1500)
        XCTAssertEqual(advanced.phaseStartedAt, now.addingTimeInterval(1800))
    }

    func testFourthWorkAdvancesToLongBreak() {
        let state = Pomodoro.start(settings: settings, now: now)
        // (作業25分 + 休憩5分) × 3 = 5400 秒、そこから 4 回目の作業 25 分 = 6900 秒
        let advanced = Pomodoro.advancedIfNeeded(state: state, now: now.addingTimeInterval(6900))
        XCTAssertEqual(advanced.phase, .longBreak)
        XCTAssertEqual(advanced.completedWorkCycles, 4)
        XCTAssertEqual(advanced.accumulatedWorkSeconds, 1500 * 4)
        XCTAssertEqual(advanced.phaseDurationSeconds, 900)
    }

    func testAdvancedIfNeededCatchesUpAcrossManyPhases() {
        // 長時間バックグラウンドに置いたケース: 1 サイクル(30分)分をまとめてまたぐ
        let state = Pomodoro.start(settings: settings, now: now)
        let advanced = Pomodoro.advancedIfNeeded(state: state, now: now.addingTimeInterval(3000))
        // 作業(1500) → 休憩(300) → 作業(1500) の途中(3000 秒地点は 2 回目の作業の 1200 秒目)
        XCTAssertEqual(advanced.phase, .work)
        XCTAssertEqual(advanced.completedWorkCycles, 1)
        XCTAssertEqual(advanced.accumulatedWorkSeconds, 1500)
        XCTAssertEqual(advanced.phaseStartedAt, now.addingTimeInterval(1800))
        XCTAssertEqual(Pomodoro.remainingSeconds(now: now.addingTimeInterval(3000), state: advanced), 300)
    }

    // MARK: skip

    func testSkipWorkAddsElapsedAndCountsCycle() {
        let state = Pomodoro.start(settings: settings, now: now)
        let skipped = Pomodoro.skip(state: state, now: now.addingTimeInterval(120))
        XCTAssertEqual(skipped.phase, .shortBreak)
        XCTAssertEqual(skipped.accumulatedWorkSeconds, 120)
        // スキップでもサイクルは1つ消化した扱い(表示が 1/4 → 0/4 に戻らないように)
        XCTAssertEqual(skipped.completedWorkCycles, 1)
        XCTAssertEqual(skipped.phaseStartedAt, now.addingTimeInterval(120))
        XCTAssertEqual(skipped.phaseDurationSeconds, 300)
    }

    func testSkipFourthWorkLeadsToLongBreak() {
        var state = Pomodoro.start(settings: settings, now: now)
        state.completedWorkCycles = 3
        let skipped = Pomodoro.skip(state: state, now: now.addingTimeInterval(60))
        XCTAssertEqual(skipped.phase, .longBreak)
        XCTAssertEqual(skipped.completedWorkCycles, 4)
    }

    func testSkipWorkCapsElapsedAtPhaseDuration() {
        let state = Pomodoro.start(settings: settings, now: now)
        let skipped = Pomodoro.skip(state: state, now: now.addingTimeInterval(9999))
        XCTAssertEqual(skipped.accumulatedWorkSeconds, 1500)
    }

    func testSkipBreakReturnsToWork() {
        let state = Pomodoro.start(settings: settings, now: now)
        let inBreak = Pomodoro.skip(state: state, now: now.addingTimeInterval(60))
        let backToWork = Pomodoro.skip(state: inBreak, now: now.addingTimeInterval(90))
        XCTAssertEqual(backToWork.phase, .work)
        XCTAssertEqual(backToWork.phaseDurationSeconds, 1500)
        // 休憩をスキップしても作業の累計は変わらない
        XCTAssertEqual(backToWork.accumulatedWorkSeconds, 60)
    }

    // MARK: workSeconds

    func testWorkSecondsIncludesCurrentWorkPhase() {
        let state = Pomodoro.start(settings: settings, now: now)
        XCTAssertEqual(Pomodoro.workSeconds(now: now.addingTimeInterval(300), state: state), 300)
    }

    func testWorkSecondsCapsCurrentPhaseAtItsDuration() {
        let state = Pomodoro.start(settings: settings, now: now)
        XCTAssertEqual(Pomodoro.workSeconds(now: now.addingTimeInterval(9999), state: state), 1500)
    }

    func testWorkSecondsDuringBreakReturnsAccumulatedOnly() {
        let state = Pomodoro.start(settings: settings, now: now)
        let inBreak = Pomodoro.advancedIfNeeded(state: state, now: now.addingTimeInterval(1500))
        XCTAssertEqual(inBreak.phase, .shortBreak)
        // 休憩が進んでも作業秒は増えない
        XCTAssertEqual(Pomodoro.workSeconds(now: now.addingTimeInterval(1700), state: inBreak), 1500)
    }

    // MARK: PomodoroSettings

    func testSettingsDefaults() {
        let defaults = PomodoroSettings()
        XCTAssertEqual(defaults.workMinutes, 25)
        XCTAssertEqual(defaults.breakMinutes, 5)
        XCTAssertEqual(defaults.longBreakMinutes, 15)
        XCTAssertEqual(defaults.cyclesBeforeLongBreak, 4)
    }

    func testSettingsLoadReturnsDefaultWhenUnset() {
        UserDefaults.standard.removeObject(forKey: PomodoroSettings.userDefaultsKey)
        XCTAssertEqual(PomodoroSettings.load(), PomodoroSettings())
    }

    func testSettingsSaveLoadRoundTrip() {
        let original = PomodoroSettings.load()
        defer {
            PomodoroSettings.save(original)
        }
        let custom = PomodoroSettings(
            workMinutes: 50,
            breakMinutes: 10,
            longBreakMinutes: 30,
            cyclesBeforeLongBreak: 3
        )
        PomodoroSettings.save(custom)
        XCTAssertEqual(PomodoroSettings.load(), custom)
    }
}
