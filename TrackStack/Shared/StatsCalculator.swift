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

    /// endingOn を最終日として days 日分(古い順)のカテゴリ別分数を返す。
    /// 記録がない日も 0 で埋めて含める(グラフの歯抜け防止)。
    static func dailyMinutes(
        _ sessions: [Session],
        days: Int,
        endingOn: Date,
        calendar: Calendar = .current
    ) -> [(date: Date, minutesByCategory: [ActivityCategory: Int])] {
        let endDay = calendar.startOfDay(for: endingOn)
        guard days > 0 else { return [] }

        // 日ごとにセッションをグルーピングしておく
        let grouped = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.startedAt) }

        var result: [(date: Date, minutesByCategory: [ActivityCategory: Int])] = []
        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: endDay) else { continue }
            let daySessions = grouped[day] ?? []
            result.append((date: day, minutesByCategory: minutesByCategory(daySessions)))
        }
        return result
    }

    /// 指定月に含まれるセッションを日(startOfDay)ごとに合計分。カレンダーの濃淡表示用。
    static func minutesByDay(
        _ sessions: [Session],
        in month: Date,
        calendar: Calendar = .current
    ) -> [Date: Int] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [:] }
        let monthSessions = sessions.filter { monthInterval.contains($0.startedAt) }
        return monthSessions.reduce(into: [:]) { result, session in
            let day = calendar.startOfDay(for: session.startedAt)
            result[day, default: 0] += session.durationMinutes
        }
    }

    /// 指定月に含まれるセッションを日ごとに集計し、その日の合計分が最大のカテゴリを返す。
    /// 同値のときは ActivityCategory.allCases の順で先勝ち(決定的)。
    static func dominantCategoryByDay(
        _ sessions: [Session],
        in month: Date,
        calendar: Calendar = .current
    ) -> [Date: ActivityCategory] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [:] }
        let monthSessions = sessions.filter { monthInterval.contains($0.startedAt) }
        let grouped = Dictionary(grouping: monthSessions) { calendar.startOfDay(for: $0.startedAt) }

        return grouped.reduce(into: [:]) { result, entry in
            let (day, daySessions) = entry
            let minutes = minutesByCategory(daySessions)
            let dominant = ActivityCategory.allCases
                .compactMap { category -> (ActivityCategory, Int)? in
                    guard let value = minutes[category] else { return nil }
                    return (category, value)
                }
                .max { $0.1 < $1.1 }
            if let dominant {
                result[day] = dominant.0
            }
        }
    }
}
