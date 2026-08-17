import SwiftUI
import SwiftData

/// 種目ドラフト一覧の編集セクション群(記録フォームとメニュー編集で共用)
struct ExerciseDraftSections: View {
    @Binding var drafts: [ExerciseDraft]
    /// 「前回の記録」を出すための除外対象(編集中のセッション)
    var editingSessionID: UUID?
    /// メニューの雛形編集では前回の記録を出さない
    var showsPreviousRecord: Bool = true

    @Environment(\.modelContext) private var context
    /// 種目名 → 前回の記録
    @State private var previous: [String: PreviousRecord.Entry] = [:]

    var body: some View {
        ForEach($drafts) { $draft in
            Section {
                if draft.bodyPart.isCardio {
                    CardioFieldsView(
                        distanceKm: $draft.distanceKm,
                        durationMinutes: $draft.durationMinutes
                    )
                } else {
                    SetsEditorView(sets: $draft.sets)
                }
            } header: {
                HStack {
                    // アイコンは部位色、種目名は通常色(Label だと両方が同じ色になるため分ける)
                    Image(systemName: draft.bodyPart.symbolName)
                        .foregroundStyle(draft.bodyPart.color)
                    Text(draft.name)
                    Text(draft.bodyPart.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        drafts.removeAll { $0.id == draft.id }
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            } footer: {
                if let entry = previous[draft.name] {
                    Text(PreviousRecord.label(entry))
                }
            }
        }
        .onAppear { reloadPreviousRecords() }
        .onChange(of: drafts.map(\.name)) { _, _ in reloadPreviousRecords() }
    }

    private func reloadPreviousRecords() {
        guard showsPreviousRecord else { return }
        previous = PreviousRecord.latest(
            for: drafts.map(\.name),
            excluding: editingSessionID,
            in: context
        )
    }
}

/// 筋トレのセット(重量 × 回数)編集。
/// 両手/片手の切り替えと、マイナス重量(加重アシストで負荷を軽くする種目)に対応。
struct SetsEditorView: View {
    @Binding var sets: [SetRecord]

    var body: some View {
        ForEach($sets) { $set in
            let index = sets.firstIndex(where: { $0.id == set.id }) ?? 0
            SetRow(
                set: $set,
                index: index,
                // セットが1つだけのときは削除させない(種目ごと消せばよい)
                onDelete: sets.count > 1 ? { sets.removeAll { $0.id == set.id } } : nil
            )
            // セットが縦に並ぶため、行の上下余白を詰めて一覧性を上げる
            .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
        }
        .onDelete { sets.remove(atOffsets: $0) }

        Button {
            let last = sets.last ?? SetRecord(weightKg: 20, reps: 10)
            sets.append(SetRecord(weightKg: last.weightKg, reps: last.reps, isSingleArm: last.isSingleArm))
        } label: {
            Label("セットを追加", systemImage: "plus")
        }
        .buttonStyle(.borderless)
    }
}

/// セット1件分の入力行。通常の文字サイズでは横一列、アクセシビリティ文字サイズでは
/// 横並びが収まらないため2段組みにする。
/// (ViewThatFits は両方の枝を保持し、UITextField を包んだ入力欄のタップを
///  取りこぼすため使わない)
private struct SetRow: View {
    @Binding var set: SetRecord
    let index: Int
    /// nil のときは削除ボタンを出さない(最後の1セット)
    let onDelete: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    labelAndArmToggle
                    Spacer()
                    deleteButton
                }
                HStack(spacing: 6) {
                    Spacer()
                    signToggle
                    valueFields
                }
            }
        } else {
            HStack(spacing: 4) {
                labelAndArmToggle
                Spacer(minLength: 0)
                signToggle
                valueFields
                deleteButton
            }
        }
    }

    @ViewBuilder
    private var deleteButton: some View {
        if let onDelete {
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "minus.circle")
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .font(.subheadline)
        }
    }

    @ViewBuilder
    private var labelAndArmToggle: some View {
        // 1行に収めるため番号だけにする(「セット」の語はセクション文脈から自明)
        Text("\(index + 1)")
            .foregroundStyle(.secondary)
            .font(.subheadline)
            .monospacedDigit()
            .frame(minWidth: 14, alignment: .leading)

        // 両手/片手は色で見分ける(藍=両手 / 朱=片手)
        Button(set.isSingleArm ? "片手" : "両手") {
            set.isSingleArm.toggle()
        }
        .buttonStyle(.bordered)
        .tint(set.isSingleArm ? ActivityCategory.media.color : Theme.ai)
        .font(.caption)
    }

    /// 重量の符号切り替え(マイナス = 加重で負荷を軽くする)
    private var signToggle: some View {
        Button {
            if set.weightKg != 0 {
                set.weightKg = -set.weightKg
            }
        } label: {
            Image(systemName: set.weightKg < 0 ? "minus.circle.fill" : "plusminus.circle")
                .foregroundStyle(set.weightKg < 0 ? Color.orange : Color.secondary)
                .frame(width: 40, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private var valueFields: some View {
        WeightField(value: $set.weightKg)
            .frame(width: 56)
        Text("kg")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        RepsField(value: $set.reps)
            .frame(width: 40)
        Text("回")
            .font(.subheadline)
            .foregroundStyle(.secondary)
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
            WeightField(value: $distanceKm, placeholder: "0")
                .frame(width: 70)
            Text("km")
                .foregroundStyle(.secondary)
        }
        HStack {
            Text("時間")
            Spacer()
            RepsField(value: $durationMinutes, placeholder: "0")
                .frame(width: 70)
            Text("分")
                .foregroundStyle(.secondary)
        }
    }
}

/// 種目選択シート。既存種目からの選択と、その場での新規追加に対応。部位ごとにセクション表示する。
struct ExercisePickerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.createdAt) private var exercises: [Exercise]
    @Query(sort: \WorkoutMenu.createdAt, order: .reverse) private var menus: [WorkoutMenu]

    let onSelect: (Exercise) -> Void
    /// メニューを選んだときの処理。指定しなければメニュー欄を出さない。
    var onSelectMenu: ((WorkoutMenu) -> Void)?

    @State private var newName = ""
    @State private var newBodyPart: BodyPart = .chest

    private var trimmedNewName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    Color.clear
                        .frame(height: 0)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .id("top")

                    // メニューが未登録でも欄自体は出す(消えていると壊れて見えるため)
                    if let onSelectMenu {
                        Section("メニューから") {
                            if menus.isEmpty {
                                Text("メニューが未登録です。設定 > トレーニングメニュー から作成できます")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(menus) { menu in
                                    Button {
                                        onSelectMenu(menu)
                                        dismiss()
                                    } label: {
                                        HStack {
                                            Label(menu.name, systemImage: "list.bullet.rectangle")
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            Text("\(menu.items.count)種目")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ForEach(BodyPart.allCases) { part in
                        let items = exercises.filter { $0.bodyPart == part }
                        if !items.isEmpty {
                            Section(part.label) {
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
                        Picker("部位", selection: $newBodyPart) {
                            ForEach(BodyPart.allCases) { part in
                                Text(part.label).tag(part)
                            }
                        }
                        Button("追加して選択") {
                            let exercise = Exercise(name: trimmedNewName, bodyPart: newBodyPart)
                            context.insert(exercise)
                            onSelect(exercise)
                            dismiss()
                        }
                        .disabled(trimmedNewName.isEmpty)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        withAnimation {
                            proxy.scrollTo("top", anchor: .top)
                        }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.body.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial, in: Circle())
                            .shadow(radius: 3)
                    }
                    .padding()
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
