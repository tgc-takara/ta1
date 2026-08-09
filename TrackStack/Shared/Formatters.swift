import Foundation

enum Formatters {
    /// 90 → 「1時間30分」、45 → 「45分」
    static func duration(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        switch (h, m) {
        case (0, _): return "\(m)分"
        case (_, 0): return "\(h)時間"
        default: return "\(h)時間\(m)分"
        }
    }

    static func dayHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: date)
    }

    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "H:mm"
        return formatter.string(from: date)
    }

    /// 開始時刻と所要分から「22:58〜23:13」形式の時間帯を返す
    static func timeRange(start: Date, minutes: Int) -> String {
        let end = start.addingTimeInterval(TimeInterval(minutes * 60))
        return "\(time(start))〜\(time(end))"
    }
}
