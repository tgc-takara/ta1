import Foundation

/// 「今週」の区切り(週の始まり)。UserDefaults に firstWeekday の値で保存する。
enum WeekStart: Int, CaseIterable, Identifiable {
    case system = 0   // iOS の地域設定に従う
    case sunday = 1
    case monday = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .system: "システム設定に従う"
        case .sunday: "日曜日"
        case .monday: "月曜日"
        }
    }

    static let userDefaultsKey = "weekFirstWeekday"

    /// 未設定・不明値は .system
    static func load() -> WeekStart {
        let raw = UserDefaults.standard.integer(forKey: userDefaultsKey)
        return WeekStart(rawValue: raw) ?? .system
    }

    static func save(_ start: WeekStart) {
        UserDefaults.standard.set(start.rawValue, forKey: userDefaultsKey)
    }
}

/// アプリ全体で使うカレンダー。週の始まりだけ設定で上書きする。
enum AppCalendar {
    static var current: Calendar {
        var calendar = Calendar.current
        let start = WeekStart.load()
        if start != .system {
            calendar.firstWeekday = start.rawValue
        }
        return calendar
    }
}
