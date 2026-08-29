import SwiftUI
import SwiftData

/// トレーニングメニューの管理(作成・編集・削除)。設定タブから開く。
struct TrainingMenuManageView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutMenu.createdAt, order: .reverse) private var menus: [WorkoutMenu]

    @State private var showingForm = false
    @State private var editingMenu: WorkoutMenu?

    var body: some View {
        List {
            Section {
                if menus.isEmpty {
                    Text("種目の組み合わせを「メニュー」として保存すると、記録時に 1 タップで呼び出せます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(menus) { menu in
                    Button {
                        editingMenu = menu
                    } label: {
                        HStack {
                            Text(menu.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(menu.items.count)種目")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        context.delete(menus[index])
                    }
                }
                Button {
                    showingForm = true
                } label: {
                    Label("メニューを作成", systemImage: "plus")
                }
            } footer: {
                if !menus.isEmpty {
                    Text("タップで編集、左スワイプで削除できます")
                }
            }
            .listRowBackground(Theme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .navigationTitle("トレーニングメニュー")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingForm) {
            MenuFormView()
        }
        .sheet(item: $editingMenu) { menu in
            MenuFormView(menuToEdit: menu)
        }
    }
}

/// 勉強科目マスタの管理(追加・名称変更・削除)。設定タブから開く。
/// ライブラリの勉強タブ(SubjectListView)とは別画面。SubjectListView は試験日・目標時間も
/// 編集できるフルフォームを持つが、ここは名称のみを扱う軽量な管理画面として独立させている。
struct SubjectManageView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]

    @State private var newName = ""
    @State private var editingSubject: Subject?

    private var trimmedNewName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDuplicateNewName: Bool {
        subjects.contains { $0.name == trimmedNewName }
    }

    var body: some View {
        List {
            Section {
                if subjects.isEmpty {
                    Text("科目を登録すると、勉強記録の科目として選択できます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(subjects) { subject in
                    Button {
                        editingSubject = subject
                    } label: {
                        Text(subject.name)
                            .foregroundStyle(.primary)
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        context.delete(subjects[index])
                    }
                }
            } footer: {
                if !subjects.isEmpty {
                    Text("タップで編集、左スワイプで削除できます。削除しても過去の記録は残ります(科目名は記録側に残ります)")
                }
            }
            .listRowBackground(Theme.surface)

            Section("新しい科目") {
                TextField("科目・資格名(例: 簿記2級)", text: $newName)
                Button("追加") {
                    context.insert(Subject(name: trimmedNewName))
                    newName = ""
                }
                .disabled(trimmedNewName.isEmpty || isDuplicateNewName)
            }
            .listRowBackground(Theme.surface)
        }
        .keyboardDismissable()
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .navigationTitle("勉強科目")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingSubject) { subject in
            SubjectEditFormView(subject: subject, existingSubjects: subjects)
        }
    }
}

/// 科目の編集フォーム(名前・メモ・削除)。共通の編集シート形式に合わせる。
/// SubjectListView の SubjectFormView(試験日・目標時間も編集可)とは別に、
/// 設定側の管理画面専用として用意している。
struct SubjectEditFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let subject: Subject
    let existingSubjects: [Subject]

    @State private var name: String
    @State private var memo: String
    @State private var showingDeleteConfirm = false

    init(subject: Subject, existingSubjects: [Subject]) {
        self.subject = subject
        self.existingSubjects = existingSubjects
        _name = State(initialValue: subject.name)
        _memo = State(initialValue: subject.memo ?? "")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 空文字、または(自分以外の)既存科目名と重複している場合は保存不可
    private var isInvalid: Bool {
        let trimmed = trimmedName
        if trimmed.isEmpty { return true }
        return existingSubjects.contains { $0.id != subject.id && $0.name == trimmed }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("科目・資格名", text: $name)
                }

                Section("メモ") {
                    TextField("メモ(任意)", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button("この科目を削除", role: .destructive) {
                        showingDeleteConfirm = true
                    }
                }
            }
            .keyboardDismissable()
            .navigationTitle("科目を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        subject.name = trimmedName
                        subject.memo = memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : memo
                        dismiss()
                    }
                    .disabled(isInvalid)
                }
            }
            .confirmationDialog("この科目を削除しますか?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    context.delete(subject)
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("削除しても過去の記録は残ります(科目名は記録側に残ります)")
            }
        }
    }
}

