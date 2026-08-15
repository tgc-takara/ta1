import SwiftUI
import SwiftData

/// 記録フォーム(新規作成・編集の両対応)。
/// 共通フィールド(カテゴリ・日時・時間・メモ)に加え、
/// カテゴリ固有の入力(本+進捗% / 科目 / 種目・メニュー)を切り替えて表示する。
struct SessionFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @Query(sort: \Subject.createdAt, order: .reverse) private var subjects: [Subject]
    @Query(sort: \WorkoutMenu.createdAt, order: .reverse) private var menus: [WorkoutMenu]
    @Query(sort: \PodcastShow.createdAt, order: .reverse) private var shows: [PodcastShow]

    private let sessionToEdit: Session?

    @State private var category: ActivityCategory
    @State private var startedAt: Date
    @State private var durationMinutes: Int
    @State private var note: String

    // 読書
    @State private var selectedBook: Book?
    @State private var progressPercent: Double

    // 勉強
    @State private var selectedSubject: Subject?

    // トレーニング
    @State private var exerciseDrafts: [ExerciseDraft]
    @State private var menuName: String?
    @State private var showingExercisePicker = false

    // 新聞
    @State private var clipDrafts: [ArticleClipDraft]

    // 動画・音声
    @State private var selectedShow: PodcastShow?
    @State private var episodeTitle: String

    // 時間プリセット(設定画面で編集可能。表示直前に再読み込みする)
    @State private var durationPresets: [Int] = DurationPresets.load()
    // 選べるカテゴリ(設定画面で編集可能)
    @State private var pickableCategories: [ActivityCategory] = ActivityCategory.allCases

    init(
        sessionToEdit: Session? = nil,
        initialCategory: ActivityCategory? = nil,
        initialStartedAt: Date? = nil,
        initialDurationMinutes: Int? = nil
    ) {
        self.sessionToEdit = sessionToEdit
        // 新規記録の既定は読書。読書を非表示にしている場合は有効なカテゴリの先頭にする
        let fallback = EnabledCategories.load().first ?? .reading
        let defaultCategory = EnabledCategories.load().contains(.reading) ? .reading : fallback
        _category = State(initialValue: sessionToEdit?.category ?? initialCategory ?? defaultCategory)
        _startedAt = State(initialValue: sessionToEdit?.startedAt ?? initialStartedAt ?? Date())
        _durationMinutes = State(initialValue: sessionToEdit?.durationMinutes ?? initialDurationMinutes ?? 30)
        _note = State(initialValue: sessionToEdit?.note ?? "")
        _selectedBook = State(initialValue: sessionToEdit?.book)
        _progressPercent = State(initialValue: Double(
            sessionToEdit?.book?.progressPercent ?? 0
        ))
        _selectedSubject = State(initialValue: sessionToEdit?.subject)
        let drafts = (sessionToEdit?.exerciseLogs ?? [])
            .sorted { $0.order < $1.order }
            .map(ExerciseDraft.init(log:))
        _exerciseDrafts = State(initialValue: drafts)
        _menuName = State(initialValue: sessionToEdit?.menuName)
        let clips = (sessionToEdit?.articleClips ?? [])
            .sorted { $0.order < $1.order }
            .map(ArticleClipDraft.init(clip:))
        _clipDrafts = State(initialValue: clips)
        _selectedShow = State(initialValue: sessionToEdit?.podcastShow)
        _episodeTitle = State(initialValue: sessionToEdit?.episodeTitle ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                commonSection

                switch category {
                case .reading: readingSection
                case .study: studySection
                case .training: trainingSections
                case .article: articleSection
                case .media: mediaSection
                }

                durationSection
                noteSection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle(sessionToEdit == nil ? "記録を追加" : "記録を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView { exercise in
                    exerciseDrafts.append(
                        ExerciseDraft(name: exercise.name, bodyPart: exercise.bodyPart)
                    )
                }
            }
        }
    }

    // MARK: - Sections

    private var commonSection: some View {
        Section {
            Picker("カテゴリ", selection: $category) {
                ForEach(pickableCategories) { category in
                    Label(category.label, systemImage: category.symbolName)
                        .tag(category)
                }
            }
            .pickerStyle(.menu)

            DatePicker("開始日時", selection: $startedAt)
        }
        .onAppear {
            // 設定でカテゴリの表示/非表示が変わっている可能性があるため表示のたびに読み直す
            // (編集中の記録のカテゴリは非表示でも選択肢に残す)
            pickableCategories = EnabledCategories.forPicker(including: category)
        }
    }

    private var readingSection: some View {
        Section {
            Picker("本", selection: $selectedBook) {
                Text("選択なし").tag(nil as Book?)
                ForEach(books) { book in
                    Text(book.title).tag(book as Book?)
                }
            }
            .onChange(of: selectedBook) { _, newBook in
                progressPercent = Double(newBook?.progressPercent ?? 0)
            }

            if selectedBook != nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text("この本の進捗 \(Int(progressPercent))%")
                        .font(.subheadline)
                    Slider(value: $progressPercent, in: 0...100, step: 1)
                }
            }

            if books.isEmpty {
                Text("ライブラリの読書タブから本を追加できます")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("読書")
        } footer: {
            if selectedBook != nil {
                Text("進捗は本に保存されます(記録ごとには残りません)")
            }
        }
    }

    private var studySection: some View {
        Section("勉強") {
            Picker("科目", selection: $selectedSubject) {
                Text("選択なし").tag(nil as Subject?)
                ForEach(subjects) { subject in
                    Text(subject.name).tag(subject as Subject?)
                }
            }

            if subjects.isEmpty {
                Text("ライブラリの勉強タブから科目を追加できます")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var trainingSections: some View {
        Section("トレーニング") {
            HStack {
                Menu {
                    ForEach(menus) { menu in
                        Button(menu.name) { apply(menu) }
                    }
                } label: {
                    Label("メニューから", systemImage: "list.bullet.rectangle")
                }
                .disabled(menus.isEmpty)

                Spacer()

                Button {
                    applyLastTraining()
                } label: {
                    Label("前回と同じ", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
            }

            if let menuName {
                LabeledContent("メニュー", value: menuName)
            }
        }

        IntervalTimerSection()

        ExerciseDraftSections(drafts: $exerciseDrafts)

        Section {
            Button {
                showingExercisePicker = true
            } label: {
                Label("種目を追加", systemImage: "plus")
            }
        }
    }

    /// 記事(新聞・Web記事・レポート/白書)。1回の記録に読んだ記事を何本でもぶら下げる。
    private var articleSection: some View {
        Section {
            ForEach($clipDrafts) { $draft in
                VStack(alignment: .leading, spacing: 6) {
                    TextField("記事の見出し", text: $draft.title)
                        .font(.body)
                    TextField("URL(任意)", text: $draft.urlString)
                        .font(.caption)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("メモ(任意)", text: $draft.memo, axis: .vertical)
                        .font(.caption)
                        .lineLimit(1...3)
                }
                .padding(.vertical, 2)
            }
            .onDelete { clipDrafts.remove(atOffsets: $0) }

            Button {
                clipDrafts.append(ArticleClipDraft())
            } label: {
                Label("記事を追加", systemImage: "plus")
            }
        } header: {
            Text("読んだ記事")
        } footer: {
            Text(clipDrafts.isEmpty
                 ? "読んだ記事をクリップできます(記事なしで時間だけの記録も可)"
                 : "見出しが空の記事は保存されません。左スワイプで削除できます")
        }
    }

    /// 動画・音声(ポッドキャスト / 動画講座 / セミナー)。
    /// シリーズ(番組名・チャンネル名・セミナー名)はライブラリで管理するマスタから選ぶ。
    private var mediaSection: some View {
        Section {
            Picker("シリーズ", selection: $selectedShow) {
                Text("選択なし").tag(nil as PodcastShow?)
                ForEach(shows) { show in
                    Text(show.name).tag(show as PodcastShow?)
                }
            }

            TextField("タイトル(任意)", text: $episodeTitle)

            if shows.isEmpty {
                Text("ライブラリの動画・音声タブからシリーズを追加できます")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("動画・音声")
        } footer: {
            Text("ポッドキャスト・動画講座・セミナーをまとめて記録します")
        }
    }

    private var durationSection: some View {
        Section("時間") {
            Stepper(
                Formatters.duration(minutes: durationMinutes),
                value: $durationMinutes,
                in: 5...600,
                step: 5
            )
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(durationPresets, id: \.self) { preset in
                    Button(Formatters.duration(minutes: preset)) {
                        durationMinutes = preset
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
        }
        .onAppear {
            // 設定画面でプリセットが変更されている可能性があるため、表示のたびに再読み込みする
            durationPresets = DurationPresets.load()
        }
    }

    private var noteSection: some View {
        Section("メモ") {
            TextField("何をした?", text: $note, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    // MARK: - Actions

    private func apply(_ menu: WorkoutMenu) {
        menuName = menu.name
        exerciseDrafts = menu.items.map(ExerciseDraft.init(item:))
    }

    /// 直近のトレーニングセッション(編集中のものを除く)の内容を複製する
    private func applyLastTraining() {
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.categoryRaw == "training" },
            sortBy: [SortDescriptor(\Session.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 10
        guard let results = try? context.fetch(descriptor) else { return }
        let editingID = sessionToEdit?.id
        guard let last = results.first(where: { $0.id != editingID }) else { return }

        menuName = last.menuName
        durationMinutes = last.durationMinutes
        exerciseDrafts = last.exerciseLogs
            .sorted { $0.order < $1.order }
            .map(ExerciseDraft.init(log:))
    }

    private func save() {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        let session: Session
        if let existing = sessionToEdit {
            session = existing
            session.category = category
            session.startedAt = startedAt
            session.durationMinutes = durationMinutes
            session.note = trimmedNote.isEmpty ? nil : trimmedNote
        } else {
            session = Session(
                category: category,
                startedAt: startedAt,
                durationMinutes: durationMinutes,
                note: trimmedNote.isEmpty ? nil : trimmedNote
            )
            context.insert(session)
        }

        // カテゴリ固有フィールドは一度クリアしてから現在のカテゴリ分だけ設定する
        // (編集でカテゴリを切り替えたとき古い関連が残らないように)
        session.book = nil
        session.subject = nil
        session.menuName = nil
        session.podcastShow = nil
        session.episodeTitle = nil
        for log in session.exerciseLogs {
            context.delete(log)
        }
        session.exerciseLogs = []
        for clip in session.articleClips {
            context.delete(clip)
        }
        session.articleClips = []

        switch category {
        case .reading:
            session.book = selectedBook
            if let book = selectedBook {
                let percent = Int(progressPercent)
                book.progressPercent = percent
                if percent >= 100 {
                    book.status = .finished
                } else if book.status == .wantToRead {
                    book.status = .reading
                }
            }
        case .study:
            session.subject = selectedSubject
        case .training:
            session.menuName = menuName
            for (index, draft) in exerciseDrafts.enumerated() {
                let log = draft.makeLog(order: index)
                log.session = session
                context.insert(log)
            }
        case .article:
            // 見出しが空のクリップは入力途中とみなして保存しない
            for (index, draft) in clipDrafts.filter({ !$0.trimmedTitle.isEmpty }).enumerated() {
                let clip = draft.makeClip(order: index)
                clip.session = session
                context.insert(clip)
            }
        case .media:
            session.podcastShow = selectedShow
            session.episodeTitle = episodeTitle
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
        }

        dismiss()
    }
}
