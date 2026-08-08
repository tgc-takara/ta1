import Foundation
import SwiftData

/// メニュー内の 1 種目とデフォルトのセット構成。
/// 種目マスタへの参照ではなく名前のスナップショットで持つ(Codable でネスト保存するため)。
struct MenuItem: Codable, Hashable {
    var exerciseName: String
    var kindRaw: String
    var defaultSets: [SetRecord]
    var defaultDistanceKm: Double?
    var defaultDurationMinutes: Int?

    var kind: ExerciseKind {
        ExerciseKind(rawValue: kindRaw) ?? .strength
    }
}

/// トレーニングメニュー(テンプレート)。例: 「胸の日」
/// あくまで入力の雛形であり、記録実体は常に Session + ExerciseLog に落ちる。
@Model
final class WorkoutMenu {
    var id: UUID
    var name: String
    var items: [MenuItem]
    var createdAt: Date

    init(name: String, items: [MenuItem] = []) {
        self.id = UUID()
        self.name = name
        self.items = items
        self.createdAt = Date()
    }
}
