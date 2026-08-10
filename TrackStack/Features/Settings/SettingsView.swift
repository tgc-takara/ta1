import SwiftUI
import SwiftData

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("マスタ") {
                    NavigationLink("読書ジャンル") {
                        BookGenreListView()
                    }
                    NavigationLink("トレーニングメニュー") {
                        TrainingMenuManageView()
                    }
                    NavigationLink("種目の管理") {
                        ExerciseManageView()
                    }
                    NavigationLink("勉強科目") {
                        SubjectManageView()
                    }
                    NavigationLink("インターバルタイマー") {
                        IntervalPresetSettingsView()
                    }
                }
                Section("データ") {
                    LabeledContent("エクスポート") {
                        Text("M5 で実装予定")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("このアプリ") {
                    LabeledContent("バージョン") {
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                    }
                }
            }
            .navigationTitle("設定")
        }
    }
}

/// 読書ジャンルのマスタ管理。ここで登録したジャンルが本の登録フォームの選択肢になる。
struct BookGenreListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \BookGenre.createdAt) private var genres: [BookGenre]

    @State private var newName = ""
    @State private var editingGenre: BookGenre?

    private var trimmedNewName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDuplicate: Bool {
        genres.contains { $0.name == trimmedNewName }
    }

    var body: some View {
        List {
            Section {
                if genres.isEmpty {
                    Text("ジャンルを登録すると、本の追加時に選択できます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(genres) { genre in
                    Button {
                        editingGenre = genre
                    } label: {
                        Text(genre.name)
                            .foregroundStyle(.primary)
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        context.delete(genres[index])
                    }
                }
            } footer: {
                if !genres.isEmpty {
                    Text("タップで編集、左スワイプで削除できます。ジャンルを削除しても、登録済みの本のジャンル表示は残ります")
                }
            }

            Section("新しいジャンル") {
                TextField("ジャンル名(例: ビジネス)", text: $newName)
                Button("追加") {
                    context.insert(BookGenre(name: trimmedNewName))
                    newName = ""
                }
                .disabled(trimmedNewName.isEmpty || isDuplicate)
            }
        }
        .navigationTitle("読書ジャンル")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingGenre) { genre in
            GenreEditFormView(genre: genre, existingGenres: genres)
        }
    }
}

/// 読書ジャンルの編集フォーム(名前・メモ・削除)。共通の編集シート形式に合わせる。
struct GenreEditFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let genre: BookGenre
    let existingGenres: [BookGenre]

    @State private var name: String
    @State private var memo: String
    @State private var showingDeleteConfirm = false

    init(genre: BookGenre, existingGenres: [BookGenre]) {
        self.genre = genre
        self.existingGenres = existingGenres
        _name = State(initialValue: genre.name)
        _memo = State(initialValue: genre.memo ?? "")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 空文字、または(自分以外の)既存ジャンル名と重複している場合は保存不可
    private var isInvalid: Bool {
        let trimmed = trimmedName
        if trimmed.isEmpty { return true }
        return existingGenres.contains { $0.id != genre.id && $0.name == trimmed }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("ジャンル名", text: $name)
                } footer: {
                    Text("ジャンル名を変更しても、登録済みの本のジャンル表示(登録時点の名前)は変わりません")
                }

                Section("メモ") {
                    TextField("メモ(任意)", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button("このジャンルを削除", role: .destructive) {
                        showingDeleteConfirm = true
                    }
                }
            }
            .navigationTitle("ジャンルを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        genre.name = trimmedName
                        genre.memo = memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : memo
                        dismiss()
                    }
                    .disabled(isInvalid)
                }
            }
            .confirmationDialog("このジャンルを削除しますか?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    context.delete(genre)
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("登録済みの本のジャンル表示は残ります")
            }
        }
    }
}

/// インターバルタイマーのプリセット秒数の管理。ここで追加・削除した値が
/// トレーニング記録画面のインターバルタイマー(IntervalTimerSection)の選択肢になる。
struct IntervalPresetSettingsView: View {
    @State private var presets: [Int] = IntervalTimerPresets.load()
    @State private var newSeconds: Int = 30

    private var isDuplicate: Bool {
        presets.contains(newSeconds)
    }

    var body: some View {
        List {
            Section {
                if presets.isEmpty {
                    Text("プリセットがありません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(presets, id: \.self) { seconds in
                    Text(Formatters.presetLabel(seconds: seconds))
                }
                .onDelete { offsets in
                    presets.remove(atOffsets: offsets)
                    IntervalTimerPresets.save(presets)
                }
            } footer: {
                Text("すべて削除すると既定のプリセット(30秒/60秒/90秒/2分/3分)に戻ります")
            }

            Section("新しいプリセット") {
                Stepper(value: $newSeconds, in: 5...600, step: 5) {
                    Text(Formatters.presetLabel(seconds: newSeconds))
                }
                Button("追加") {
                    presets.append(newSeconds)
                    presets.sort()
                    IntervalTimerPresets.save(presets)
                }
                .disabled(isDuplicate)
            }
        }
        .navigationTitle("インターバルタイマー")
        .navigationBarTitleDisplayMode(.inline)
    }
}
