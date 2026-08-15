import Foundation
import SwiftData

/// 動画・音声の「シリーズ」マスタ(ポッドキャストの番組名 / 動画講座名 / セミナー名)。
/// 本(Book)と同じ立ち位置で、シリーズごとの累積時間と視聴履歴を Session 側から集計する。
/// 型名が PodcastShow なのは、SwiftData の保存済みデータ(エンティティ名)を壊さないため。
@Model
final class PodcastShow {
    var id: UUID
    var name: String
    var memo: String?
    var createdAt: Date

    /// このシリーズを見聴きした記録
    @Relationship(deleteRule: .nullify, inverse: \Session.podcastShow)
    var sessions: [Session]

    init(name: String, memo: String? = nil) {
        self.id = UUID()
        self.name = name
        self.memo = memo
        self.createdAt = Date()
        self.sessions = []
    }
}
