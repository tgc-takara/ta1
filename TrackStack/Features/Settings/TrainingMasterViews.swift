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
