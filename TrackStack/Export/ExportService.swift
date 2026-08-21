import Foundation

/// 記録データを JSON / CSV / Obsidian Markdown へ変換する純粋なロジック。
/// UI には依存せず、SwiftData モデルの配列を受け取って Data / String を返すだけの構造にする(ユニットテスト対象)。
enum ExportService {

    // MARK: - JSON

    /// JSON エクスポート全体のペイロード。キーは英語・camelCase、値の自由記述は日本語のまま。
    struct ExportPayload: Encodable {
        var app: String
        var schemaVersion: Int
        var exportedAt: Date
        var sessions: [ExportSession]
        var books: [ExportBook]
        var subjects: [ExportSubject]
        var exercises: [ExportExercise]
    }

    struct ExportSession: Encodable {
        var id: String
        var category: String
        var startedAt: Date
        var durationMinutes: Int
        var note: String?
        var book: ExportSessionBook?
        var subject: ExportSessionSubject?
        var menu: String?
        var exercises: [ExportSessionExercise]?
    }

    struct ExportSessionBook: Encodable {
        var title: String
        var author: String?
        var genre: String?
    }

    struct ExportSessionSubject: Encodable {
        var name: String
    }

    struct ExportSessionExercise: Encodable {
        var name: String
        var bodyPart: String
        var sets: [ExportSetRecord]?
        var distanceKm: Double?
        var durationMinutes: Int?
    }

    struct ExportSetRecord: Encodable {
        var weightKg: Double
        var reps: Int
        var isSingleArm: Bool
    }

    struct ExportBook: Encodable {
        var title: String
        var author: String?
        var genre: String?
        var status: String
        var progressPercent: Int
        var rating: Int?
        var review: String?
        var startedOn: String?
        var finishedOn: String?
    }

    struct ExportSubject: Encodable {
        var name: String
        var examDate: String?
        var targetHours: Int?
        var memo: String?
    }

    struct ExportExercise: Encodable {
        var name: String
        var bodyPart: String
        var memo: String?
    }

