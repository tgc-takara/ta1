import Foundation

/// ポモドーロの長さの設定。設定画面で変更でき、ポモドーロ開始時にスナップショットされる
/// (進行中のタイマーは設定変更の影響を受けない)。
struct PomodoroSettings: Codable, Equatable {
    /// 作業局面の長さ(分)
    var workMinutes: Int = 25
    /// 休憩局面の長さ(分)
    var breakMinutes: Int = 5
    /// 長い休憩の長さ(分)
    var longBreakMinutes: Int = 15
    /// 何回作業したら長い休憩にするか
    var cyclesBeforeLongBreak: Int = 4

    static let userDefaultsKey = "pomodoroSettings"

    /// 保存済みの設定を読み込む。未設定またはデコードに失敗したら既定値を返す。
    static func load() -> PomodoroSettings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode(PomodoroSettings.self, from: data) else {
            return PomodoroSettings()
        }
        return decoded
    }

    static func save(_ settings: PomodoroSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
}
