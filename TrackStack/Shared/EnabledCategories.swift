import Foundation

/// 表示するカテゴリの設定。設定画面でオフにしたカテゴリは
/// 記録の選択肢・ライブラリ・内訳から消える(既存の記録は消えない)。
enum EnabledCategories {
    static let userDefaultsKey = "enabledCategories"

    /// 有効なカテゴリ。未設定なら全カテゴリ(既定は全部表示)。
    /// 並びは常に ActivityCategory.allCases の順に揃える。
    static func load() -> [ActivityCategory] {
        guard let raws = UserDefaults.standard.stringArray(forKey: userDefaultsKey) else {
            return ActivityCategory.allCases
        }
        // 廃止したカテゴリ名など、いまはないキーは読み捨てる
        let enabled = Set(raws.compactMap(ActivityCategory.init(rawValue:)))
        // 全部オフになってしまった状態は選択不能になるため、既定に戻す
        guard !enabled.isEmpty else { return ActivityCategory.allCases }
        return ActivityCategory.allCases.filter(enabled.contains)
    }

    static func save(_ categories: [ActivityCategory]) {
        UserDefaults.standard.set(categories.map(\.rawValue), forKey: userDefaultsKey)
    }

    /// 集計表示用のカテゴリ。オフにしていても、その期間に記録があるカテゴリは
    /// 合計と内訳が合わなくなるため表示に含める。
    /// `enabled` を渡さない場合は保存値をその場で読む。
    static func forDisplay(
        minutes: [ActivityCategory: Int],
        enabled: [ActivityCategory]? = nil
    ) -> [ActivityCategory] {
        let enabledSet = Set(enabled ?? load())
        return ActivityCategory.allCases.filter { category in
            enabledSet.contains(category) || (minutes[category] ?? 0) > 0
        }
    }

    /// 記録フォームで選べるカテゴリ。編集中の記録が非表示カテゴリでも
    /// 選択肢から消えてしまわないよう、必ず含める。
    static func forPicker(including current: ActivityCategory?) -> [ActivityCategory] {
        var enabled = Set(load())
        if let current { enabled.insert(current) }
        return ActivityCategory.allCases.filter(enabled.contains)
    }
}
