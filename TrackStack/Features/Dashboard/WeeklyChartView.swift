import SwiftUI
import Charts

/// カテゴリ別積み上げ棒グラフの本体。日数・終了日・カレンダーをパラメータ化し、
/// ホームの「直近7日」とウィークリー振り返りの「対象週7日」の両方から再利用する。
struct DailyStackedChart: View {
    let sessions: [Session]
    var days: Int = 7
    var endingOn: Date = Date()
    var calendar: Calendar = .current
    /// 設定で表示オンにしているカテゴリ(親から渡して設定変更を反映させる)
    var enabledCategories: [ActivityCategory] = EnabledCategories.load()

    private var daily: [(date: Date, minutesByCategory: [ActivityCategory: Int])] {
        StatsCalculator.dailyMinutes(sessions, days: days, endingOn: endingOn, calendar: calendar)
    }

    /// グラフ表示用にフラット化したデータ点(日 × カテゴリ)
    private struct DataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let category: ActivityCategory
        let minutes: Int
    }

    /// 表示するカテゴリ(設定でオフでも、期間内に記録があるものは合計が合わなくなるので含める)
    private var visibleCategories: [ActivityCategory] {
        let totals = daily.reduce(into: [ActivityCategory: Int]()) { result, entry in
            for (category, minutes) in entry.minutesByCategory {
                result[category, default: 0] += minutes
            }
        }
        return EnabledCategories.forDisplay(minutes: totals, enabled: enabledCategories)
    }

    private var points: [DataPoint] {
        let categories = visibleCategories
        return daily.flatMap { entry in
            categories.map { category in
                DataPoint(date: entry.date, category: category, minutes: entry.minutesByCategory[category] ?? 0)
            }
        }
    }

    private var hasAnyRecord: Bool {
        daily.contains { $0.minutesByCategory.values.contains { $0 > 0 } }
    }

    var body: some View {
        Group {
            if hasAnyRecord {
                Chart(points) { point in
                    BarMark(
                        x: .value("日付", point.date, unit: .day),
                        y: .value("分", point.minutes)
                    )
                    .foregroundStyle(by: .value("カテゴリ", point.category.label))
                }
                .chartForegroundStyleScale(
                    domain: visibleCategories.map(\.label),
                    range: visibleCategories.map(\.color)
                )
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day(), centered: true)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let minutes = value.as(Int.self) {
                                Text("\(minutes)分")
                            }
                        }
                    }
                }
                .frame(height: 180)
                // 軸ラベルはグラフの限られた幅に収める必要があるため、Dynamic Type の拡大上限を
                // 標準サイズの最大(xxxLarge)までに制限する(アクセシビリティ文字サイズで7日分の
                // 日付ラベルが重なって判読不能になるのを防ぐ)。カード見出しなど他のテキストは
                // このスコープ外なので通常どおり拡大される
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            } else {
                Text("まだ記録がありません")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            }
        }
    }
}

/// 直近7日間(今日を最終日)のカテゴリ別積み上げ棒グラフ。ホーム専用のカード見出し付きラッパー。
struct WeeklyChartView: View {
    let sessions: [Session]
    /// 設定で表示オンにしているカテゴリ(親から渡して設定変更を反映させる)
    var enabledCategories: [ActivityCategory] = EnabledCategories.load()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("直近7日の推移")
                .font(.headline)

            DailyStackedChart(sessions: sessions, enabledCategories: enabledCategories)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle()
    }
}
