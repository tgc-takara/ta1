import SwiftUI
import SwiftData

/// 手動記録フォーム(新規作成・編集の両対応)。
/// M1 では全カテゴリ共通のフィールド(カテゴリ・日時・時間・メモ)のみ。
/// カテゴリ固有の入力(書籍・科目・種目)は M2 で追加する。
struct SessionFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let sessionToEdit: Session?

    @State private var category: ActivityCategory
    @State private var startedAt: Date
    @State private var durationMinutes: Int
    @State private var note: String

    init(sessionToEdit: Session? = nil) {
        self.sessionToEdit = sessionToEdit
        _category = State(initialValue: sessionToEdit?.category ?? .study)
        _startedAt = State(initialValue: sessionToEdit?.startedAt ?? Date())
        _durationMinutes = State(initialValue: sessionToEdit?.durationMinutes ?? 30)
        _note = State(initialValue: sessionToEdit?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("カテゴリ", selection: $category) {
                        ForEach(ActivityCategory.allCases) { category in
                            Label(category.label, systemImage: category.symbolName)
                                .tag(category)
                        }
                    }
                    .pickerStyle(.menu)

                    DatePicker("開始日時", selection: $startedAt)
                }

                Section("時間") {
                    Stepper(
                        Formatters.duration(minutes: durationMinutes),
                        value: $durationMinutes,
                        in: 5...600,
                        step: 5
                    )
                    HStack {
                        ForEach([15, 30, 45, 60, 90], id: \.self) { preset in
                            Button("\(preset)分") {
                                durationMinutes = preset
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)
                        }
                    }
                }

                Section("メモ") {
                    TextField("何をした?", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
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
        }
    }

    private func save() {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let session = sessionToEdit {
            session.category = category
            session.startedAt = startedAt
            session.durationMinutes = durationMinutes
            session.note = trimmedNote.isEmpty ? nil : trimmedNote
        } else {
            let session = Session(
                category: category,
                startedAt: startedAt,
                durationMinutes: durationMinutes,
                note: trimmedNote.isEmpty ? nil : trimmedNote
            )
            context.insert(session)
        }
        dismiss()
    }
}
