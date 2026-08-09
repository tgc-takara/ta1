import SwiftUI
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

    var symbolName: String {
        switch self {
        case .chest: "figure.strengthtraining.traditional"
        case .shoulders: "figure.strengthtraining.functional"
        case .biceps: "figure.arms.open"
        case .triceps: "figure.boxing"
        case .back: "figure.rower"
        case .legs: "figure.stair.stepper"
        case .abs: "figure.core.training"
        case .cardio: "figure.run"
        }
    }

    var color: Color {
        switch self {
        case .chest: .red
        case .shoulders: .orange
        case .biceps: .purple
        case .triceps: .pink
        case .back: .blue
        case .legs: .green
        case .abs: .mint
        case .cardio: .cyan
        }
    }
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

    /// 起動時に投入するプリセット種目。未登録の名前だけ追加される(既存データは重複しない)。
    static let presets: [(String, BodyPart)] = [
        // 胸
        ("ベンチプレス", .chest),
        ("インクラインベンチプレス", .chest),
        ("ダンベルベンチプレス", .chest),
        ("インクラインダンベルベンチプレス", .chest),
        ("スミスマシンベンチプレス", .chest),
        ("スミスマシンインクラインベンチプレス", .chest),
        ("チェストプレスマシン", .chest),
        ("インクラインチェストプレスマシン", .chest),
        ("ペックフライ", .chest),
        ("スタンディングマルチフライ", .chest),
        ("ダンベルフライ", .chest),
        ("インクラインダンベルフライ", .chest),
        ("ローケーブルフライ", .chest),
        ("ケーブルクロスオーバー上部", .chest),
        ("ケーブルクロスオーバー中部", .chest),
        ("ディップス", .chest),
        ("腕立て伏せ", .chest),
        // 背中
        ("デッドリフト", .back),
        ("懸垂", .back),
        ("チンニング", .back),
        ("パラレルグリップチンニング", .back),
        ("ラットプルダウン", .back),
        ("パラレルグリップラットプルダウン", .back),
        ("プレートローテッドプルダウン", .back),
        ("シーテッドケーブルロウ", .back),
        ("シーテッドロウマシン", .back),
        ("プレートローテッドシーテッドロウ", .back),
        ("ワンハンドダンベルロウ", .back),
        ("Tバーロウマシン", .back),
        ("ローローマシン", .back),
        ("ハイローマシン", .back),
        ("スミスマシンデッドリフト", .back),
        ("スミスマシンベントオーバーロウ", .back),
        ("バックエクステンション", .back),
        ("ぶら下がり", .back),
        // 肩
        ("オーバーヘッドプレス", .shoulders),
        ("スミスマシンオーバーヘッドプレス", .shoulders),
        ("ショルダープレスマシン", .shoulders),
        ("ダンベルショルダープレス", .shoulders),
        ("アーノルドプレス", .shoulders),
        ("ダンベルサイドレイズ", .shoulders),
        ("サイドレイズマシン", .shoulders),
        ("ケーブルサイドレイズ", .shoulders),
        ("ケーブルワンハンドサイドレイズ", .shoulders),
        ("インクラインサイドレイズ", .shoulders),
        ("ケーブルフロントレイズ", .shoulders),
        ("リアレイズ", .shoulders),
        ("リアデルトフライマシン", .shoulders),
        ("フェイスプル", .shoulders),
        ("バーベルアップライトロウ", .shoulders),
        ("ケーブルアップライトロウ", .shoulders),
        ("スミスマシンアップライトロウ", .shoulders),
        ("クリーンアンドジャーク", .shoulders),
        ("JMプレス", .shoulders),
        // 二頭筋
        ("バーベルカール", .biceps),
        ("ケーブルカール", .biceps),
        ("インクラインダンベルカール", .biceps),
        ("インクラインハンマーカール", .biceps),
        ("ケーブルハンマーカール", .biceps),
        ("アームカールマシン", .biceps),
        ("ダンベルリストカール", .biceps),
        ("ダンベルリバースリストカール", .biceps),
        // 三頭筋
        ("ケーブルプレスダウン", .triceps),
        ("ケーブルトライセプスエクステンション", .triceps),
        ("ナローベンチプレス", .triceps),
        ("スミスマシンナローベンチプレス", .triceps),
        ("クローズグリップベンチプレス", .triceps),
        ("ダンベルキックバック", .triceps),
        ("シーテッドダンベルフレンチプレス", .triceps),
        ("ベンチディップス", .triceps),
        ("ディップ", .triceps),
        // 足
        ("スクワット", .legs),
        ("バーベルスクワット", .legs),
        ("スミスマシンスクワット", .legs),
        ("ハックスクワットマシン", .legs),
        ("レッグプレス", .legs),
        ("シーテッドレッグプレス", .legs),
        ("レッグエクステンション", .legs),
        ("シーテッドレッグカール", .legs),
        ("バーベルブルガリアンスプリットスクワット", .legs),
        ("ダンベルブルガリアンスプリットスクワット", .legs),
        ("ダンベルランジ", .legs),
        ("ヒップスラスト", .legs),
        ("バーベルヒップスラスト", .legs),
        ("ヒップアブダクションマシン", .legs),
        ("インナーサイマシン", .legs),
        ("グルート", .legs),
        ("スタンディングカーフレイズ", .legs),
        ("バーベルスタンディングカーフレイズ", .legs),
        ("シーテッドカーフレイズ", .legs),
        ("カーフレイズ", .legs),
        // 腹
        ("腹筋", .abs),
        ("アブドミナルクランチマシン", .abs),
        ("クランチ", .abs),
        ("レッグレイズ", .abs),
        ("レッグレイズマシン", .abs),
        ("ハンギングレッグレイズ", .abs),
        ("プランク", .abs),
        ("45度サイドベンド", .abs),
        ("加重デクラインクランチ", .abs),
        ("ロータリートーソ", .abs),
        // 有酸素
        ("ランニング", .cardio),
        ("ウォーキング", .cardio),
        ("サイクリング", .cardio),
    ]

    /// 旧2分類("strength")の記録を部位分類へ移行する。種目名がプリセットにあれば対応部位、なければ胸。
    static func migratedBodyPart(name: String) -> BodyPart {
        presets.first(where: { $0.0 == name })?.1 ?? .chest
    }
}
