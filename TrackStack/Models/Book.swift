import Foundation
import SwiftData

enum BookStatus: String, Codable, CaseIterable, Identifiable {
    case wantToRead
    case reading
    case finished

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wantToRead: "読みたい"
        case .reading: "読書中"
        case .finished: "読了"
        }
    }
}

@Model
final class Book {
    var id: UUID
    var title: String
    var author: String?
    var statusRaw: String
    /// 最新の進捗(0–100)。セッション記録時に更新される。
    var progressPercent: Int
    var rating: Int?
    var review: String?
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Session.book)
    var sessions: [Session]

    var status: BookStatus {
        get { BookStatus(rawValue: statusRaw) ?? .wantToRead }
        set { statusRaw = newValue.rawValue }
    }

    init(title: String, author: String? = nil, status: BookStatus = .wantToRead) {
        self.id = UUID()
        self.title = title
        self.author = author
        self.statusRaw = status.rawValue
        self.progressPercent = 0
        self.createdAt = Date()
        self.sessions = []
    }
}
