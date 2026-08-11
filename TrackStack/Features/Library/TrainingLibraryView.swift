import SwiftUI
import SwiftData

/// トレーニングのライブラリ(メニューと種目マスタの管理)
struct TrainingLibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutMenu.createdAt, order: .reverse) private var menus: [WorkoutMenu]
    @Query(sort: \Exercise.createdAt) private var exercises: [Exercise]

    @State private var editingMenu: WorkoutMenu?
    @State private var showingExerciseForm = false

    var body: some View {
        ScrollViewReader { proxy in
            List {
                Section("メニュー") {
                    if menus.isEmpty {
                        Text("設定の「トレーニングメニュー」からメニューを作成できます")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Theme.surface)
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                            ForEach(menus) { menu in
                                Button {
                                    editingMenu = menu
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: "list.bullet.rectangle")
                                            .font(.title3)
                                        Text(menu.name)
                                            .font(.caption2)
                                            .lineLimit(2)
                                            .minimumScaleFactor(0.6)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(ActivityCategory.training.color.opacity(0.15))
                                    )
                                    .foregroundStyle(ActivityCategory.training.color)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.clear)
                    }
                }

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
                                HStack {
                                    Image(systemName: part.symbolName)
                                        .foregroundStyle(part.color)
                                        .frame(width: 28)
                                    Text(exercise.name)
                                }
                                .listRowBackground(Theme.surface)
                            }
                        } header: {
                            Label("種目: \(part.label)", systemImage: part.symbolName)
                                .foregroundStyle(part.color)
                                .id(part)
                        }
                    }
                }

                Section {
                    Button {
                        showingExerciseForm = true
                    } label: {
                        Label("種目を追加", systemImage: "plus")
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
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
    @State private var bodyPart: BodyPart = .chest

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("種目名(例: ショルダープレス)", text: $name)
                Picker("部位", selection: $bodyPart) {
                    ForEach(BodyPart.allCases) { part in
                        Text(part.label).tag(part)
                    }
                }
            }
            .navigationTitle("種目を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        context.insert(Exercise(name: trimmedName, bodyPart: bodyPart))
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
                    drafts.append(ExerciseDraft(name: exercise.name, bodyPart: exercise.bodyPart))
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
