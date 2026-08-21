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
    /// 本のタイトルのスナップショット(本を削除しても記録が「どれだったか」分かるように)
    var bookTitle: String?

    // MARK: 勉強
    var subject: Subject?
    /// 科目名のスナップショット(科目を削除しても記録が「どれだったか」分かるように)
    var subjectName: String?

    // MARK: トレーニング
    @Relationship(deleteRule: .cascade, inverse: \ExerciseLog.session)
    var exerciseLogs: [ExerciseLog]
    /// 使用したメニュー名(参照ではなくスナップショット。メニュー削除後も記録は残る)
    var menuName: String?

    /// 未知の rawValue は既定(勉強)に倒す。カテゴリ不明で記録が消えてしまわないように。
    var category: ActivityCategory {
        get { ActivityCategory(rawValue: categoryRaw) ?? .study }
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
        self.bookTitle = nil
        self.subjectName = nil
        self.exerciseLogs = []
    }
}
