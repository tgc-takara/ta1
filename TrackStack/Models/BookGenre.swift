import Foundation
import SwiftData

/// 読書ジャンルのマスタ。設定画面で任意に登録・削除する。
/// Book 側は名前のスナップショット(genreName)で保持するため、削除しても既存の本は壊れない。
@Model
final class BookGenre {
    var id: UUID
    var name: String
    var createdAt: Date
    /// ジャンルメモ(任意)
    var memo: String?

    init(name: String, memo: String? = nil) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.memo = memo
    }
}
