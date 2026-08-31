import SwiftUI
import UIKit

/// スクリーンショットして投稿できるカードの下に添える共有ボタン群。
/// 「スクショを撮って投稿できます」キャプション + X / Instagram を開くボタン(横並び)。
struct SNSShareButtons: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("スクリーンショットを撮って投稿できます")
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)

            HStack(spacing: 12) {
                Button {
                    open(Self.xURL)
                } label: {
                    Label("Xを開く", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    open(Self.instagramURL)
                } label: {
                    Label("Instagramを開く", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    /// アプリが入っていれば専用スキームで、なければ Web で開く
    private static let xURL = (app: URL(string: "twitter://post"), web: URL(string: "https://x.com/compose/post")!)
    private static let instagramURL = (app: URL(string: "instagram://app"), web: URL(string: "https://www.instagram.com/")!)

    private func open(_ urls: (app: URL?, web: URL)) {
        if let app = urls.app, UIApplication.shared.canOpenURL(app) {
            UIApplication.shared.open(app)
        } else {
            UIApplication.shared.open(urls.web)
        }
    }
}
