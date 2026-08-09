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
                    Text(genre.name)
                }
                .onDelete { offsets in
                    for index in offsets {
                        context.delete(genres[index])
                    }
                }
            } footer: {
                if !genres.isEmpty {
                    Text("ジャンルを削除しても、登録済みの本のジャンル表示は残ります")
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
    }
}
