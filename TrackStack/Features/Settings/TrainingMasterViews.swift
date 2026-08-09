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
        }
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
                    Text("タップで名称変更、左スワイプで削除できます。削除すると過去の記録の科目表示も外れます(記録自体は残ります)")
                }
            }

            Section("新しい科目") {
                TextField("科目・資格名(例: 簿記2級)", text: $newName)
                Button("追加") {
                    context.insert(Subject(name: trimmedNewName))
                    newName = ""
                }
                .disabled(trimmedNewName.isEmpty || isDuplicateNewName)
            }
        }
        .navigationTitle("勉強科目")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingSubject) { subject in
            SubjectRenameFormView(subject: subject, existingSubjects: subjects)
        }
    }
}

/// 科目名のみを変更する小さな編集フォーム(シート表示)。
/// SubjectListView の SubjectFormView(試験日・目標時間も編集可)とは別に、
/// 設定側の管理画面専用として名称変更のみに絞って用意している。
struct SubjectRenameFormView: View {
    @Environment(\.dismiss) private var dismiss

    let subject: Subject
    let existingSubjects: [Subject]

    @State private var name: String

    init(subject: Subject, existingSubjects: [Subject]) {
        self.subject = subject
        self.existingSubjects = existingSubjects
        _name = State(initialValue: subject.name)
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
                TextField("科目・資格名", text: $name)
            }
            .navigationTitle("科目名を変更")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        subject.name = trimmedName
                        dismiss()
                    }
                    .disabled(isInvalid)
                }
            }
        }
    }
}

/// 種目マスタの管理(追加・削除)。設定タブから開く。
struct ExerciseManageView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.createdAt) private var exercises: [Exercise]

    @State private var showingForm = false

    var body: some View {
        List {
            ForEach(BodyPart.allCases) { part in
                let items = exercises.filter { $0.bodyPart == part }
                if !items.isEmpty {
                    Section {
                        ForEach(items) { exercise in
                            HStack {
                                Image(systemName: part.symbolName)
                                    .foregroundStyle(part.color)
                                    .frame(width: 28)
                                Text(exercise.name)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                context.delete(items[index])
                            }
                        }
                    } header: {
                        Label(part.label, systemImage: part.symbolName)
                            .foregroundStyle(part.color)
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
                Text("左スワイプで削除できます。削除しても過去の記録は残ります")
            }
        }
        .navigationTitle("種目の管理")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingForm) {
            ExerciseFormView()
        }
    }
}
