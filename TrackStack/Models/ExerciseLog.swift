import Foundation
import SwiftData

/// 筋トレ 1 セットの実績(重量 × 回数)。
/// 重量はマイナス値も許容する(加重で負荷を軽くするアシスト系種目のため)。
struct SetRecord: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var weightKg: Double
    var reps: Int
    /// 片手(左右別々)で行ったセットかどうか
    var isSingleArm: Bool = false

    init(weightKg: Double, reps: Int, isSingleArm: Bool = false) {
        self.id = UUID()
        self.weightKg = weightKg
        self.reps = reps
        self.isSingleArm = isSingleArm
    }

    private enum CodingKeys: String, CodingKey {
        case id, weightKg, reps, isSingleArm
    }

    // isSingleArm を持たない旧データも読めるように decodeIfPresent で補う
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.weightKg = try container.decode(Double.self, forKey: .weightKg)
        self.reps = try container.decode(Int.self, forKey: .reps)
        self.isSingleArm = try container.decodeIfPresent(Bool.self, forKey: .isSingleArm) ?? false
    }
}

/// セッション内の種目ごとの実績
@Model
final class ExerciseLog {
    var id: UUID
    /// 種目名のスナップショット(種目マスタ削除後も記録が読めるように)
    var exerciseName: String
    /// BodyPart.rawValue。旧データは "strength" の場合があり、起動時に移行する。
    var kindRaw: String
    /// 筋トレ系のとき: セットの配列
    var sets: [SetRecord]
    /// cardio のとき
    var distanceKm: Double?
    var durationMinutes: Int?
    /// cardio のうち階数計測(階段)のとき
    var floorsUp: Int?
    var floorsDown: Int?
    /// 表示順
    var order: Int

    var session: Session?

    var bodyPart: BodyPart {
        get { BodyPart(rawValue: kindRaw) ?? .chest }
        set { kindRaw = newValue.rawValue }
    }

    init(exerciseName: String, bodyPart: BodyPart, order: Int = 0) {
        self.id = UUID()
        self.exerciseName = exerciseName
        self.kindRaw = bodyPart.rawValue
        self.sets = []
        self.order = order
    }
}
