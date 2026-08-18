import SwiftUI

/// 履歴・ダッシュボード共通のセッション 1 行表示
struct SessionRowView: View {
    let session: Session

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(session.category.color)
                .frame(width: 3)

            Image(systemName: session.category.symbolName)
                .foregroundStyle(Theme.inkSecondary)
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
        case .article:
            return "記事"
        case .media:
            return session.podcastShow?.name ?? "動画・音声"
        }
    }

    /// カテゴリ固有の補足行(進捗% / 種目名)。なければメモを表示。
    private var subtitle: String? {
        switch session.category {
        case .reading:
            break
        case .training:
            let names = session.exerciseLogs
                .sorted { $0.order < $1.order }
                .map(\.exerciseName)
            if !names.isEmpty {
                return names.joined(separator: "・")
            }
        case .study:
            break
        case .article:
            let titles = session.articleClips
                .sorted { $0.order < $1.order }
                .map(\.displayTitle)
            if !titles.isEmpty {
                return titles.joined(separator: "・")
            }
        case .media:
            if let episode = session.episodeTitle, !episode.isEmpty {
                return episode
            }
        }
        if let note = session.note, !note.isEmpty {
            return note
        }
        return nil
    }
}
