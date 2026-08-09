import SwiftUI

/// 履歴・ダッシュボード共通のセッション 1 行表示
struct SessionRowView: View {
    let session: Session

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.category.symbolName)
                .foregroundStyle(session.category.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatters.duration(minutes: session.durationMinutes))
                    .font(.subheadline.bold())
                Text(Formatters.timeRange(start: session.startedAt, minutes: session.durationMinutes))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var title: String {
        switch session.category {
        case .reading:
            return session.book?.title ?? "読書"
        case .training:
            return session.menuName ?? "トレーニング"
        case .study:
            return session.subject?.name ?? "勉強"
        }
    }

    /// カテゴリ固有の補足行(進捗% / 種目名)。なければメモを表示。
    private var subtitle: String? {
        switch session.category {
        case .reading:
            if let percent = session.progressPercent {
                return "進捗 \(percent)%"
            }
        case .training:
            let names = session.exerciseLogs
                .sorted { $0.order < $1.order }
                .map(\.exerciseName)
            if !names.isEmpty {
                return names.joined(separator: "・")
            }
        case .study:
            break
        }
        if let note = session.note, !note.isEmpty {
            return note
        }
        return nil
    }
}
