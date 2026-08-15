import SwiftUI

/// 記録のカテゴリ。SwiftData には rawValue(String)で保存する。
/// case の並び順が、そのまま選択肢・凡例・内訳の表示順になる。
enum ActivityCategory: String, Codable, CaseIterable, Identifiable {
    case reading
    case training
    case study
    case newspaper
    case podcast

    var id: String { rawValue }

    var label: String {
        switch self {
        case .reading: "読書"
        case .training: "トレーニング"
        case .study: "勉強"
        case .newspaper: "新聞"
        case .podcast: "ポッドキャスト"
        }
    }

    /// 内訳・チップなど幅の狭い場所で使う短い表記
    var shortLabel: String {
        switch self {
        case .training: "トレ"
        case .podcast: "音声"
        default: label
        }
    }

    var symbolName: String {
        switch self {
        case .reading: "book.fill"
        case .training: "dumbbell.fill"
        case .study: "pencil.and.list.clipboard"
        case .newspaper: "newspaper.fill"
        case .podcast: "headphones"
        }
    }

    var color: Color {
        switch self {
        case .reading: Theme.dynamicColor(light: 0x2E4A63, dark: 0x7FA3C4)
        case .training: Theme.dynamicColor(light: 0x8A5A2B, dark: 0xC89A63)
        case .study: Theme.dynamicColor(light: 0x5B6E3C, dark: 0x9DB377)
        case .newspaper: Theme.dynamicColor(light: 0x6B4E7D, dark: 0xB79ED0)
        case .podcast: Theme.dynamicColor(light: 0xA93B2B, dark: 0xD06450)
        }
    }
}
