import Foundation

/// 記録フォームの時間プリセット(分・UserDefaults 保存)。
/// IntervalTimerPresets と同じパターン。記録フォーム(SessionFormView)と
/// 設定画面(DurationPresetSettingsView)で共有する。
enum DurationPresets {
    static let userDefaultsKey = "durationPresets"
    /// 既定値。保存値が未設定/空のときに使う
    static let defaultValues: [Int] = [5, 10, 15, 30, 45, 60]

    /// 保存済みプリセットを昇順で読み込む。未設定または空配列なら既定値を返す。
    static func load() -> [Int] {
        guard let saved = UserDefaults.standard.array(forKey: userDefaultsKey) as? [Int], !saved.isEmpty else {
            return defaultValues
        }
        return saved.sorted()
    }

    static func save(_ presets: [Int]) {
        UserDefaults.standard.set(presets, forKey: userDefaultsKey)
    }
}
