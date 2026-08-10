import SwiftUI
import UIKit

/// アプリ全体の色を集約する「和紙と墨」テーマ。すべてライト/ダーク対応のダイナミックカラー。
/// 朱(shu)は「今日」を示すときにのみ使う特別な色。警告や汎用の強調には使わない。
enum Theme {
    /// 画面全体の背景(地)
    static let paper = dynamicColor(light: 0xF6F3EA, dark: 0x16150F)
    /// カードなど面の背景
    static let surface = dynamicColor(light: 0xFFFDF7, dark: 0x1E1D16)
    /// 本文の文字色
    static let ink = dynamicColor(light: 0x1C1A17, dark: 0xEDEAE2)
    /// 補足文字色
    static let inkSecondary = dynamicColor(light: 0x6B6555, dark: 0xA49D8E)
    /// カード罫線・区切り線
    static let rule = dynamicColor(light: 0xE2DCCC, dark: 0x302E25)
    /// 朱。「今日」を示すときにだけ使う
    static let shu = dynamicColor(light: 0xA93B2B, dark: 0xD06450)

    /// ライト/ダークそれぞれの16進カラーコードからダイナミックな Color を作る
    static func dynamicColor(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension UIColor {
    /// 0xRRGGBB 形式の16進値から不透明なUIColorを作る
    convenience init(hex: UInt32) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}

extension Font {
    /// 数値・見出し用の明朝体(Hiragino Mincho ProN W6)。未対応環境向けに `.fontDesign(.serif)` の併用を推奨。
    static func mincho(size: CGFloat) -> Font {
        .custom("HiraMinProN-W6", size: size)
    }
}

/// カードの共通見た目。角丸3px・1px罫線・Theme.surface背景。影は使わない。
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Theme.rule, lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}
