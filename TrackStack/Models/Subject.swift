import Foundation
import SwiftData

/// 勉強の科目・資格(例: 簿記 2 級、TOEIC)
@Model
final class Subject {
    var id: UUID
    var name: String
    var examDate: Date?
    /// 目標学習時間(時間単位)。未設定可。
    var targetHours: Int?
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Session.subject)
    var sessions: [Session]

    init(name: String, examDate: Date? = nil, targetHours: Int? = nil) {
        self.id = UUID()
        self.name = name
        self.examDate = examDate
        self.targetHours = targetHours
        self.createdAt = Date()
        self.sessions = []
    }

    /// 起動時に投入するプリセット科目(中小企業診断士1次試験の7科目)。未登録の名前だけ追加される。
    static let presets: [String] = [
        "経済学・経済政策",
        "財務・会計",
        "企業経営理論",
        "運営管理",
        "経営法務",
        "経営情報システム",
        "中小企業経営・中小企業政策",
    ]
}
