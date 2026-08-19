import Foundation

/// カテゴリ別の週の目標時間(分)。設定画面で登録した値をホームの今週カードの進捗表示に使う。
enum WeeklyTargets {
    static let userDefaultsKey = "weeklyTargetMinutes"

    /// カテゴリ別の目標分数。未設定のカテゴリはエントリなし。
    static func load() -> [ActivityCategory: Int] {
        guard let raw = UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: Int] else {
            return [:]
        }
        // 旧カテゴリ("newspaper" / "podcast")や不明なキーが混ざっていても無視して読む。
        return raw.reduce(into: [:]) { result, entry in
            guard let category = ActivityCategory(rawValue: entry.key) ?? ActivityCategory.legacyRawValues[entry.key] else {
                return
            }
            result[category] = entry.value
        }
    }

    /// 0以下の値は「目標なし」としてエントリごと削除して保存する
    static func save(_ targets: [ActivityCategory: Int]) {
        let raw = targets.reduce(into: [String: Int]()) { result, entry in
            guard entry.value > 0 else { return }
            result[entry.key.rawValue] = entry.value
        }
        UserDefaults.standard.set(raw, forKey: userDefaultsKey)
    }
}
