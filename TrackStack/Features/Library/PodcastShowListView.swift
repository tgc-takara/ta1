import SwiftUI
import SwiftData

/// ポッドキャスト番組の一覧(累積再生時間・エピソード数付き)
struct PodcastShowListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PodcastShow.createdAt, order: .reverse) private var shows: [PodcastShow]

    @State private var showingAdd = false
    @State private var editingShow: PodcastShow?

    var body: some View {
        Group {
            if shows.isEmpty {
                ContentUnavailableView(
                    "番組がありません",
                    systemImage: "headphones",
                    description: Text("右上の + から番組を追加できます")
                )
            } else {
                List {
                    ForEach(shows) { show in
                        PodcastShowRowView(show: show)
                            .contentShape(Rectangle())
                            .onTapGesture { editingShow = show }
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
                    Text("\(show.sessions.count)エピソード")
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

/// 番組の追加・編集フォーム。編集時は聴いた履歴(セッション由来)も表示する。
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
                    TextField("番組名", text: $name)
                    if let show = showToEdit {
                        LabeledContent(
                            "再生時間",
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
                        Button("この番組を削除", role: .destructive) {
                            showingDeleteConfirm = true
                        }
                    }
                }
            }
            .navigationTitle(showToEdit == nil ? "番組を追加" : "番組を編集")
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
            .confirmationDialog("この番組を削除しますか?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    if let show = showToEdit {
                        context.delete(show)
                    }
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("聴いた記録は残り、番組との紐付けだけが外れます")
            }
        }
    }

    /// 聴いた記録(記録タブで追加したセッション)の履歴。表示専用。
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
            Text("聴いた記録")
        } footer: {
            Text("記録タブでこの番組を選んで追加した記録がここに蓄積されます")
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
