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
    /// 計測中のカテゴリ(ActivityCategory.rawValue)。計測していなければ nil
    var activeCategoryRaw: String?
    /// 計測中の開始時刻。ウィジェットはここからの経過を Text(_:style:.timer) で表示する
    var activeStartedAt: Date?

    init(
        date: Date,
        totalMinutes: Int,
        minutesByCategory: [String: Int],
        streak: Int,
        activeCategoryRaw: String? = nil,
        activeStartedAt: Date? = nil
    ) {
        self.date = date
        self.totalMinutes = totalMinutes
        self.minutesByCategory = minutesByCategory
        self.streak = streak
        self.activeCategoryRaw = activeCategoryRaw
        self.activeStartedAt = activeStartedAt
    }

    private enum CodingKeys: String, CodingKey {
        case date, totalMinutes, minutesByCategory, streak, activeCategoryRaw, activeStartedAt
    }

    // 計測中の情報を持たない旧データも読めるように decodeIfPresent で補う
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.date = try container.decode(Date.self, forKey: .date)
        self.totalMinutes = try container.decode(Int.self, forKey: .totalMinutes)
        self.minutesByCategory = try container.decode([String: Int].self, forKey: .minutesByCategory)
        self.streak = try container.decode(Int.self, forKey: .streak)
        self.activeCategoryRaw = try container.decodeIfPresent(String.self, forKey: .activeCategoryRaw)
        self.activeStartedAt = try container.decodeIfPresent(Date.self, forKey: .activeStartedAt)
    }

    /// 計測中のカテゴリ。開始時刻とセットで揃っているときだけ有効とみなす。
    var activeCategory: ActivityCategory? {
        guard let activeCategoryRaw, activeStartedAt != nil else { return nil }
        return ActivityCategory(rawValue: activeCategoryRaw)
    }

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
