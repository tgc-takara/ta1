import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]
    @State private var showingRecordSheet = false
    @State private var activeTimer = ActiveTimer()
    @State private var showingTimerSheet = false
    @State private var pendingTimerResult: PendingTimerResult?
    /// 設定で選んだ表示カテゴリ。設定画面から戻ったときに読み直す。
    @State private var enabledCategories: [ActivityCategory] = EnabledCategories.load()
    /// カテゴリ別の週の目標時間(分)。設定画面から戻ったときに読み直す。
    @State private var weeklyTargets: [ActivityCategory: Int] = WeeklyTargets.load()
    /// トレーニングは計測画面ではなく記録フォームを開く
    @State private var showingTrainingSheet = false
    @State private var trainingStartedAt = Date()
    @State private var trainingSummaryDate: TrainingSummaryDate?

    /// sheet(item:) で扱うための日付ラッパー
    private struct TrainingSummaryDate: Identifiable {
        let id = UUID()
        let date: Date
    }

    /// 「記録開始」から始める。トレーニングだけ記録フォーム、他はタイマー画面。
    private func start(_ category: ActivityCategory) {
        if category == .training {
            trainingStartedAt = Date()
            showingTrainingSheet = true
        } else {
            activeTimer.start(category: category)
            showingTimerSheet = true
        }
    }

    /// タイマー終了後、記録フォームへプリフィルする値。Identifiable にして sheet(item:) で扱う。
    private struct PendingTimerResult: Identifiable {
        let id = UUID()
        let category: ActivityCategory
        let startedAt: Date
        let durationMinutes: Int
    }

    private var todaySessions: [Session] {
        StatsCalculator.sessions(sessions, on: Date())
    }

    private var weekSessions: [Session] {
        StatsCalculator.sessionsInWeek(sessions, of: Date())
    }

    private var streak: Int {
        StatsCalculator.streak(
            recordedDays: Set(sessions.map(\.startedAt)),
            today: Date()
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if activeTimer.isRunning {
                        timerBanner
                    }
                    todayCard
                    weekCard
                    WeeklyChartView(sessions: sessions, enabledCategories: enabledCategories)
                    if !todaySessions.isEmpty {
                        recentSection
                    }
                }
                .padding()
            }
            .onAppear {
                enabledCategories = EnabledCategories.load()
                weeklyTargets = WeeklyTargets.load()
            }
            .background(Theme.paper)
            .navigationTitle("ひとつみ")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(enabledCategories) { category in
                            Button {
                                start(category)
                            } label: {
                                Label(category.label, systemImage: category.symbolName)
                            }
                        }
                    } label: {
                        Label("記録開始", systemImage: "timer")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingRecordSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingRecordSheet) {
                SessionFormView()
            }
            .sheet(isPresented: $showingTrainingSheet) {
                // トレーニングは計測しながら内容を書き込む運用なので、
                // タイマー画面ではなく記録フォームを開き、終了時に経過時間を実施時間にする
                SessionFormView(
                    initialCategory: .training,
                    initialStartedAt: trainingStartedAt,
                    isLiveTraining: true,
                    onFinishTraining: { finishedAt in
                        trainingSummaryDate = TrainingSummaryDate(date: finishedAt)
                    }
                )
            }
            .sheet(item: $trainingSummaryDate) { summary in
                TrainingSummaryView(date: summary.date)
            }
            .fullScreenCover(isPresented: $showingTimerSheet) {
                TimerView(activeTimer: activeTimer) { category, startedAt, durationMinutes in
                    pendingTimerResult = PendingTimerResult(
                        category: category,
                        startedAt: startedAt,
                        durationMinutes: durationMinutes
                    )
                }
            }
            .sheet(item: $pendingTimerResult) { result in
                SessionFormView(
                    initialCategory: result.category,
                    initialStartedAt: result.startedAt,
                    initialDurationMinutes: result.durationMinutes
                )
            }
        }
    }

    /// 計測中バナー。タップするとタイマー画面を再表示する(アプリ再起動後の復元経路)。
    private var timerBanner: some View {
        Button {
            showingTimerSheet = true
        } label: {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if let state = activeTimer.state, let category = activeTimer.category {
                    let elapsed = ActiveTimer.elapsedSeconds(now: context.date, state: state)
                    HStack {
                        Image(systemName: category.symbolName)
                            .foregroundStyle(category.color)
                        Text("計測中: \(category.label)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(Formatters.elapsedClock(seconds: elapsed))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .cardStyle()
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今日")
                    .font(.headline)
                Spacer()
                if streak > 0 {
                    Label("\(streak)日継続中", systemImage: "flame.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.ai)
                }
            }

            Text(Formatters.duration(minutes: todaySessions.reduce(0) { $0 + $1.durationMinutes }))
                .font(.mincho(size: 40))
                .fontDesign(.serif)
                .monospacedDigit()
                .foregroundStyle(Theme.ink)

            categoryBreakdown(StatsCalculator.minutesByCategory(todaySessions))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle()
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今週")
                .font(.headline)
            Text(Formatters.duration(minutes: weekSessions.reduce(0) { $0 + $1.durationMinutes }))
                .font(.mincho(size: 28))
                .fontDesign(.serif)
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
            categoryBreakdown(StatsCalculator.minutesByCategory(weekSessions))
            weeklyTargetProgress
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle()
    }

    /// 週の目標時間を設定したカテゴリだけ、実績との進捗を表示する。1件もなければ何も出さない。
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

    /// カテゴリ別の内訳。5カテゴリあるため1行に収めず3列グリッドで折り返す。
    private func categoryBreakdown(_ minutes: [ActivityCategory: Int]) -> some View {
        LazyVGrid(
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

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日の記録")
                .font(.headline)
            ForEach(todaySessions) { session in
                SessionRowView(session: session)
                    .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle()
    }
}
