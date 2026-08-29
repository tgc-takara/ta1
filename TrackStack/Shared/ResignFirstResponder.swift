import SwiftUI
import UIKit

/// 入力画面でキーボードを任意に閉じられるようにする共通モディファイア。
/// 下スワイプで閉じる + キーボード上部に「閉じる」ボタンを出す。
struct KeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("閉じる") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                        )
                    }
                }
            }
    }
}

extension View {
    func keyboardDismissable() -> some View { modifier(KeyboardDismissModifier()) }
}
