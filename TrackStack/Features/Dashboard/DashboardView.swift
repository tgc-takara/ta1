import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]
    @State private var showingRecordSheet = false

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
                    todayCard
                    weekCard
                    if !todaySessions.isEmpty {
                        recentSection
                    }
                }
                .padding()
            }
            .navigationTitle("TrackStack")
            .toolbar {
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
        }
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
