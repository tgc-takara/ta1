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
        case .reading: .blue
        case .training: .orange
        case .study: .green
        }
    }
}
