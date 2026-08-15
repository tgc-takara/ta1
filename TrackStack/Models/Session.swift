import Foundation
import SwiftData

/// すべてのカテゴリ共通の記録単位。
/// カテゴリ固有の情報(書籍・科目・種目実績)は関連エンティティに持たせ、
/// 横断集計は Session だけで完結させる。
@Model
final class Session {
    var id: UUID
    /// ActivityCategory.rawValue。SwiftData の #Predicate で扱いやすいよう String で保持。
    var categoryRaw: String
    var startedAt: Date
    var durationMinutes: Int
    var note: String?

    // MARK: 読書
    var book: Book?

    // MARK: 勉強
    var subject: Subject?

    // MARK: トレーニング
    @Relationship(deleteRule: .cascade, inverse: \ExerciseLog.session)
    var exerciseLogs: [ExerciseLog]
    /// 使用したメニュー名(参照ではなくスナップショット。メニュー削除後も記録は残る)
    var menuName: String?

    // MARK: 新聞
    /// その日読んだ記事のクリップ
    @Relationship(deleteRule: .cascade, inverse: \ArticleClip.session)
    var articleClips: [ArticleClip]

    // MARK: 動画・音声
    /// シリーズ(番組名 / 動画講座名 / セミナー名)
    var podcastShow: PodcastShow?
    /// 回・エピソードのタイトル(任意)
    var episodeTitle: String?

    /// 旧カテゴリ("newspaper" / "podcast")で保存された記録も、統合後のカテゴリとして読める
    var category: ActivityCategory {
        get {
            ActivityCategory(rawValue: categoryRaw)
                ?? ActivityCategory.legacyRawValues[categoryRaw]
                ?? .study
        }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        category: ActivityCategory,
        startedAt: Date,
        durationMinutes: Int,
        note: String? = nil
    ) {
        self.id = UUID()
        self.categoryRaw = category.rawValue
        self.startedAt = startedAt
        self.durationMinutes = durationMinutes
        self.note = note
        self.exerciseLogs = []
        self.articleClips = []
    }
}
