import SwiftUI
import SwiftData

/// 本棚(ステータス別の書籍一覧)
struct BookshelfView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]

    @State private var statusFilter: BookStatus = .reading
    @State private var showingAdd = false
    @State private var editingBook: Book?

    private var filtered: [Book] {
        books.filter { $0.status == statusFilter }
    }

    var body: some View {
        VStack {
            Picker("ステータス", selection: $statusFilter) {
                ForEach(BookStatus.allCases) { status in
                    Text(status.label).tag(status)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if filtered.isEmpty {
                ContentUnavailableView(
                    "「\(statusFilter.label)」の本がありません",
                    systemImage: "book",
                    description: Text("右上の + から本を追加できます")
                )
            } else {
                List {
                    ForEach(filtered) { book in
                        BookRowView(book: book)
                            .contentShape(Rectangle())
                            .onTapGesture { editingBook = book }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            context.delete(filtered[index])
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
            BookFormView()
        }
        .sheet(item: $editingBook) { book in
            BookFormView(bookToEdit: book)
        }
    }
}

struct BookRowView: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(.body)
                    if let author = book.author, !author.isEmpty {
                        Text(author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if book.status == .finished, let rating = book.rating {
                    Text(String(repeating: "★", count: rating))
                        .font(.caption)
                        .foregroundStyle(.yellow)
                } else {
                    Text("\(book.progressPercent)%")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                }
            }
            if book.status != .wantToRead {
                ProgressView(value: Double(book.progressPercent), total: 100)
                    .tint(ActivityCategory.reading.color)
            }
        }
        .padding(.vertical, 2)
    }
}

/// 書籍の追加・編集フォーム
struct BookFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let bookToEdit: Book?

    @State private var title: String
    @State private var author: String
    @State private var status: BookStatus
    @State private var rating: Int
    @State private var review: String

    init(bookToEdit: Book? = nil) {
        self.bookToEdit = bookToEdit
        _title = State(initialValue: bookToEdit?.title ?? "")
        _author = State(initialValue: bookToEdit?.author ?? "")
        _status = State(initialValue: bookToEdit?.status ?? .wantToRead)
        _rating = State(initialValue: bookToEdit?.rating ?? 3)
        _review = State(initialValue: bookToEdit?.review ?? "")
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("タイトル", text: $title)
                    TextField("著者(任意)", text: $author)
                    Picker("ステータス", selection: $status) {
                        ForEach(BookStatus.allCases) { status in
                            Text(status.label).tag(status)
                        }
                    }
                }

                if status == .finished {
                    Section("読了メモ") {
                        Picker("評価", selection: $rating) {
                            ForEach(1...5, id: \.self) { value in
                                Text(String(repeating: "★", count: value)).tag(value)
                            }
                        }
                        TextField("感想(任意)", text: $review, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
            }
            .navigationTitle(bookToEdit == nil ? "本を追加" : "本を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(trimmedTitle.isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReview = review.trimmingCharacters(in: .whitespacesAndNewlines)

        let book: Book
        if let existing = bookToEdit {
            book = existing
            book.title = trimmedTitle
            book.author = trimmedAuthor.isEmpty ? nil : trimmedAuthor
            book.status = status
        } else {
            book = Book(
                title: trimmedTitle,
                author: trimmedAuthor.isEmpty ? nil : trimmedAuthor,
                status: status
            )
            context.insert(book)
        }

        if status == .finished {
            book.rating = rating
            book.review = trimmedReview.isEmpty ? nil : trimmedReview
            book.progressPercent = 100
        } else {
            book.rating = nil
            book.review = nil
        }

        dismiss()
    }
}
