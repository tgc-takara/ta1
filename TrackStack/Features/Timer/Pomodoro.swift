import Foundation

/// ポモドーロの局面。
enum PomodoroPhase: String, Codable {
    case work
    case shortBreak
    case longBreak

    var label: String {
        switch self {
        case .work: return "作業"
        case .shortBreak: return "休憩"
        case .longBreak: return "長い休憩"
        }
    }

    var isBreak: Bool { self != .work }
}

/// ポモドーロの進行状態。ActiveTimerState に同居させて UserDefaults へ永続化する。
/// 既存タイマーと同じく「開始時刻との差分」方式なので、バックグラウンドやアプリ終了をまたいでも復元できる。
struct PomodoroState: Codable, Equatable {
    var phase: PomodoroPhase
    var phaseStartedAt: Date
    var phaseDurationSeconds: Int
    /// 完了した作業局面の回数(長い休憩の判定に使う)
    var completedWorkCycles: Int
    /// 完了した作業局面の累計秒(現在進行中の局面は含めない)
    var accumulatedWorkSeconds: Int
    /// 開始時の設定のスナップショット(途中で設定を変えても進行中のタイマーは影響を受けない)
    var settings: PomodoroSettings
}

/// ポモドーロの純粋ロジック(テスト対象)。UI や永続化には関与しない。
enum Pomodoro {
    /// 作業局面から開始する。
    static func start(settings: PomodoroSettings, now: Date) -> PomodoroState {
        PomodoroState(
            phase: .work,
            phaseStartedAt: now,
            phaseDurationSeconds: seconds(minutes: settings.workMinutes),
            completedWorkCycles: 0,
            accumulatedWorkSeconds: 0,
            settings: settings
        )
    }

    /// 現局面の終了予定時刻(通知のスケジュールに使う)。
    static func phaseEndDate(state: PomodoroState) -> Date {
        state.phaseStartedAt.addingTimeInterval(TimeInterval(state.phaseDurationSeconds))
    }

    /// 現局面の残り秒。切り上げ、負なら 0。
    static func remainingSeconds(now: Date, state: PomodoroState) -> Int {
        let diff = phaseEndDate(state: state).timeIntervalSince(now)
        if diff <= 0 { return 0 }
        return Int(diff.rounded(.up))
    }

    /// 残りが 0 以下なら次の局面へ進めた状態を返す。
    /// バックグラウンドで複数局面をまたいだ場合も、追いつくまで繰り返し進める。
    static func advancedIfNeeded(state: PomodoroState, now: Date) -> PomodoroState {
        var current = state
        // 異常な設定値(0分など)で無限ループにならないよう上限を設ける
        var steps = 0
        while remainingSeconds(now: now, state: current) <= 0 && steps < 1000 {
            steps += 1
            current = advancedOnce(state: current)
        }
        return current
    }

    /// 強制的に次の局面へ(スキップ)。
    /// 作業をスキップした場合は、その局面で経過した秒だけを累計に足す。
    /// サイクルは1つ消化した扱いにする(「サイクル 1/4」がスキップで 0 に戻って見えないように。
    /// 長い休憩の判定も通常完了と同じ規則に従う)。
    static func skip(state: PomodoroState, now: Date) -> PomodoroState {
        var next = state
        switch state.phase {
        case .work:
            next.accumulatedWorkSeconds += elapsedInPhase(now: now, state: state)
            next.completedWorkCycles += 1
            let cycles = max(1, state.settings.cyclesBeforeLongBreak)
            if next.completedWorkCycles % cycles == 0 {
                next.phase = .longBreak
                next.phaseDurationSeconds = seconds(minutes: state.settings.longBreakMinutes)
            } else {
                next.phase = .shortBreak
                next.phaseDurationSeconds = seconds(minutes: state.settings.breakMinutes)
            }
        case .shortBreak, .longBreak:
            next.phase = .work
            next.phaseDurationSeconds = seconds(minutes: state.settings.workMinutes)
        }
        next.phaseStartedAt = now
        return next
    }

    /// 記録に使う作業秒。休憩中は完了済みの累計だけを返す。
    static func workSeconds(now: Date, state: PomodoroState) -> Int {
        guard state.phase == .work else { return state.accumulatedWorkSeconds }
        return state.accumulatedWorkSeconds + elapsedInPhase(now: now, state: state)
    }

    // MARK: - 内部

    /// 次の局面へ 1 つだけ進める。
    /// 次局面の開始時刻は実時刻ではなく前局面の終了予定時刻にして、遅れが累積しないようにする。
    private static func advancedOnce(state: PomodoroState) -> PomodoroState {
        var next = state
        let endDate = phaseEndDate(state: state)
        switch state.phase {
        case .work:
            next.accumulatedWorkSeconds += state.phaseDurationSeconds
            next.completedWorkCycles += 1
            let cycles = max(1, state.settings.cyclesBeforeLongBreak)
            if next.completedWorkCycles % cycles == 0 {
                next.phase = .longBreak
                next.phaseDurationSeconds = seconds(minutes: state.settings.longBreakMinutes)
            } else {
                next.phase = .shortBreak
                next.phaseDurationSeconds = seconds(minutes: state.settings.breakMinutes)
            }
        case .shortBreak, .longBreak:
            next.phase = .work
            next.phaseDurationSeconds = seconds(minutes: state.settings.workMinutes)
        }
        next.phaseStartedAt = endDate
        return next
    }

    /// 現局面で経過した秒(0 以上、局面の長さが上限)
    private static func elapsedInPhase(now: Date, state: PomodoroState) -> Int {
        let elapsed = Int(now.timeIntervalSince(state.phaseStartedAt))
        return min(max(0, elapsed), state.phaseDurationSeconds)
    }

    /// 分を秒へ。0 以下の設定値でも局面が止まらないよう最低 1 秒にする。
    private static func seconds(minutes: Int) -> Int {
        max(1, minutes * 60)
    }
}
