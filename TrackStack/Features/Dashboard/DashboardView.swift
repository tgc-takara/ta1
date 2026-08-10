import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]
    @State private var showingRecordSheet = false
    @State private var activeTimer = ActiveTimer()
    @State private var showingTimerSheet = false
    @State private var pendingTimerResult: PendingTimerResult?

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
                    WeeklyChartView(sessions: sessions)
                    if !todaySessions.isEmpty {
                        recentSection
                    }
                }
                .padding()
            }
            .navigationTitle("つみき")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(ActivityCategory.allCases) { category in
                            Button {
                                activeTimer.start(category: category)
                                showingTimerSheet = true
                            } label: {
                                Label(category.label, systemImage: category.symbolName)
                            }
                        }
                    } label: {
                        Label("タイマー開始", systemImage: "timer")
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
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
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
                        .foregroundStyle(.orange)
                }
            }

            Text(Formatters.duration(minutes: todaySessions.reduce(0) { $0 + $1.durationMinutes }))
                .font(.system(size: 40, weight: .bold, design: .rounded))

            categoryBreakdown(StatsCalculator.minutesByCategory(todaySessions))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今週")
                .font(.headline)
            Text(Formatters.duration(minutes: weekSessions.reduce(0) { $0 + $1.durationMinutes }))
                .font(.title2.bold())
            categoryBreakdown(StatsCalculator.minutesByCategory(weekSessions))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func categoryBreakdown(_ minutes: [ActivityCategory: Int]) -> some View {
        HStack(spacing: 12) {
            ForEach(ActivityCategory.allCases) { category in
                HStack(spacing: 4) {
                    Image(systemName: category.symbolName)
                        .foregroundStyle(category.color)
                    Text(Formatters.duration(minutes: minutes[category] ?? 0))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
