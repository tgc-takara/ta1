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

    func start(category: ActivityCategory) {
        let now = Date()
        state = ActiveTimerState(
            categoryRaw: category.rawValue,
            startedAt: now,
            accumulatedPauseSeconds: 0,
            pauseStartedAt: nil
        )
        persist()
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
        let seconds = Self.elapsedSeconds(now: now, state: current)
        let minutes = Self.minutes(fromSeconds: seconds)
        clear()
        return (category: category, startedAt: current.startedAt, durationMinutes: minutes)
    }

    func cancel() {
        clear()
    }

    private func clear() {
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
