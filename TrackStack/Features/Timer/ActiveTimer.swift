import Foundation
import Observation

/// タイマーの状態のスナップショット。UserDefaults に JSON で永続化するための値型。
/// 「開始時刻との差分」方式で経過時間を計算するため、バックグラウンド実行や
/// アプリ強制終了があっても復元できる。
struct ActiveTimerState: Codable {
    var categoryRaw: String
    var startedAt: Date
    /// これまでの一時停止時間の合計(秒)
    var accumulatedPauseSeconds: TimeInterval
    /// 現在一時停止中ならその開始時刻。計測中は nil
    var pauseStartedAt: Date?
    /// ポモドーロモードのときの進行状態。ストップウォッチのときは nil
    var pomodoro: PomodoroState?

    init(
        categoryRaw: String,
        startedAt: Date,
        accumulatedPauseSeconds: TimeInterval,
        pauseStartedAt: Date?,
        pomodoro: PomodoroState? = nil
    ) {
        self.categoryRaw = categoryRaw
        self.startedAt = startedAt
        self.accumulatedPauseSeconds = accumulatedPauseSeconds
        self.pauseStartedAt = pauseStartedAt
        self.pomodoro = pomodoro
    }

    private enum CodingKeys: String, CodingKey {
        case categoryRaw, startedAt, accumulatedPauseSeconds, pauseStartedAt, pomodoro
    }

    // pomodoro を持たない旧データも読めるように decodeIfPresent で補う
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.categoryRaw = try container.decode(String.self, forKey: .categoryRaw)
        self.startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.accumulatedPauseSeconds = try container.decode(TimeInterval.self, forKey: .accumulatedPauseSeconds)
        self.pauseStartedAt = try container.decodeIfPresent(Date.self, forKey: .pauseStartedAt)
        self.pomodoro = try container.decodeIfPresent(PomodoroState.self, forKey: .pomodoro)
    }
}

/// 実行中のタイマーを管理する。@Observable(iOS 17 Observation フレームワーク)で
/// SwiftUI から直接参照できるようにし、状態はすべて UserDefaults へ即時保存する。
@Observable
final class ActiveTimer {
    private static let userDefaultsKey = "activeTimerState"

    private(set) var state: ActiveTimerState?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.userDefaultsKey),
           let decoded = try? JSONDecoder().decode(ActiveTimerState.self, from: data) {
            self.state = decoded
        } else {
            self.state = nil
        }
    }

    var isRunning: Bool { state != nil }

    var isPaused: Bool { state?.pauseStartedAt != nil }

    var category: ActivityCategory? {
        guard let raw = state?.categoryRaw else { return nil }
        return ActivityCategory(rawValue: raw)
    }

    /// ポモドーロモードで動作中かどうか
    var isPomodoro: Bool { state?.pomodoro != nil }

    var pomodoroState: PomodoroState? { state?.pomodoro }

    func start(category: ActivityCategory) {
        let now = Date()
        state = ActiveTimerState(
            categoryRaw: category.rawValue,
            startedAt: now,
            accumulatedPauseSeconds: 0,
            pauseStartedAt: nil
        )
        PomodoroNotifier.cancel()
        persist()
    }

    /// ポモドーロとして開始する。設定は開始時にスナップショットする。
    func startPomodoro(category: ActivityCategory) {
        let now = Date()
        let pomodoro = Pomodoro.start(settings: PomodoroSettings.load(), now: now)
        state = ActiveTimerState(
            categoryRaw: category.rawValue,
            startedAt: now,
            accumulatedPauseSeconds: 0,
            pauseStartedAt: nil,
            pomodoro: pomodoro
        )
        persist()
        PomodoroNotifier.schedule(for: pomodoro)
    }

    /// ストップウォッチ / ポモドーロを切り替える。同じカテゴリで開始し直す(開始時刻は今にリセット)。
    func switchMode(toPomodoro: Bool) {
        guard let category else { return }
        if toPomodoro {
            startPomodoro(category: category)
        } else {
            start(category: category)
        }
    }

    /// ポモドーロの局面を現在時刻に追いつかせる。局面が変わったら true を返す(呼び出し側が音を鳴らす)。
    @discardableResult
    func tick(now: Date = Date()) -> Bool {
        guard var current = state, let pomodoro = current.pomodoro else { return false }
        let advanced = Pomodoro.advancedIfNeeded(state: pomodoro, now: now)
        guard advanced != pomodoro else { return false }
        current.pomodoro = advanced
        state = current
        persist()
        PomodoroNotifier.schedule(for: advanced, now: now)
        return true
    }

    /// 現在の局面をスキップして次へ進める。
    func skipPhase(now: Date = Date()) {
        guard var current = state, let pomodoro = current.pomodoro else { return }
        let next = Pomodoro.skip(state: pomodoro, now: now)
        current.pomodoro = next
        state = current
        persist()
        PomodoroNotifier.schedule(for: next, now: now)
    }

    func pause() {
        guard var current = state, current.pauseStartedAt == nil else { return }
        current.pauseStartedAt = Date()
        state = current
        persist()
    }

    func resume() {
        guard var current = state, let pauseStartedAt = current.pauseStartedAt else { return }
        current.accumulatedPauseSeconds += Date().timeIntervalSince(pauseStartedAt)
        current.pauseStartedAt = nil
        state = current
        persist()
    }

    /// タイマーを終了し、記録に必要な情報を返す。state はクリアされる。
    func finish(now: Date = Date()) -> (category: ActivityCategory, startedAt: Date, durationMinutes: Int)? {
        guard let current = state,
              let category = ActivityCategory(rawValue: current.categoryRaw) else {
            return nil
        }
        let minutes: Int
        if let pomodoro = current.pomodoro {
            // ポモドーロは休憩を含めず、作業局面の合計だけを記録する
            let workSeconds = Pomodoro.workSeconds(now: now, state: pomodoro)
            minutes = max(1, Int((Double(workSeconds) / 60).rounded(.up)))
        } else {
            minutes = Self.minutes(fromSeconds: Self.elapsedSeconds(now: now, state: current))
        }
        clear()
        return (category: category, startedAt: current.startedAt, durationMinutes: minutes)
    }

    func cancel() {
        clear()
    }

    private func clear() {
        PomodoroNotifier.cancel()
        state = nil
        defaults.removeObject(forKey: Self.userDefaultsKey)
    }

    private func persist() {
        guard let state else {
            defaults.removeObject(forKey: Self.userDefaultsKey)
            return
        }
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: Self.userDefaultsKey)
        }
    }

    // MARK: - 純粋関数(テスト対象)

    /// 現在時刻と状態から経過秒を計算する。負値になった場合は 0 を返す。
    static func elapsedSeconds(now: Date, state: ActiveTimerState) -> Int {
        var elapsed = now.timeIntervalSince(state.startedAt)
        elapsed -= state.accumulatedPauseSeconds
        if let pauseStartedAt = state.pauseStartedAt {
            elapsed -= now.timeIntervalSince(pauseStartedAt)
        }
        return max(0, Int(elapsed))
    }

    /// 経過秒を記録用の分に変換する(四捨五入、最低 1 分)。
    static func minutes(fromSeconds seconds: Int) -> Int {
        let rounded = Int((Double(seconds) / 60).rounded())
        return max(1, rounded)
    }
}
