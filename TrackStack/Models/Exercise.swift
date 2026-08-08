import Foundation
import SwiftData

enum ExerciseKind: String, Codable, CaseIterable, Identifiable {
    case strength
    case cardio

    var id: String { rawValue }

    var label: String {
        switch self {
        case .strength: "筋トレ"
        case .cardio: "有酸素"
        }
    }
}

/// 種目マスタ(ベンチプレス、ランニング等)
@Model
final class Exercise {
    var id: UUID
    var name: String
    var kindRaw: String
    var createdAt: Date

    var kind: ExerciseKind {
        get { ExerciseKind(rawValue: kindRaw) ?? .strength }
        set { kindRaw = newValue.rawValue }
    }

    init(name: String, kind: ExerciseKind) {
        self.id = UUID()
        self.name = name
        self.kindRaw = kind.rawValue
        self.createdAt = Date()
    }

    /// 初回起動時に投入するプリセット種目
    static let presets: [(String, ExerciseKind)] = [
        ("ベンチプレス", .strength),
        ("スクワット", .strength),
        ("デッドリフト", .strength),
        ("懸垂", .strength),
        ("腹筋", .strength),
        ("ランニング", .cardio),
        ("ウォーキング", .cardio),
        ("サイクリング", .cardio),
    ]
}
