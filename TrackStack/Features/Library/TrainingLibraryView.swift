import SwiftUI
import SwiftData

/// トレーニングのライブラリ(メニューと種目マスタの管理)
struct TrainingLibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutMenu.createdAt, order: .reverse) private var menus: [WorkoutMenu]
    @Query(sort: \Exercise.createdAt) private var exercises: [Exercise]

    @State private var showingMenuForm = false
    @State private var editingMenu: WorkoutMenu?
    @State private var showingExerciseForm = false

    var body: some View {
        List {
            Section("メニュー") {
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
                    showingMenuForm = true
                } label: {
                    Label("メニューを作成", systemImage: "plus")
                }
            }

            Section("種目") {
                ForEach(exercises) { exercise in
                    HStack {
                        Image(systemName: exercise.kind == .strength ? "dumbbell" : "figure.run")
                            .foregroundStyle(ActivityCategory.training.color)
                        Text(exercise.name)
                        Spacer()
                        Text(exercise.kind.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        context.delete(exercises[index])
                    }
                }
                Button {
                    showingExerciseForm = true
                } label: {
                    Label("種目を追加", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingMenuForm) {
            MenuFormView()
        }
        .sheet(item: $editingMenu) { menu in
            MenuFormView(menuToEdit: menu)
        }
        .sheet(isPresented: $showingExerciseForm) {
            ExerciseFormView()
        }
    }
}

/// 種目マスタの追加フォーム
struct ExerciseFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var kind: ExerciseKind = .strength

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("種目名(例: ショルダープレス)", text: $name)
                Picker("種類", selection: $kind) {
                    ForEach(ExerciseKind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
            }
            .navigationTitle("種目を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        context.insert(Exercise(name: trimmedName, kind: kind))
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }
}

/// メニュー(テンプレート)の作成・編集フォーム。
/// 種目とデフォルトのセット構成(重量・回数など)を雛形として保存する。
struct MenuFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let menuToEdit: WorkoutMenu?

    @State private var name: String
    @State private var drafts: [ExerciseDraft]
    @State private var showingExercisePicker = false

    init(menuToEdit: WorkoutMenu? = nil) {
        self.menuToEdit = menuToEdit
        _name = State(initialValue: menuToEdit?.name ?? "")
        _drafts = State(initialValue: (menuToEdit?.items ?? []).map(ExerciseDraft.init(item:)))
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("メニュー名(例: 胸の日)", text: $name)
                }

                ExerciseDraftSections(drafts: $drafts)

                Section {
                    Button {
                        showingExercisePicker = true
                    } label: {
                        Label("種目を追加", systemImage: "plus")
                    }
                }
            }
            .navigationTitle(menuToEdit == nil ? "メニューを作成" : "メニューを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(trimmedName.isEmpty || drafts.isEmpty)
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView { exercise in
                    drafts.append(ExerciseDraft(name: exercise.name, kind: exercise.kind))
                }
            }
        }
    }

    private func save() {
        let items = drafts.map { $0.makeMenuItem() }
        if let menu = menuToEdit {
            menu.name = trimmedName
            menu.items = items
        } else {
            context.insert(WorkoutMenu(name: trimmedName, items: items))
        }
        dismiss()
    }
}
