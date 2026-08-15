import Foundation
import SwiftData

/// ポッドキャストの番組マスタ。本(Book)と同じ立ち位置で、
/// 番組ごとの累積時間とエピソード履歴を Session 側から集計する。
@Model
final class PodcastShow {
    var id: UUID
    var name: String
    var memo: String?
    var createdAt: Date

    /// この番組を聴いた記録
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
