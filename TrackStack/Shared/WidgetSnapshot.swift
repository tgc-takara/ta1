import Foundation

/// ホーム画面ウィジェットに渡す「今日の積み上げ」のスナップショット。
/// アプリ本体とウィジェット拡張の両ターゲットに含める共有ファイル。
///
/// ウィジェット拡張から SwiftData のストアを直接読むのは避け、
/// アプリ側が App Group の UserDefaults に書き込んだ値だけをウィジェットが読む。
struct WidgetSnapshot: Codable, Equatable {
    /// 集計対象の日(その日の 0:00)。ウィジェット側で「今日のものか」を判定する
    var date: Date
    var totalMinutes: Int
    /// ActivityCategory.rawValue をキーにしたカテゴリ別分数
    var minutesByCategory: [String: Int]
    var streak: Int

    static let suiteName = "group.com.taguchi.TrackStack"
    static let key = "widgetSnapshot"

    /// App Groups が使えない環境(署名に entitlement が付いていない等)では
    /// UserDefaults(suiteName:) が nil を返す。その場合は standard に退避して落とさない。
    /// (このときウィジェットからは読めないが、アプリは正常に動く)
    static var store: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func load() -> WidgetSnapshot? {
        guard let data = store.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.store.set(data, forKey: Self.key)
    }
}
