import Foundation
import SwiftData

enum BookStatus: String, Codable, CaseIterable, Identifiable {
    case wantToRead
    case reading
    case finished

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wantToRead: "積読"
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
    /// ジャンル名のスナップショット(設定のジャンルマスタから選択。マスタ削除後も本側の表示は残る)
    var genreName: String?
    /// 表紙写真(JPEG)。サイズが大きいので外部ストレージに逃がす。
    @Attribute(.externalStorage)
    var coverImageData: Data?
    var statusRaw: String
    /// 最新の進捗(0–100)。セッション記録時に更新される。
    var progressPercent: Int
    var rating: Int?
    var review: String?
    var createdAt: Date
    /// 読み始めた日(任意)。ユーザーが未設定なら nil。
    var startedOn: Date?
    /// 読み終わった日(任意)。読了時に未設定なら自動で当日を設定する。
    var finishedOn: Date?

    @Relationship(deleteRule: .nullify, inverse: \Session.book)
    var sessions: [Session]

    var status: BookStatus {
        get { BookStatus(rawValue: statusRaw) ?? .wantToRead }
        set { statusRaw = newValue.rawValue }
    }

    init(title: String, author: String? = nil, genreName: String? = nil, status: BookStatus = .wantToRead) {
        self.id = UUID()
        self.title = title
        self.author = author
        self.genreName = genreName
        self.statusRaw = status.rawValue
        self.progressPercent = 0
        self.createdAt = Date()
        self.startedOn = nil
        self.finishedOn = nil
        self.sessions = []
    }
}
