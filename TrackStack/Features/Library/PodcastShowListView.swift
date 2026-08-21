import SwiftUI
import SwiftData

/// 動画・音声のシリーズ一覧(累積時間・本数付き)
struct PodcastShowListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PodcastShow.createdAt, order: .reverse) private var shows: [PodcastShow]

    @State private var showingAdd = false
    @State private var editingShow: PodcastShow?

    var body: some View {
        Group {
            if shows.isEmpty {
                ContentUnavailableView(
                    "シリーズがありません",
                    systemImage: "headphones",
                    description: Text("右上の + からシリーズを追加できます")
                )
            } else {
                List {
                    ForEach(shows) { show in
                        Button {
                            editingShow = show
                        } label: {
                            HStack {
                                PodcastShowRowView(show: show)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.surface)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            context.delete(shows[index])
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.paper)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            PodcastShowFormView()
        }
        .sheet(item: $editingShow) { show in
            PodcastShowFormView(showToEdit: show)
        }
    }
}

struct PodcastShowRowView: View {
    let show: PodcastShow

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(show.name)
                    .font(.body)
                if !show.sessions.isEmpty {
                    Text("\(show.sessions.count)本")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(Formatters.duration(minutes: StatsCalculator.totalMinutes(show.sessions)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}

/// シリーズの追加・編集フォーム。編集時は見聴きした履歴(セッション由来)も表示する。
struct PodcastShowFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let showToEdit: PodcastShow?

    @State private var name: String
    @State private var memo: String
    @State private var showingDeleteConfirm = false

    private static let episodeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d(E)"
        return formatter
    }()

    init(showToEdit: PodcastShow? = nil) {
        self.showToEdit = showToEdit
        _name = State(initialValue: showToEdit?.name ?? "")
        _memo = State(initialValue: showToEdit?.memo ?? "")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("シリーズ名", text: $name)
                    if let show = showToEdit {
                        LabeledContent(
                            "視聴時間",
                            value: Formatters.duration(minutes: StatsCalculator.totalMinutes(show.sessions))
                        )
                    }
                }

                Section("メモ") {
                    TextField("メモ(任意)", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let show = showToEdit {
                    episodeSection(of: show)

                    Section {
                        Button("このシリーズを削除", role: .destructive) {
                            showingDeleteConfirm = true
                        }
                    }
                }
            }
            .navigationTitle(showToEdit == nil ? "シリーズを追加" : "シリーズを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
            .confirmationDialog("このシリーズを削除しますか?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    if let show = showToEdit {
                        context.delete(show)
                    }
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("削除しても過去の記録は残ります(シリーズ名は記録側に残ります)")
            }
        }
    }

    /// 見聴きした記録(記録タブで追加したセッション)の履歴。表示専用。
    private func episodeSection(of show: PodcastShow) -> some View {
        let sessions = show.sessions.sorted { $0.startedAt > $1.startedAt }
        return Section {
            if sessions.isEmpty {
                Text("まだ記録がありません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sessions) { session in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(Self.episodeDateFormatter.string(from: session.startedAt))
                            Spacer()
                            Text(Formatters.duration(minutes: session.durationMinutes))
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)

                        if let episode = session.episodeTitle, !episode.isEmpty {
                            Text(episode)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("見聴きした記録")
        } footer: {
            Text("記録タブでこのシリーズを選んで追加した記録がここに蓄積されます")
        }
    }

    private func save() {
        let trimmedMemo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        if let show = showToEdit {
            show.name = trimmedName
            show.memo = trimmedMemo.nilIfEmpty
        } else {
            context.insert(PodcastShow(name: trimmedName, memo: trimmedMemo.nilIfEmpty))
        }
        dismiss()
    }
}