/// 種目マスタの管理(追加・編集・削除)。設定タブから開く。
/// ツールバーの「選択」で複数選択モードに切り替え、まとめて削除できる。
struct ExerciseManageView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.createdAt) private var exercises: [Exercise]

    @State private var showingForm = false
    @State private var editingExercise: Exercise?
    @State private var editMode: EditMode = .inactive
    @State private var selectedIDs: Set<Exercise.ID> = []
    @State private var showingBulkDeleteConfirm = false

    var body: some View {
        ScrollViewReader { proxy in
            List(selection: $selectedIDs) {
                Section("部位へジャンプ") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                        ForEach(BodyPart.allCases) { part in
                            Button {
                                withAnimation {
                                    proxy.scrollTo(part, anchor: .top)
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: part.symbolName)
                                        .font(.title3)
                                        .frame(height: 24)
                                    Text(part.label)
                                        .font(.caption2)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.6)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, minHeight: 64)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(part.color.opacity(0.15))
                                )
                                .foregroundStyle(part.color)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                }

                ForEach(BodyPart.allCases) { part in
                    let items = exercises.filter { $0.bodyPart == part }
                    if !items.isEmpty {
                        Section {
                            ForEach(items) { exercise in
                                Button {
                                    // 編集モード中は行タップが選択動作になるため、通常モード時のみ編集シートを開く
                                    guard !editMode.isEditing else { return }
                                    editingExercise = exercise
                                } label: {
                                    HStack {
                                        Image(systemName: part.symbolName)
                                            .foregroundStyle(part.color)
                                            .frame(width: 28)
                                        Text(exercise.name)
                                            .foregroundStyle(.primary)
                                    }
                                }
                                .tag(exercise.id)
                                .listRowBackground(Theme.surface)
                            }
                            .onDelete { offsets in
                                for index in offsets {
                                    context.delete(items[index])
                                }
                            }
                        } header: {
                            Label(part.label, systemImage: part.symbolName)
                                .foregroundStyle(part.color)
                                .id(part)
                        }
                    }
                }

                Section {
                    Button {
                        showingForm = true
                    } label: {
                        Label("種目を追加", systemImage: "plus")
                    }
                } footer: {
                    Text("タップで編集、左スワイプで削除できます。削除しても過去の記録は残ります")
                }
                .listRowBackground(Theme.surface)
            }
            .environment(\.editMode, $editMode)
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
        }
        .navigationTitle("種目の管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 一括削除はタブバーに隠れない上部バーに置く(.bottomBarはフローティングタブバーと重なるため)
            ToolbarItemGroup(placement: .topBarTrailing) {
                if editMode.isEditing {
                    Button("削除 (\(selectedIDs.count))", role: .destructive) {
                        showingBulkDeleteConfirm = true
                    }
                    .disabled(selectedIDs.isEmpty)
                }
                Button(editMode.isEditing ? "完了" : "選択") {
                    withAnimation {
                        if editMode.isEditing {
                            editMode = .inactive
                            selectedIDs.removeAll()
                        } else {
                            editMode = .active
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            ExerciseFormView()
        }
        .sheet(item: $editingExercise) { exercise in
            ExerciseEditFormView(exercise: exercise, existingExercises: exercises)
        }
        .confirmationDialog("選択した種目(\(selectedIDs.count)件)を削除しますか?", isPresented: $showingBulkDeleteConfirm, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                deleteSelected()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("削除しても過去の記録は残ります")
        }
    }

    private func deleteSelected() {
        for exercise in exercises where selectedIDs.contains(exercise.id) {
            context.delete(exercise)
        }
        selectedIDs.removeAll()
        withAnimation {
            editMode = .inactive
        }
    }
}

/// 種目の編集フォーム(名前・部位・メモ・削除)。共通の編集シート形式に合わせる。
struct ExerciseEditFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let exercise: Exercise
    let existingExercises: [Exercise]

    @State private var name: String
    @State private var bodyPart: BodyPart
    @State private var memo: String
    @State private var showingDeleteConfirm = false

    init(exercise: Exercise, existingExercises: [Exercise]) {
        self.exercise = exercise
        self.existingExercises = existingExercises
        _name = State(initialValue: exercise.name)
        _bodyPart = State(initialValue: exercise.bodyPart)
        _memo = State(initialValue: exercise.memo ?? "")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 空文字、または(自分以外の)既存種目名と重複している場合は保存不可
    private var isInvalid: Bool {
        let trimmed = trimmedName
        if trimmed.isEmpty { return true }
        return existingExercises.contains { $0.id != exercise.id && $0.name == trimmed }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("種目名", text: $name)
                    Picker("部位", selection: $bodyPart) {
                        ForEach(BodyPart.allCases) { part in
                            Text(part.label).tag(part)
                        }
                    }
                } footer: {
                    Text("名前を変えると、過去の記録とメニューの種目名も一緒に変わります")
                }

                Section("メモ") {
                    TextField("メモ(任意)", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button("この種目を削除", role: .destructive) {
                        showingDeleteConfirm = true
                    }
                }
            }
            .keyboardDismissable()
            .navigationTitle("種目を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        // @State は書き換え直後に読み返すと古い値が返るため、先にローカルへ取る
                        let newName = trimmedName
                        let oldName = exercise.name
                        Exercise.propagateRename(from: oldName, to: newName, in: context)
                        exercise.name = newName
                        exercise.bodyPart = bodyPart
                        exercise.memo = memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : memo
                        dismiss()
                    }
                    .disabled(isInvalid)
                }
            }
            .confirmationDialog("この種目を削除しますか?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    context.delete(exercise)
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("削除しても過去の記録は残ります")
            }
        }
    }
}

extension Exercise {
    /// 種目名を変えたとき、名前のスナップショットを持つ側(過去の記録とメニュー)も同じ名前に揃える。
    /// これをしないと履歴・「前回の記録」が名前で引けなくなり、記録が消えたように見える。
    static func propagateRename(from oldName: String, to newName: String, in context: ModelContext) {
        guard oldName != newName, !newName.isEmpty else { return }

        let descriptor = FetchDescriptor<ExerciseLog>(
            predicate: #Predicate { $0.exerciseName == oldName }
        )
        if let logs = try? context.fetch(descriptor) {
            for log in logs {
                log.exerciseName = newName
            }
        }

        // items は Codable の配列なので、作り直して代入しないと保存されない
        if let menus = try? context.fetch(FetchDescriptor<WorkoutMenu>()) {
            for menu in menus where menu.items.contains(where: { $0.exerciseName == oldName }) {
                menu.items = menu.items.map { item in
                    var item = item
                    if item.exerciseName == oldName {
                        item.exerciseName = newName
                    }
                    return item
                }
            }
        }
    }
}
