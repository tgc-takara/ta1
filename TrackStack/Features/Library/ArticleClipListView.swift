import SwiftUI
import SwiftData

/// 記事の記録(新聞・Web記事・レポート)に紐づくクリップを、読んだ日ごとにまとめて一覧する。
/// クリップの追加は記録側(記録を追加 → 新聞)で行い、ここでは閲覧と削除だけを担う。
struct ArticleClipListView: View {
    @Environment(\.modelContext) private var context
    @Query private var clips: [ArticleClip]

    /// 読んだ日(セッションの開始日)ごとにグルーピング。新しい日が先頭。
    private var grouped: [(day: Date, clips: [ArticleClip])] {
        let calendar = Calendar.current
        let dated = clips.compactMap { clip -> (Date, ArticleClip)? in
            guard let startedAt = clip.session?.startedAt else { return nil }
            return (calendar.startOfDay(for: startedAt), clip)
        }
        let dict = Dictionary(grouping: dated, by: \.0)
        return dict.keys.sorted(by: >).map { day in
            let dayClips = (dict[day] ?? [])
                .map(\.1)
                .sorted { $0.order < $1.order }
            return (day: day, clips: dayClips)
        }
    }

    var body: some View {
        Group {
            if grouped.isEmpty {
                ContentUnavailableView(
                    "クリップした記事がありません",
                    systemImage: "newspaper",
                    description: Text("記録を追加 → 記事 から、読んだ記事をクリップできます")
                )
            } else {
                List {
                    ForEach(grouped, id: \.day) { group in
                        Section {
                            ForEach(group.clips) { clip in
                                ArticleClipRowView(clip: clip)
                                    .listRowBackground(Theme.surface)
                            }
                            .onDelete { offsets in
                                for index in offsets {
                                    context.delete(group.clips[index])
                                }
                            }
                        } header: {
                            Text(Formatters.dayHeader(group.day))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.paper)
    }
}

struct ArticleClipRowView: View {
    let clip: ArticleClip

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let url = clip.url {
                Link(destination: url) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(clip.title)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                    }
                }
                .foregroundStyle(ActivityCategory.article.color)
            } else {
                Text(clip.title)
                    .font(.body)
            }

            if let memo = clip.memo, !memo.isEmpty {
                Text(memo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
