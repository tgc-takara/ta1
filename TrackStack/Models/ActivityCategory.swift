import SwiftUI

/// 記録のカテゴリ。SwiftData には rawValue(String)で保存する。
/// 媒体(どういう形で入ってきたか)で切り分ける: 本 / 短い読み物 / 見る聴く / 手を動かす / 体。
/// case の並び順が、そのまま選択肢・凡例・内訳の表示順になる。
enum ActivityCategory: String, Codable, CaseIterable, Identifiable {
    case reading
    case training
    case study
    /// 新聞・Web記事・レポート・白書
    case article
    /// ポッドキャスト・動画講座・セミナー/ウェビナー
    case media

    var id: String { rawValue }

    /// 旧カテゴリ(新聞 / ポッドキャスト)から統合後のカテゴリへの対応。
    /// 起動時の移行と、移行前に保存された記録の読み出しに使う。
    static let legacyRawValues: [String: ActivityCategory] = [
        "newspaper": .article,
        "podcast": .media,
    ]

    var label: String {
        switch self {
        case .reading: "読書"
        case .training: "トレーニング"
        case .study: "勉強"
        case .article: "記事"
        case .media: "動画・音声"
        }
    }

    /// 内訳・チップなど幅の狭い場所で使う短い表記
    var shortLabel: String {
        switch self {
        case .training: "トレ"
        case .media: "動画音声"
        default: label
        }
    }

    var symbolName: String {
        switch self {
        case .reading: "book.fill"
        case .training: "dumbbell.fill"
        case .study: "pencil.and.list.clipboard"
        case .article: "newspaper.fill"
        case .media: "play.rectangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .reading: Theme.dynamicColor(light: 0x2E4A63, dark: 0x7FA3C4)
        case .training: Theme.dynamicColor(light: 0x8A5A2B, dark: 0xC89A63)
        case .study: Theme.dynamicColor(light: 0x5B6E3C, dark: 0x9DB377)
        case .article: Theme.dynamicColor(light: 0x6B4E7D, dark: 0xB79ED0)
        case .media: Theme.dynamicColor(light: 0xA93B2B, dark: 0xD06450)
        }
    }
}
