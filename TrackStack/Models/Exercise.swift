import Foundation
import SwiftData

/// 種目の部位分類。筋トレは部位ごと、有酸素は独立した1分類。
enum BodyPart: String, Codable, CaseIterable, Identifiable {
    case chest
    case shoulders
    case biceps
    case triceps
    case back
    case legs
    case abs
    case cardio

    var id: String { rawValue }

    var label: String {
        switch self {
        case .chest: "胸"
        case .shoulders: "肩"
        case .biceps: "二頭筋"
        case .triceps: "三頭筋"
        case .back: "背中"
        case .legs: "足"
        case .abs: "腹"
        case .cardio: "有酸素"
        }
    }

    /// 入力UIの分岐(セット入力 or 距離・時間入力)
    var isCardio: Bool { self == .cardio }

    var symbolName: String { isCardio ? "figure.run" : "dumbbell" }
}

/// 種目マスタ(ベンチプレス、ランニング等)
@Model
final class Exercise {
    var id: UUID
    var name: String
    /// BodyPart.rawValue。旧データは "strength"(筋トレ2分類時代)の場合があり、起動時に移行する。
    var kindRaw: String
    var createdAt: Date

    var bodyPart: BodyPart {
        get { BodyPart(rawValue: kindRaw) ?? .chest }
        set { kindRaw = newValue.rawValue }
    }

    init(name: String, bodyPart: BodyPart) {
        self.id = UUID()
        self.name = name
        self.kindRaw = bodyPart.rawValue
        self.createdAt = Date()
    }

    /// 初回起動時に投入するプリセット種目
    static let presets: [(String, BodyPart)] = [
        ("ベンチプレス", .chest),
        ("スクワット", .legs),
        ("デッドリフト", .back),
        ("懸垂", .back),
        ("腹筋", .abs),
        ("ランニング", .cardio),
        ("ウォーキング", .cardio),
        ("サイクリング", .cardio),
    ]

    /// 旧2分類("strength")の記録を部位分類へ移行する。種目名がプリセットにあれば対応部位、なければ胸。
    static func migratedBodyPart(name: String) -> BodyPart {
        presets.first(where: { $0.0 == name })?.1 ?? .chest
    }
}
