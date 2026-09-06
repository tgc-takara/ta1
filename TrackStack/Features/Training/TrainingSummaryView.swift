import SwiftUI
import SwiftData

/// トレーニング終了後に出す、その日のまとめ画面。
/// スクリーンショットを撮ってSNSに貼れるよう、カード1枚に収まるレイアウトにする。
struct TrainingSummaryView: View {
    /// このまとめの対象日(終了時刻の属する日)
    let date: Date

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Session.startedAt) private var sessions: [Session]

    /// その日のトレーニング記録(1日に複数回やった場合もまとめて1枚にする)
    private var todayTraining: [Session] {
        StatsCalculator.sessions(sessions, on: date)
            .filter { $0.category == .training }
            .sorted { $0.startedAt < $1.startedAt }
    }

    private var totalMinutes: Int {
        StatsCalculator.totalMinutes(todayTraining)
    }

    /// 種目ごとにセットをまとめた表示用の行
    private var exerciseLines: [(name: String, bodyPart: BodyPart, detail: String)] {
        todayTraining
            .flatMap { $0.exerciseLogs }
            .sorted { $0.order < $1.order }
            .map { log in
                (name: log.exerciseName, bodyPart: log.bodyPart, detail: log.summaryDetail)
            }
    }

    private var endedAt: Date {
        todayTraining
            .map { $0.startedAt.addingTimeInterval(TimeInterval($0.durationMinutes * 60)) }
            .max() ?? date
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summaryCard
                    SNSShareButtons()
                }
                .padding()
            }
            .background(Theme.paper)
            .navigationTitle("今日のひとつみ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    // MARK: - まとめカード(スクショ対象)

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(Formatters.dayHeader(date))
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
                BrandMark()
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: ActivityCategory.training.symbolName)
                    .foregroundStyle(ActivityCategory.training.color)
                Text(Formatters.duration(minutes: totalMinutes))
                    .font(.mincho(size: 40))
                    .fontDesign(.serif)
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(Formatters.time(endedAt)) 終了")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }

            if exerciseLines.isEmpty {
                Text("種目の記録はありません")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(exerciseLines.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: line.bodyPart.symbolName)
                                .font(.caption)
                                .foregroundStyle(line.bodyPart.color)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(line.name)
                                    .font(.subheadline)
                                if !line.detail.isEmpty {
                                    Text(line.detail)
                                        .font(.caption)
                                        .foregroundStyle(Theme.inkSecondary)
                                }
                            }
                            Spacer()
                        }
                    }
                }
            }

            Text("今日も、ひとつ積もう。")
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle()
    }
}
