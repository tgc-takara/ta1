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

    /// 秒数を「H:MM:SS」形式に整形する(タイマー表示用)
    static func elapsedClock(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }

    /// 秒数を「M:SS」形式に整形する(インターバルタイマーのカウントダウン表示用)
    /// 90 → "1:30"、5 → "0:05"
    static func countdownClock(seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    /// 週の DateInterval を「M/d〜M/d」形式に整形する。
    /// interval.end は翌週の開始(排他的境界)なので、表示上の最終日は1日前にする。
    static func weekRange(_ interval: DateInterval) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
        let lastDay = interval.end.addingTimeInterval(-1)
        return "\(formatter.string(from: interval.start))〜\(formatter.string(from: lastDay))"
    }

    /// インターバルタイマーのプリセット秒数を人が読みやすい形式に整形する。
    /// 45 → "45秒"、120 → "2分"、90 → "1分30秒"
    static func presetLabel(seconds: Int) -> String {
        guard seconds >= 60 else { return "\(seconds)秒" }
        let m = seconds / 60
        let s = seconds % 60
        return s == 0 ? "\(m)分" : "\(m)分\(s)秒"
    }
}
