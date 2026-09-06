import Foundation
import Observation

/// ホーム画面ウィジェット等からアプリを開くためのディープリンク。
/// URL スキームは `hitotsumi`(project.yml の CFBundleURLTypes で宣言)。
///
/// - `hitotsumi://start?category=reading|training|study` … その記録を開始する
/// - `hitotsumi://record` … 記録追加フォームを開く
enum DeepLink: Equatable {
    case start(ActivityCategory)
    case record

    /// URL を DeepLink に変換する純粋関数。解釈できない URL は nil(=無視)。
    static func parse(_ url: URL) -> DeepLink? {
        guard url.scheme?.lowercased() == "hitotsumi" else { return nil }

        // `hitotsumi://start` では "start" は host に入る。
        // `hitotsumi:///start` のようなパス形式でも拾えるようにフォールバックする。
        let action = url.host ?? url.pathComponents.first { $0 != "/" }

        switch action {
        case "record":
            return .record
        case "start":
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let raw = components.queryItems?.first(where: { $0.name == "category" })?.value,
                  let category = ActivityCategory(rawValue: raw) else { return nil }
            return .start(category)
        default:
            return nil
        }
    }
}

/// 受け取ったディープリンクを画面側へ受け渡すための入れ物。
/// App が `pending` に積み、ホーム画面(DashboardView)が消費して nil に戻す。
@Observable
final class DeepLinkRouter {
    var pending: DeepLink?

    init(pending: DeepLink? = nil) {
        self.pending = pending
    }
}
