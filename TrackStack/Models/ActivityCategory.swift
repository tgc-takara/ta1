import SwiftUI

/// 記録の 3 大カテゴリ。SwiftData には rawValue(String)で保存する。
enum ActivityCategory: String, Codable, CaseIterable, Identifiable {
    case reading
    case training
    case study

    var id: String { rawValue }

    var label: String {
        switch self {
        case .reading: "読書"
        case .training: "トレーニング"
        case .study: "勉強"
        }
    }

    var symbolName: String {
        switch self {
        case .reading: "book.fill"
        case .training: "dumbbell.fill"
        case .study: "pencil.and.list.clipboard"
        }
    }

    var color: Color {
        switch self {
        case .reading: Theme.dynamicColor(light: 0x2E4A63, dark: 0x7FA3C4)
        case .training: Theme.dynamicColor(light: 0x8A5A2B, dark: 0xC89A63)
        case .study: Theme.dynamicColor(light: 0x5B6E3C, dark: 0x9DB377)
        }
    }
}
