import SwiftUI
import SwiftData

/// 種目ごとのトレーニング履歴。ライブラリで種目をタップすると開く。
/// 記録は Session + ExerciseLog に入っているため、種目名で拾って日付順に並べる。
struct ExerciseHistoryView: View {
    let exerciseName: String
    let bodyPart: BodyPart

    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]

    /// この種目を含む記録(新しい順)
    private var entries: [(date: Date, log: ExerciseLog)] {
        sessions
            .filter { $0.category == .training }
            .flatMap { session in
                session.exerciseLogs
                    .filter { $0.exerciseName == exerciseName }
                    .map { (date: session.startedAt, log: $0) }
            }
            .sorted { $0.date > $1.date }
    }

    /// 記録した中での最大重量(片手・マイナス重量も含めた素の最大値)
    private var maxWeight: Double? {
        let weights = entries.flatMap { $0.log.sets.map(\.weightKg) }
        return weights.max()
    }

    /// 総ボリューム(重量 × 回数の合計)。負荷の推移をざっくり見るための目安。
    private var totalVolume: Double {
        entries.reduce(0) { sum, entry in
            sum + entry.log.sets.reduce(0) { $0 + $1.weightKg * Double($1.reps) }
        }
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "まだ記録がありません",
                    systemImage: bodyPart.symbolName,
                    description: Text("記録タブでこの種目を追加すると、ここに履歴が並びます")
                )
            } else {
                List {
                    summarySection
                    historySection
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.paper)
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summarySection: some View {
        Section {
            LabeledContent("記録した回数", value: "\(entries.count)回")
            if let maxWeight, !bodyPart.isCardio {
                LabeledContent("最高重量", value: "\(Self.formatWeight(maxWeight))kg")
            }
            if !bodyPart.isCardio, totalVolume != 0 {
                LabeledContent("総ボリューム", value: "\(Self.formatWeight(totalVolume))kg")
            }
        } header: {
            Label(bodyPart.label, systemImage: bodyPart.symbolName)
                .foregroundStyle(bodyPart.color)
        } footer: {
            if !bodyPart.isCardio {
                Text("総ボリュームは 重量 × 回数 の合計です")
            }
        }
        .listRowBackground(Theme.surface)
    }

    private var historySection: some View {
        Section("履歴") {
            ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(Formatters.dayHeader(entry.date))
                            .font(.subheadline.bold())
                        Spacer()
                        Text(Formatters.time(entry.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.log.summaryDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
        .listRowBackground(Theme.surface)
    }

    /// 整数なら小数点を出さない
    static func formatWeight(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}
