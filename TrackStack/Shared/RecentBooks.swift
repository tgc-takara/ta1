import Foundation
import SwiftData

/// 「最後に読んだ本」を引くための検索。記録フォームの本の選び方(最近読んだ・初期選択)に使う。
enum RecentBooks {
    /// 最後に読んだ順に本を返す(読書セッションの startedAt が新しい順、重複なし)。
    static func latest(limit: Int, in context: ModelContext) -> [Book] {
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.categoryRaw == "reading" },
            sortBy: [SortDescriptor(\Session.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 50
        guard let sessions = try? context.fetch(descriptor) else { return [] }

        var seen = Set<PersistentIdentifier>()
        var result: [Book] = []
        for session in sessions {
            guard let book = session.book, !seen.contains(book.persistentModelID) else { continue }
            seen.insert(book.persistentModelID)
            result.append(book)
            if result.count == limit { break }
        }
        return result
    }

    /// 新規記録の初期選択に使う: 最後に読んだ本のうち、まだ読了していないもの。なければ nil
    static func mostRecentUnfinished(in context: ModelContext) -> Book? {
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.categoryRaw == "reading" },
            sortBy: [SortDescriptor(\Session.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 50
        guard let sessions = try? context.fetch(descriptor) else { return nil }

        var seen = Set<PersistentIdentifier>()
        for session in sessions {
            guard let book = session.book, !seen.contains(book.persistentModelID) else { continue }
            seen.insert(book.persistentModelID)
            if book.status != .finished { return book }
        }
        return nil
    }
}
