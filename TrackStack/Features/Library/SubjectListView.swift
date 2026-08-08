import SwiftUI
import SwiftData

/// 科目・資格の一覧(累計時間・試験日カウントダウン付き)
struct SubjectListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Subject.createdAt, order: .reverse) private var subjects: [Subject]

    @State private var showingAdd = false
    @State private var editingSubject: Subject?

    var body: some View {
        Group {
            if subjects.isEmpty {
                ContentUnavailableView(
                    "科目がありません",
                    systemImage: "pencil.and.list.clipboard",
                    description: Text("右上の + から科目・資格を追加できます")
                )
            } else {
                List {
                    ForEach(subjects) { subject in
                        SubjectRowView(subject: subject)
                            .contentShape(Rectangle())
                            .onTapGesture { editingSubject = subject }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            context.delete(subjects[index])
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            SubjectFormView()
        }
        .sheet(item: $editingSubject) { subject in
            SubjectFormView(subjectToEdit: subject)
        }
    }
}

struct SubjectRowView: View {
    let subject: Subject

    private var totalMinutes: Int {
        subject.sessions.reduce(0) { $0 + $1.durationMinutes }
    }

    private var daysUntilExam: Int? {
        guard let examDate = subject.examDate else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: examDate)
        ).day
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(subject.name)
                    .font(.body)
                Spacer()
                if let days = daysUntilExam {
                    if days >= 0 {
                        Text("試験まであと\(days)日")
                            .font(.caption.bold())
                            .foregroundStyle(days <= 14 ? .red : .secondary)
                    } else {
                        Text("試験終了")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Text("累計 \(Formatters.duration(minutes: totalMinutes))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let target = subject.targetHours, target > 0 {
                    Text("/ 目標\(target)時間")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let target = subject.targetHours, target > 0 {
                ProgressView(
                    value: min(Double(totalMinutes), Double(target * 60)),
                    total: Double(target * 60)
                )
                .tint(ActivityCategory.study.color)
            }
        }
        .padding(.vertical, 2)
    }
}

/// 科目の追加・編集フォーム
struct SubjectFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let subjectToEdit: Subject?

    @State private var name: String
    @State private var hasExamDate: Bool
    @State private var examDate: Date
    @State private var hasTarget: Bool
    @State private var targetHours: Int

    init(subjectToEdit: Subject? = nil) {
        self.subjectToEdit = subjectToEdit
        _name = State(initialValue: subjectToEdit?.name ?? "")
        _hasExamDate = State(initialValue: subjectToEdit?.examDate != nil)
        _examDate = State(initialValue: subjectToEdit?.examDate ?? Date())
        _hasTarget = State(initialValue: (subjectToEdit?.targetHours ?? 0) > 0)
        _targetHours = State(initialValue: subjectToEdit?.targetHours ?? 100)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("科目・資格名(例: 簿記2級)", text: $name)
                }

                Section("試験日") {
                    Toggle("試験日を設定", isOn: $hasExamDate)
                    if hasExamDate {
                        DatePicker("試験日", selection: $examDate, displayedComponents: .date)
                    }
                }

                Section("目標") {
                    Toggle("目標学習時間を設定", isOn: $hasTarget)
                    if hasTarget {
                        Stepper("\(targetHours)時間", value: $targetHours, in: 5...2000, step: 5)
                    }
                }
            }
            .navigationTitle(subjectToEdit == nil ? "科目を追加" : "科目を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func save() {
        if let subject = subjectToEdit {
            subject.name = trimmedName
            subject.examDate = hasExamDate ? examDate : nil
            subject.targetHours = hasTarget ? targetHours : nil
        } else {
            let subject = Subject(
                name: trimmedName,
                examDate: hasExamDate ? examDate : nil,
                targetHours: hasTarget ? targetHours : nil
            )
            context.insert(subject)
        }
        dismiss()
    }
}
