import SwiftUI
import SwiftData

/// 種目ドラフト一覧の編集セクション群(記録フォームとメニュー編集で共用)
struct ExerciseDraftSections: View {
    @Binding var drafts: [ExerciseDraft]

    var body: some View {
        ForEach($drafts) { $draft in
            Section {
                if draft.kind == .strength {
                    SetsEditorView(sets: $draft.sets)
                } else {
                    CardioFieldsView(
                        distanceKm: $draft.distanceKm,
                        durationMinutes: $draft.durationMinutes
                    )
                }
            } header: {
                HStack {
                    Label(
                        draft.name,
                        systemImage: draft.kind == .strength ? "dumbbell" : "figure.run"
                    )
                    Spacer()
                    Button {
                        drafts.removeAll { $0.id == draft.id }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }
        }
    }
}

/// 筋トレのセット(重量 × 回数)編集
struct SetsEditorView: View {
    @Binding var sets: [SetRecord]

    var body: some View {
        ForEach($sets) { $set in
            let index = sets.firstIndex(where: { $0.id == set.id }) ?? 0
            HStack {
                Text("セット\(index + 1)")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Spacer()
                TextField("kg", value: $set.weightKg, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                Text("kg ×")
                    .foregroundStyle(.secondary)
                TextField("回", value: $set.reps, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 44)
                Text("回")
                    .foregroundStyle(.secondary)
            }
        }
        .onDelete { sets.remove(atOffsets: $0) }

        Button {
            let last = sets.last ?? SetRecord(weightKg: 20, reps: 10)
            sets.append(SetRecord(weightKg: last.weightKg, reps: last.reps))
        } label: {
            Label("セットを追加", systemImage: "plus")
        }
        .buttonStyle(.borderless)
    }
}

/// 有酸素(距離・時間)編集
struct CardioFieldsView: View {
    @Binding var distanceKm: Double
    @Binding var durationMinutes: Int

    var body: some View {
        HStack {
            Text("距離")
            Spacer()
            TextField("0", value: $distanceKm, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
            Text("km")
                .foregroundStyle(.secondary)
        }
        HStack {
            Text("時間")
            Spacer()
            TextField("0", value: $durationMinutes, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
            Text("分")
                .foregroundStyle(.secondary)
        }
    }
}

/// 種目選択シート。既存種目からの選択と、その場での新規追加に対応。
struct ExercisePickerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.createdAt) private var exercises: [Exercise]

    let onSelect: (Exercise) -> Void

    @State private var newName = ""
    @State private var newKind: ExerciseKind = .strength

    private var trimmedNewName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(ExerciseKind.allCases) { kind in
                    let items = exercises.filter { $0.kind == kind }
                    if !items.isEmpty {
                        Section(kind.label) {
                            ForEach(items) { exercise in
                                Button {
                                    onSelect(exercise)
                                    dismiss()
                                } label: {
                                    Text(exercise.name)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }

                Section("新しい種目") {
                    TextField("種目名", text: $newName)
                    Picker("種類", selection: $newKind) {
                        ForEach(ExerciseKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    Button("追加して選択") {
                        let exercise = Exercise(name: trimmedNewName, kind: newKind)
                        context.insert(exercise)
                        onSelect(exercise)
                        dismiss()
                    }
                    .disabled(trimmedNewName.isEmpty)
                }
            }
            .navigationTitle("種目を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }
}
