import Foundation
import SwiftData

/// 筋トレ 1 セットの実績(重量 × 回数)
struct SetRecord: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var weightKg: Double
    var reps: Int
}

/// セッション内の種目ごとの実績
@Model
final class ExerciseLog {
    var id: UUID
    /// 種目名のスナップショット(種目マスタ削除後も記録が読めるように)
    var exerciseName: String
    var kindRaw: String
    /// strength のとき: セットの配列
    var sets: [SetRecord]
    /// cardio のとき
    var distanceKm: Double?
    var durationMinutes: Int?
    /// 表示順
    var order: Int

    var session: Session?

    var kind: ExerciseKind {
        get { ExerciseKind(rawValue: kindRaw) ?? .strength }
        set { kindRaw = newValue.rawValue }
    }

    init(exerciseName: String, kind: ExerciseKind, order: Int = 0) {
        self.id = UUID()
        self.exerciseName = exerciseName
        self.kindRaw = kind.rawValue
        self.sets = []
        self.order = order
    }
}
