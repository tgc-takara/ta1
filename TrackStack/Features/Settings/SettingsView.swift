import SwiftUI
import SwiftData

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("表示") {
                    NavigationLink("表示するカテゴリ") {
                        CategoryVisibilitySettingsView()
                    }
                    NavigationLink("週の目標時間") {
                        WeeklyTargetSettingsView()
                    }
                    NavigationLink("週の始まり") {
                        WeekStartSettingsView()
                    }
                }
                .listRowBackground(Theme.surface)
                Section("記録") {
                    NavigationLink("インターバルタイマー") {
                        IntervalPresetSettingsView()
                    }
                    NavigationLink("記録時間のプリセット") {
                        DurationPresetSettingsView()
                    }
                    NavigationLink("ポモドーロ") {
                        PomodoroSettingsView()
                    }
                }
                .listRowBackground(Theme.surface)
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
                }
                .listRowBackground(Theme.surface)
                Section("データ") {
                    NavigationLink("エクスポート") {
                        ExportView()
                    }
                }
                .listRowBackground(Theme.surface)
                Section("このアプリ") {
                    LabeledContent("バージョン") {
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                    }
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("設定")
        }
    }
}

/// 使うカテゴリの取捨選択。オフにしたカテゴリは記録の選択肢・ライブラリ・内訳から消える。
/// 記録済みのデータは消えないため、あとからオンに戻せば元どおり表示される。
struct CategoryVisibilitySettingsView: View {
    @State private var enabled: Set<ActivityCategory> = Set(EnabledCategories.load())

