import SwiftUI

/// 数値入力欄。タップして入力を始めたとき、キャレットが必ず末尾(右端)に来る。
///
/// SwiftUI の TextField はキャレット位置を直接指定できないため、
/// フォーカスを得た瞬間に値を空にして即座に戻すことで末尾へ送る。
/// (UITextField を UIViewRepresentable で包む方法は、List の行内でタップを
///  受け取れなかったため採用していない)
private struct NumberFieldBase: View {
    @Binding var text: String
    let placeholder: String
    let keyboardType: UIKeyboardType

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboardType)
            .multilineTextAlignment(.trailing)
            .focused($isFocused)
            .onChange(of: isFocused) { _, focused in
                guard focused else { return }
                let current = text
                text = ""
                // 同じ更新サイクルで戻すとキャレットが移動しないため次のループへ回す
                DispatchQueue.main.async { text = current }
            }
    }
}

/// 重量(小数可)用。空欄は 0 として扱う。
struct WeightField: View {
    @Binding var value: Double
    var placeholder: String = "kg"

    @State private var text: String = ""

    var body: some View {
        NumberFieldBase(text: $text, placeholder: placeholder, keyboardType: .numbersAndPunctuation)
            .onAppear { text = Self.format(value) }
            .onChange(of: text) { _, newText in
                // 入力途中(空文字や "-" だけ)は 0 とみなす
                value = Double(newText) ?? 0
            }
            .onChange(of: value) { _, newValue in
                // 符号反転など外部から書き換えられたときに表示を追従させる
                if Double(text) != newValue {
                    text = Self.format(newValue)
                }
            }
    }

    /// 整数なら小数点を出さない(60.0 ではなく 60)
    static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

/// 回数など整数用。空欄は 0 として扱う。
struct RepsField: View {
    @Binding var value: Int
    var placeholder: String = "回"

    @State private var text: String = ""

    var body: some View {
        NumberFieldBase(text: $text, placeholder: placeholder, keyboardType: .numberPad)
            .onAppear { text = String(value) }
            .onChange(of: text) { _, newText in
                value = Int(newText) ?? 0
            }
            .onChange(of: value) { _, newValue in
                if Int(text) != newValue {
                    text = String(newValue)
                }
            }
    }
}
