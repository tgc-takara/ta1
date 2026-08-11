import SwiftUI
import Charts

/// 直近7日間(今日を最終日)のカテゴリ別積み上げ棒グラフ。
struct WeeklyChartView: View {
    let sessions: [Session]

    private var daily: [(date: Date, minutesByCategory: [ActivityCategory: Int])] {
        StatsCalculator.dailyMinutes(sessions, days: 7, endingOn: Date())
    }

    /// グラフ表示用にフラット化したデータ点(日 × カテゴリ)
    private struct DataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let category: ActivityCategory
        let minutes: Int
    }

    private var points: [DataPoint] {
        daily.flatMap { entry in
            ActivityCategory.allCases.map { category in
                DataPoint(date: entry.date, category: category, minutes: entry.minutesByCategory[category] ?? 0)
            }
        }
    }

    private var hasAnyRecord: Bool {
        daily.contains { $0.minutesByCategory.values.contains { $0 > 0 } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今週の推移")
                .font(.headline)

            if hasAnyRecord {
                Chart(points) { point in
                    BarMark(
                        x: .value("日付", point.date, unit: .day),
                        y: .value("分", point.minutes)
                    )
                    .foregroundStyle(by: .value("カテゴリ", point.category.label))
                }
                .chartForegroundStyleScale([
                    ActivityCategory.reading.label: ActivityCategory.reading.color,
                    ActivityCategory.training.label: ActivityCategory.training.color,
                    ActivityCategory.study.label: ActivityCategory.study.color,
                ])
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle()
    }
}
