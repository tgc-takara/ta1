import Foundation

/// 集計ロジック。UI から分離した純粋関数群(ユニットテスト対象)。
enum StatsCalculator {

    /// 継続日数(ストリーク)。
    /// 「今日または昨日」を起点に、記録のある日が何日連続しているかを返す。
    /// 今日まだ記録がなくても昨日まで連続していればストリークは維持される。
    static func streak(
        recordedDays: Set<Date>,
        today: Date,
        calendar: Calendar = .current
    ) -> Int {
        let todayStart = calendar.startOfDay(for: today)
        let normalized = Set(recordedDays.map { calendar.startOfDay(for: $0) })

        var anchor = todayStart
        if !normalized.contains(anchor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: anchor),
                  normalized.contains(yesterday) else { return 0 }
            anchor = yesterday
        }

        var count = 0
        var cursor = anchor
        while normalized.contains(cursor) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    /// カテゴリ別の合計分数
    static func minutesByCategory(_ sessions: [Session]) -> [ActivityCategory: Int] {
        sessions.reduce(into: [:]) { result, session in
            result[session.category, default: 0] += session.durationMinutes
        }
    }

    /// 指定日のセッションのみ抽出
    static func sessions(_ sessions: [Session], on day: Date, calendar: Calendar = .current) -> [Session] {
        sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
    }

    /// 指定日を含む週(週の開始曜日は calendar 設定に従う)のセッションのみ抽出
    static func sessionsInWeek(_ sessions: [Session], of day: Date, calendar: Calendar = .current) -> [Session] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: day) else { return [] }
        return sessions.filter { week.contains($0.startedAt) }
    }
}
