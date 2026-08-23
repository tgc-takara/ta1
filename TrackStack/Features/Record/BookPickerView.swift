import SwiftUI
import SwiftData

/// 本を選ぶシート。検索なしのときは「最近読んだ」「読書中」「積読」「読了」でセクション分けし、
/// 検索中は全冊をタイトル・著者の部分一致でフラットに並べる。
struct BookPickerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]

    private let selected: Book?
    private let onSelect: (Book?) -> Void

    @State private var searchText = ""

    init(selected: Book?, onSelect: @escaping (Book?) -> Void) {
        self.selected = selected
        self.onSelect = onSelect
    }

    private var recentBooks: [Book] {
        RecentBooks.latest(limit: 3, in: context)
    }

    private func books(status: BookStatus) -> [Book] {
        books.filter { $0.status == status }
    }

    private var searchResults: [Book] {
        books.filter { book in
            book.title.localizedCaseInsensitiveContains(searchText)
                || (book.author?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    Section {
                        selectNoneRow
                    }

                    if !recentBooks.isEmpty {
                        Section("最近読んだ") {
                            ForEach(recentBooks) { book in
                                bookRow(book)
                            }
                        }
                    }

                    ForEach([BookStatus.reading, .wantToRead, .finished]) { status in
                        let list = books(status: status)
                        if !list.isEmpty {
                            Section(status.label) {
                                ForEach(list) { book in
                                    bookRow(book)
                                }
                            }
                        }
                    }
                } else {
                    Section {
                        ForEach(searchResults) { book in
                            bookRow(book)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .listRowBackground(Theme.surface)
            .searchable(text: $searchText, prompt: "タイトル・著者で検索")
            .navigationTitle("本を選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    private var selectNoneRow: some View {
        Button {
            onSelect(nil)
            dismiss()
        } label: {
            HStack {
                Text("選択なし")
                    .foregroundStyle(Theme.ink)
                Spacer()
                if selected == nil {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Theme.ai)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Theme.surface)
    }

    private func bookRow(_ book: Book) -> some View {
        Button {
            onSelect(book)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                coverThumbnail(for: book)

                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(.body)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if let author = book.author, !author.isEmpty {
                        Text(author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Text(book.status == .finished ? "読了" : "\(book.progressPercent)%")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if book == selected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Theme.ai)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Theme.surface)
    }

    @ViewBuilder
    private func coverThumbnail(for book: Book) -> some View {
        if let data = book.coverImageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 32, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        } else {
            RoundedRectangle(cornerRadius: 3)
                .fill(ActivityCategory.reading.color.opacity(0.15))
                .frame(width: 32, height: 44)
                .overlay(
                    Image(systemName: "book.closed")
                        .font(.caption)
                        .foregroundStyle(ActivityCategory.reading.color)
                )
        }
    }
}
