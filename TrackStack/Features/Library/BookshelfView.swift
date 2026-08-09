import SwiftUI
import SwiftData
import PhotosUI

/// 本棚(ステータス別の書籍一覧)。ジャンルでの絞り込みに対応。
struct BookshelfView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @Query(sort: \BookGenre.createdAt) private var genres: [BookGenre]

    @State private var statusFilter: BookStatus = .reading
    /// nil = すべてのジャンル
    @State private var genreFilter: String?
    @State private var showingAdd = false
    @State private var editingBook: Book?

    private var filtered: [Book] {
        books.filter { book in
            book.status == statusFilter
                && (genreFilter == nil || book.genreName == genreFilter)
        }
    }

    /// 登録済みマスタに加え、本に付いているジャンルも選択肢に含める(マスタ削除後の絞り込み用)
    private var genreOptions: [String] {
        var names = genres.map(\.name)
        for name in books.compactMap(\.genreName) where !names.contains(name) {
            names.append(name)
        }
        return names
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

            if !genreOptions.isEmpty {
                HStack {
                    Menu {
                        Picker("ジャンル", selection: $genreFilter) {
                            Text("すべてのジャンル").tag(nil as String?)
                            ForEach(genreOptions, id: \.self) { name in
                                Text(name).tag(name as String?)
                            }
                        }
                    } label: {
                        Label(
                            genreFilter ?? "すべてのジャンル",
                            systemImage: genreFilter == nil
                                ? "line.3.horizontal.decrease.circle"
                                : "line.3.horizontal.decrease.circle.fill"
                        )
                        .font(.subheadline)
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }

            if filtered.isEmpty {
                ContentUnavailableView(
                    "「\(statusFilter.label)」の本がありません",
                    systemImage: "book",
                    description: Text(
                        genreFilter == nil
                            ? "右上の + から本を追加できます"
                            : "「\(genreFilter ?? "")」で絞り込み中です"
                    )
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

    private static let finishedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter
    }()

    var body: some View {
        HStack(spacing: 12) {
            coverThumbnail

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.title)
                            .font(.body)
                        HStack(spacing: 6) {
                            if let author = book.author, !author.isEmpty {
                                Text(author)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let genre = book.genreName {
                                Text(genre)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(
                                        Capsule().fill(ActivityCategory.reading.color.opacity(0.15))
                                    )
                                    .foregroundStyle(ActivityCategory.reading.color)
                            }
                            if book.status == .finished, let finishedOn = book.finishedOn {
                                Text("\(Self.finishedDateFormatter.string(from: finishedOn))読了")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
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
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var coverThumbnail: some View {
        if let data = book.coverImageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}

/// 書籍の追加・編集フォーム
struct BookFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BookGenre.createdAt) private var genres: [BookGenre]

    private let bookToEdit: Book?

    @State private var title: String
    @State private var author: String
    @State private var genreName: String?
    @State private var status: BookStatus
    @State private var rating: Int
    @State private var review: String
    @State private var coverImageData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var startedOnEnabled: Bool
    @State private var startedOn: Date
    @State private var finishedOnEnabled: Bool
    @State private var finishedOn: Date

    init(bookToEdit: Book? = nil) {
        self.bookToEdit = bookToEdit
        _title = State(initialValue: bookToEdit?.title ?? "")
        _author = State(initialValue: bookToEdit?.author ?? "")
        _genreName = State(initialValue: bookToEdit?.genreName)
        _status = State(initialValue: bookToEdit?.status ?? .wantToRead)
        _rating = State(initialValue: bookToEdit?.rating ?? 3)
        _review = State(initialValue: bookToEdit?.review ?? "")
        _coverImageData = State(initialValue: bookToEdit?.coverImageData)
        _startedOnEnabled = State(initialValue: bookToEdit?.startedOn != nil)
        _startedOn = State(initialValue: bookToEdit?.startedOn ?? Date())
        _finishedOnEnabled = State(initialValue: bookToEdit?.finishedOn != nil)
        _finishedOn = State(initialValue: bookToEdit?.finishedOn ?? Date())
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
                    Picker("ジャンル", selection: $genreName) {
                        Text("なし").tag(nil as String?)
                        ForEach(genres) { genre in
                            Text(genre.name).tag(genre.name as String?)
                        }
                    }
                    Picker("ステータス", selection: $status) {
                        ForEach(BookStatus.allCases) { status in
                            Text(status.label).tag(status)
                        }
                    }
                } footer: {
                    if genres.isEmpty {
                        Text("ジャンルは設定タブの「読書ジャンル」から登録できます")
                    }
                }

                Section("表紙写真") {
                    if let data = coverImageData, let image = UIImage(data: data) {
                        HStack {
                            Spacer()
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Spacer()
                        }
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(
                            coverImageData == nil ? "写真を選択" : "写真を変更",
                            systemImage: "photo"
                        )
                    }
                    if coverImageData != nil {
                        Button("写真を削除", role: .destructive) {
                            coverImageData = nil
                            photoItem = nil
                        }
                    }
                }

                Section("日付") {
                    Toggle("読み始めた日を記録", isOn: $startedOnEnabled)
                    if startedOnEnabled {
                        DatePicker("読み始めた日", selection: $startedOn, displayedComponents: .date)
                    }
                    Toggle("読み終わった日を記録", isOn: $finishedOnEnabled)
                    if finishedOnEnabled {
                        DatePicker("読み終わった日", selection: $finishedOn, displayedComponents: .date)
                    }
                }

                Section("読書メモ") {
                    TextField("メモ(任意)", text: $review, axis: .vertical)
                        .lineLimit(3...6)
                }

                if status == .finished {
                    Section("評価") {
                        Picker("評価", selection: $rating) {
                            ForEach(1...5, id: \.self) { value in
                                Text(String(repeating: "★", count: value)).tag(value)
                            }
                        }
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
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        coverImageData = Self.downscaled(data)
                    }
                }
            }
        }
    }

    /// 表紙写真を保存用に縮小する(長辺 800px・JPEG)。変換できなければ元データのまま。
    private static func downscaled(_ data: Data, maxDimension: CGFloat = 800) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        guard scale < 1 else {
            return image.jpegData(compressionQuality: 0.8) ?? data
        }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.8) ?? data
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
        book.genreName = genreName
        book.coverImageData = coverImageData
        book.review = trimmedReview.isEmpty ? nil : trimmedReview

        if status == .finished {
            book.rating = rating
            book.progressPercent = 100
        } else {
            book.rating = nil
        }

        book.startedOn = startedOnEnabled ? startedOn : nil
        book.finishedOn = finishedOnEnabled ? finishedOn : nil

        // ステータス保存時、対応する日付が未設定なら自動で当日を設定する(明示設定があれば優先)
        if status == .finished && book.finishedOn == nil {
            book.finishedOn = Date()
        }
        if status == .reading && book.startedOn == nil {
            book.startedOn = Date()
        }

        dismiss()
    }
}
