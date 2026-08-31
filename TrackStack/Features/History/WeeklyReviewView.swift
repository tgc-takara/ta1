import SwiftUI

/// 記録タブの「ウィークリー」表示。週単位の振り返りカードを表示し、週送りで過去に遡れる。
/// 親の ScrollView 内に置く前提で、自前の ScrollView は持たない(MonthCalendarView と同じ流儀)。
struct WeeklyReviewView: View {
    let sessions: [Session]

    /// 0=今週、-1=先週…
    @State private var weekOffset: Int = 0
    @State private var appCalendar: Calendar = AppCalendar.current
    @State private var enabledCategories: [ActivityCategory] = EnabledCategories.load()
    @State private var weeklyTargets: [ActivityCategory: Int] = WeeklyTargets.load()

    /// 対象週のアンカー日
    private var anchorDate: Date {
        appCalendar.date(byAdding: .weekOfYear, value: weekOffset, to: Date()) ?? Date()
    }

    private var weekInterval: DateInterval? {
        appCalendar.dateInterval(of: .weekOfYear, for: anchorDate)
    }

    private var weekSessions: [Session] {
        StatsCalculator.sessionsInWeek(sessions, of: anchorDate, calendar: appCalendar)
    }

    private var totalMinutes: Int {
        StatsCalculator.totalMinutes(weekSessions)
    }

    /// 最古のセッションが属する週の開始日(sessions が空なら nil = 週送り無制限を防ぐため0固定扱い)
    private var oldestWeekStart: Date? {
        guard let oldest = sessions.map(\.startedAt).min() else { return nil }
        return appCalendar.dateInterval(of: .weekOfYear, for: oldest)?.start
    }

    /// これ以上過去に戻れないか(最古週に達しているか)
    private var isAtOldestWeek: Bool {
        guard let oldestWeekStart, let currentStart = weekInterval?.start else { return true }
        return currentStart <= oldestWeekStart
    }

    private var recordedDayCount: Int {
        Set(weekSessions.map { appCalendar.startOfDay(for: $0.startedAt) }).count
    }

    var body: some View {
        VStack(spacing: 16) {
            weekNav
            reviewCard
            SNSShareButtons()
        }
        .padding()
        .onAppear {
            appCalendar = AppCalendar.current
            enabledCategories = EnabledCategories.load()
            weeklyTargets = WeeklyTargets.load()
        }
    }

    // MARK: - 週送りナビ

    private var weekNav: some View {
        HStack {
            Button {
                weekOffset -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(sessions.isEmpty || isAtOldestWeek)

            Spacer()

            VStack(spacing: 2) {
                if let weekInterval {
                    Text(Formatters.weekRange(weekInterval))
                        .font(.headline)
                }
                if weekOffset == 0 {
                    Text("今週")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                } else if weekOffset == -1 {
                    Text("先週")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }

            Spacer()

            Button {
                weekOffset += 1
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(weekOffset == 0)
        }
    }

    // MARK: - 振り返りカード(スクショ対象)

    private var reviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                if let weekInterval {
                    Text(Formatters.weekRange(weekInterval))
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
                Text("ひとつみ")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }

            Text(Formatters.duration(minutes: totalMinutes))
                .font(.mincho(size: 40))
                .fontDesign(.serif)
                .monospacedDigit()
                .foregroundStyle(Theme.ink)

            categoryBreakdown

            weeklyTargetProgress

            if let weekInterval {
                let lastDay = weekInterval.end.addingTimeInterval(-1)
                DailyStackedChart(
                    sessions: sessions,
                    days: 7,
                    endingOn: lastDay,
                    calendar: appCalendar,
                    enabledCategories: enabledCategories
                )
            }

            Text("記録した日 \(recordedDayCount)/7日")
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)

            Text("今日も、ひとつ積もう。")
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle()
    }

    /// カテゴリ別の内訳。DashboardView.categoryBreakdown と同じ3列グリッド表示。
    private var categoryBreakdown: some View {
        let minutes = StatsCalculator.minutesByCategory(weekSessions)
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3),
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(EnabledCategories.forDisplay(minutes: minutes, enabled: enabledCategories)) { category in
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(category.color)
                        .frame(width: 3, height: 14)
                    Image(systemName: category.symbolName)
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSecondary)
                    Text(Formatters.duration(minutes: minutes[category] ?? 0))
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }

    /// 週の目標時間を設定したカテゴリだけ、実績との進捗を表示する。1件もなければ何も出さない。
    /// DashboardView.weeklyTargetProgress と同等(過去週でも表示する)。
    @ViewBuilder
    private var weeklyTargetProgress: some View {
        let targetedCategories = ActivityCategory.allCases.filter { (weeklyTargets[$0] ?? 0) > 0 }
        if !targetedCategories.isEmpty {
            let minutes = StatsCalculator.minutesByCategory(weekSessions)
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                ForEach(targetedCategories) { category in
                    let actual = minutes[category] ?? 0
                    let target = weeklyTargets[category] ?? 0
                    let achieved = actual >= target
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: category.symbolName)
                                .foregroundStyle(category.color)
                                .font(.caption)
                            Text(category.label)
                                .font(.caption)
                                .foregroundStyle(Theme.inkSecondary)
                            Spacer()
                            Text("\(Formatters.duration(minutes: actual)) / \(Formatters.duration(minutes: target))")
                                .font(.caption.monospacedDigit())
                                .fontWeight(achieved ? .bold : .regular)
                                .foregroundStyle(achieved ? category.color : Theme.inkSecondary)
                        }
                        ProgressView(value: min(Double(actual), Double(target)), total: Double(target))
                            .tint(category.color)
                    }
                }
            }
        }
    }
}
