import Foundation
import SwiftData

/// 本ごとに1件ずつ蓄積する「読んだ記録」。
/// Book.review(本全体のメモ)とは別に、読書の都度の所感を時系列で残す。
@Model
final class ReadingNote {
    var id: UUID
    var text: String
    var createdAt: Date
    var book: Book?

    init(text: String, createdAt: Date = Date()) {
        self.id = UUID()
        self.text = text
        self.createdAt = createdAt
    }
}