    /// ISO8601(タイムゾーン付き)。JSON の startedAt / exportedAt に使う。
    private static let isoDateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = .current
        return formatter
    }()

    /// "yyyy-MM-dd"。startedOn / finishedOn / examDate など日付のみの項目に使う。
    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func makeJSON(
        sessions: [Session],
        books: [Book],
        subjects: [Subject],
        exercises: [Exercise],
        exportedAt: Date
    ) throws -> Data {
        let payload = ExportPayload(
            app: "hitotsumi",
            schemaVersion: 4,
            exportedAt: exportedAt,
            sessions: sessions.map(exportSession),
            books: books.map(exportBook),
            subjects: subjects.map(exportSubject),
            exercises: exercises.map(exportExercise)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(isoDateTimeFormatter.string(from: date))
        }
        return try encoder.encode(payload)
    }

    private static func exportSession(_ session: Session) -> ExportSession {
        var book: ExportSessionBook?
        var subject: ExportSessionSubject?
        var menu: String?
        var exercises: [ExportSessionExercise]?

        switch session.category {
        case .reading:
            if let sourceBook = session.book {
                book = ExportSessionBook(
                    title: sourceBook.title,
                    author: sourceBook.author,
                    genre: sourceBook.genreName
                )
            } else if let title = session.bookTitle {
                // 本を削除済みでもタイトルのスナップショットは残す
                book = ExportSessionBook(title: title, author: nil, genre: nil)
            }
        case .study:
            if let sourceSubject = session.subject {
                subject = ExportSessionSubject(name: sourceSubject.name)
            } else if let name = session.subjectName {
                subject = ExportSessionSubject(name: name)
            }
        case .training:
            menu = session.menuName
            exercises = session.exerciseLogs
                .sorted { $0.order < $1.order }
                .map(exportSessionExercise)
        }

        return ExportSession(
            id: session.id.uuidString,
            category: session.category.rawValue,
            startedAt: session.startedAt,
            durationMinutes: session.durationMinutes,
            note: session.note,
            book: book,
            subject: subject,
            menu: menu,
            exercises: exercises
        )
    }

    private static func exportSessionExercise(_ log: ExerciseLog) -> ExportSessionExercise {
        let isCardio = log.bodyPart.isCardio
        return ExportSessionExercise(
            name: log.exerciseName,
            bodyPart: log.bodyPart.rawValue,
            sets: isCardio ? nil : log.sets.map {
                ExportSetRecord(weightKg: $0.weightKg, reps: $0.reps, isSingleArm: $0.isSingleArm)
            },
            distanceKm: isCardio ? log.distanceKm : nil,
            durationMinutes: isCardio ? log.durationMinutes : nil
        )
    }

    private static func exportBook(_ book: Book) -> ExportBook {
        ExportBook(
            title: book.title,
            author: book.author,
            genre: book.genreName,
            status: book.status.rawValue,
            progressPercent: book.progressPercent,
            rating: book.rating,
            review: book.review,
            startedOn: book.startedOn.map { dateOnlyFormatter.string(from: $0) },
            finishedOn: book.finishedOn.map { dateOnlyFormatter.string(from: $0) }
        )
    }

    private static func exportSubject(_ subject: Subject) -> ExportSubject {
        ExportSubject(
            name: subject.name,
            examDate: subject.examDate.map { dateOnlyFormatter.string(from: $0) },
            targetHours: subject.targetHours,
            memo: subject.memo
        )
    }

    private static func exportExercise(_ exercise: Exercise) -> ExportExercise {
        ExportExercise(
            name: exercise.name,
            bodyPart: exercise.bodyPart.rawValue,
            memo: exercise.memo
        )
    }

    // MARK: - CSV

    /// "date,category,duration_minutes,title,detail,note" のフラット表。RFC4180 に従いエスケープする。
    static func makeCSV(sessions: [Session]) -> String {
        var lines = ["date,category,duration_minutes,title,detail,note"]

        for session in sessions {
            let date = csvDateFormatter.string(from: session.startedAt)
            let category = session.category.label
            let duration = String(session.durationMinutes)
            let title: String
            let detail: String

            switch session.category {
            case .reading:
                title = session.book?.title ?? session.bookTitle ?? ""
                detail = ""
            case .study:
                title = session.subject?.name ?? session.subjectName ?? ""
                detail = ""
            case .training:
                title = session.menuName ?? ""
                detail = session.exerciseLogs
                    .sorted { $0.order < $1.order }
                    .map(\.exerciseName)
                    .joined(separator: "・")
            }

            let note = session.note ?? ""
            let fields = [date, category, duration, title, detail, note].map(csvField)
            lines.append(fields.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    private static let csvDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    /// RFC4180: 値に , " 改行 が含まれる場合はダブルクォートで囲み、内部の " は "" にエスケープする。
    private static func csvField(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    // MARK: - Obsidian Markdown

    /// 日ごとに1ファイル。記録のない日のファイルは作らない。
    static func makeMarkdownFiles(sessions: [Session], calendar: Calendar = .current) -> [(filename: String, content: String)] {
        guard !sessions.isEmpty else { return [] }

        let fileDateFormatter = DateFormatter()
        fileDateFormatter.calendar = calendar
        fileDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        fileDateFormatter.timeZone = calendar.timeZone
        fileDateFormatter.dateFormat = "yyyy-MM-dd"

        let grouped = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.startedAt) }

        return grouped.map { day, daySessions in
            let filename = "\(fileDateFormatter.string(from: day)).md"
            let content = makeMarkdownContent(day: day, sessions: daySessions, dateFormatter: fileDateFormatter)
            return (filename: filename, content: content)
        }
        .sorted { $0.filename < $1.filename }
    }

    private static func makeMarkdownContent(day: Date, sessions: [Session], dateFormatter: DateFormatter) -> String {
        let readingSessions = sessions.filter { $0.category == .reading }
        let trainingSessions = sessions.filter { $0.category == .training }
        let studySessions = sessions.filter { $0.category == .study }

        let readingMinutes = readingSessions.reduce(0) { $0 + $1.durationMinutes }
        let trainingMinutes = trainingSessions.reduce(0) { $0 + $1.durationMinutes }
        let studyMinutes = studySessions.reduce(0) { $0 + $1.durationMinutes }
        let totalMinutes = readingMinutes + trainingMinutes + studyMinutes

        let frontmatter = [
            "---",
            "date: \(dateFormatter.string(from: day))",
            "total_minutes: \(totalMinutes)",
            "reading_minutes: \(readingMinutes)",
            "training_minutes: \(trainingMinutes)",
            "study_minutes: \(studyMinutes)",
            "---",
        ].joined(separator: "\n")

        var sections: [String] = []

        if !readingSessions.isEmpty {
            var lines = ["## 📚 読書 \(readingMinutes)分"]
            for session in readingSessions {
                let title = session.book?.title ?? session.bookTitle ?? ""
                lines.append("- 『\(title)』\(noteSuffix(session.note))")
            }
            sections.append(lines.joined(separator: "\n"))
        }

        if !trainingSessions.isEmpty {
            let menuNames = orderedUnique(trainingSessions.compactMap { $0.menuName }.filter { !$0.isEmpty })
            let menuSuffix = menuNames.isEmpty ? "" : "(\(menuNames.joined(separator: "・")))"
            var lines = ["## 💪 トレーニング \(trainingMinutes)分\(menuSuffix)"]
            // 種目行はセッションをまたいでまとめるため、セッションのメモは見出し直後に引用行で出す
            for session in trainingSessions {
                if let note = session.note, !note.isEmpty {
                    lines.append("> \(note)")
                }
            }
            let logs = trainingSessions
                .flatMap { $0.exerciseLogs }
                .sorted { $0.order < $1.order }
            for log in logs {
                lines.append("- \(log.bodyPart.isCardio ? cardioLine(log) : strengthLine(log))")
            }
            sections.append(lines.joined(separator: "\n"))
        }

        if !studySessions.isEmpty {
            var lines = ["## ✏️ 勉強 \(studyMinutes)分"]
            for session in studySessions {
                let name = session.subject?.name ?? session.subjectName ?? ""
                lines.append("- \(name)\(noteSuffix(session.note))")
            }
            sections.append(lines.joined(separator: "\n"))
        }

        return ([frontmatter] + sections).joined(separator: "\n\n") + "\n"
    }

    /// メモがなければ空文字(「 — メモ」の部分を出さない)
    private static func noteSuffix(_ note: String?) -> String {
        guard let note, !note.isEmpty else { return "" }
        return " — \(note)"
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
        return result
    }

    /// 「60kg×10, 60kg×8」形式。片手セットは「60kg×10(片手)」、マイナス重量はそのまま出す。
    private static func strengthLine(_ log: ExerciseLog) -> String {
        let sets = log.sets.map { set -> String in
            let suffix = set.isSingleArm ? "(片手)" : ""
            return "\(formatWeight(set.weightKg))kg×\(set.reps)\(suffix)"
        }.joined(separator: ", ")
        return sets.isEmpty ? log.exerciseName : "\(log.exerciseName) \(sets)"
    }

    /// 「3.0km 20分」形式。距離・時間が無ければある方だけ出す。
    private static func cardioLine(_ log: ExerciseLog) -> String {
        var parts: [String] = []
        if let distance = log.distanceKm {
            parts.append(String(format: "%.1fkm", distance))
        }
        if let duration = log.durationMinutes {
            parts.append("\(duration)分")
        }
        return parts.isEmpty ? log.exerciseName : "\(log.exerciseName) \(parts.joined(separator: " "))"
    }

    /// 整数値なら小数点を出さず、そうでなければそのまま文字列化する。
    private static func formatWeight(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(value)
    }
}