    var body: some View {
        List {
            Section {
                // Toggle + カスタム Binding だと2回目以降の切り替えを取りこぼしたため、
                // 行タップ(Button)+チェックマークで表現する
                ForEach(ActivityCategory.allCases) { category in
                    Button {
                        toggle(category)
                    } label: {
                        HStack {
                            Label(category.label, systemImage: category.symbolName)
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Image(systemName: enabled.contains(category) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(enabled.contains(category) ? category.color : Theme.rule)
                                .font(.title3)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("タップで表示/非表示を切り替えます。非表示にしたカテゴリは記録の選択肢・ライブラリ・内訳から消えます。記録済みのデータは消えず、その期間に記録があるカテゴリは内訳に表示されます")
            }
            .listRowBackground(Theme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .navigationTitle("表示するカテゴリ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ category: ActivityCategory) {
        // @State は書き換えた直後に読み返すと古い値が返ることがあるため、
        // 必ずローカルで新しい集合を作ってから反映・保存する
        var next = enabled
        if next.contains(category) {
            // 最後の1つは外せない(全部非表示だと記録できなくなるため)
            guard next.count > 1 else { return }
            next.remove(category)
        } else {
            next.insert(category)
        }
        enabled = next
        EnabledCategories.save(ActivityCategory.allCases.filter(next.contains))
    }
}

/// 週の始まり(「今週」の区切り)の設定。単一選択で、ホームの今週カードと
/// 記録のカレンダーの週の区切りに使う。
struct WeekStartSettingsView: View {
    @State private var selected: WeekStart = WeekStart.load()

    var body: some View {
        List {
            Section {
                // Toggle + カスタム Binding だと2回目以降の切り替えを取りこぼしたため、
                // 行タップ(Button)+チェックマークで表現する
                ForEach(WeekStart.allCases) { start in
                    Button {
                        select(start)
                    } label: {
                        HStack {
                            Text(start.label)
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Image(systemName: selected == start ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected == start ? Theme.ai : Theme.rule)
                                .font(.title3)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("ホームの「今週」と、記録のカレンダーの週の区切りに使います")
            }
            .listRowBackground(Theme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .navigationTitle("週の始まり")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func select(_ start: WeekStart) {
        // @State は書き換えた直後に読み返すと古い値が返ることがあるため、
        // 必ずローカルで新しい値を作ってから反映・保存する
        let next = start
        selected = next
        WeekStart.save(next)
    }
}

/// カテゴリ別の週の目標時間(分)の設定。ここで登録した値がホームの今週カードの進捗表示になる。
struct WeeklyTargetSettingsView: View {
    @State private var targets: [ActivityCategory: Int] = WeeklyTargets.load()

    var body: some View {
        List {
            Section {
                ForEach(ActivityCategory.allCases) { category in
                    Stepper(
                        value: Binding(
                            get: { targets[category] ?? 0 },
                            set: { updateTarget(for: category, to: $0) }
                        ),
                        in: 0...3000,
                        step: 30
                    ) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label(category.label, systemImage: category.symbolName)
                                .foregroundStyle(Theme.ink)
                            let minutes = targets[category] ?? 0
                            Text(minutes > 0 ? Formatters.duration(minutes: minutes) : "未設定")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                Text("目標を設定したカテゴリだけ、ホームの今週カードに進捗が表示されます。0にすると目標なしに戻ります")
            }
            .listRowBackground(Theme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .navigationTitle("週の目標時間")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func updateTarget(for category: ActivityCategory, to minutes: Int) {
        // @State は書き換えた直後に読み返すと古い値が返ることがあるため、
        // 必ずローカルで新しい辞書を作ってから反映・保存する
        var next = targets
        if minutes > 0 {
            next[category] = minutes
        } else {
            next.removeValue(forKey: category)
        }
        targets = next
        WeeklyTargets.save(next)
    }
}

/// ポモドーロの長さの設定。ここで変更した値が、次にポモドーロを開始したときのスナップショットになる。
struct PomodoroSettingsView: View {
    @State private var settings: PomodoroSettings = PomodoroSettings.load()

    var body: some View {
        List {
            Section {
                Stepper(
                    value: Binding(
                        get: { settings.workMinutes },
                        set: { minutes in update { $0.workMinutes = minutes } }
                    ),
                    in: 5...90,
                    step: 5
                ) {
                    row(title: "作業", value: Formatters.duration(minutes: settings.workMinutes))
                }

                Stepper(
                    value: Binding(
                        get: { settings.breakMinutes },
                        set: { minutes in update { $0.breakMinutes = minutes } }
                    ),
                    in: 1...30,
                    step: 1
                ) {
                    row(title: "休憩", value: Formatters.duration(minutes: settings.breakMinutes))
                }

                Stepper(
                    value: Binding(
                        get: { settings.longBreakMinutes },
                        set: { minutes in update { $0.longBreakMinutes = minutes } }
                    ),
                    in: 5...60,
                    step: 5
                ) {
                    row(title: "長い休憩", value: Formatters.duration(minutes: settings.longBreakMinutes))
                }

                Stepper(
                    value: Binding(
                        get: { settings.cyclesBeforeLongBreak },
                        set: { count in update { $0.cyclesBeforeLongBreak = count } }
                    ),
                    in: 2...8,
                    step: 1
                ) {
                    row(title: "長い休憩までの回数", value: "\(settings.cyclesBeforeLongBreak)回")
                }
            } footer: {
                Text("変更は次にポモドーロを開始したときから反映されます")
            }
            .listRowBackground(Theme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .navigationTitle("ポモドーロ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .foregroundStyle(Theme.ink)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// @State は書き換えた直後に読み返すと古い値が返ることがあるため、
    /// 必ずローカル変数で新しい設定を作ってから反映・保存する
    private func update(_ apply: (inout PomodoroSettings) -> Void) {
        var next = settings
        apply(&next)
        settings = next
        PomodoroSettings.save(next)
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
            .listRowBackground(Theme.surface)

            Section("新しいジャンル") {
                TextField("ジャンル名(例: ビジネス)", text: $newName)
                Button("追加") {
                    context.insert(BookGenre(name: trimmedNewName))
                    newName = ""
                }
                .disabled(trimmedNewName.isEmpty || isDuplicate)
            }
            .listRowBackground(Theme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
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
            .listRowBackground(Theme.surface)

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
            .listRowBackground(Theme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .navigationTitle("インターバルタイマー")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 記録フォームの時間プリセット(分)の管理。ここで追加・削除した値が
/// 記録追加画面(SessionFormView)の時間セクションの選択肢になる。
struct DurationPresetSettingsView: View {
    @State private var presets: [Int] = DurationPresets.load()
    @State private var newMinutes: Int = 30

    private var isDuplicate: Bool {
        presets.contains(newMinutes)
    }

    var body: some View {
        List {
            Section {
                if presets.isEmpty {
                    Text("プリセットがありません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(presets, id: \.self) { minutes in
                    Text(Formatters.duration(minutes: minutes))
                }
                .onDelete { offsets in
                    presets.remove(atOffsets: offsets)
                    DurationPresets.save(presets)
                }
            } footer: {
                Text("すべて削除すると既定のプリセット(5分/10分/15分/30分/45分/60分)に戻ります")
            }
            .listRowBackground(Theme.surface)

            Section("新しいプリセット") {
                Stepper(value: $newMinutes, in: 5...300, step: 5) {
                    Text(Formatters.duration(minutes: newMinutes))
                }
                Button("追加") {
                    presets.append(newMinutes)
                    presets.sort()
                    DurationPresets.save(presets)
                }
                .disabled(isDuplicate)
            }
            .listRowBackground(Theme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .navigationTitle("記録時間のプリセット")
        .navigationBarTitleDisplayMode(.inline)
    }
}
