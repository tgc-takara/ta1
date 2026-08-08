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
                if let note = session.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatters.duration(minutes: session.durationMinutes))
                    .font(.subheadline.bold())
                Text(Formatters.time(session.startedAt))
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
}
