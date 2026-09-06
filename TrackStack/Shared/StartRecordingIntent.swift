import AppIntents
import Foundation

/// ウィジェットの「記録開始」ボタン(iOS 17 のインタラクティブウィジェット)から実行される App Intent。
///
/// systemSmall では Link が使えないため Button(intent:) を使う。
/// perform() がウィジェット拡張側のプロセスで走る場合もあるので、URL を直接開くのではなく
/// App Group の UserDefaults に「開きたいディープリンク」を置き、
/// アプリ側(TrackStackApp)が起動・復帰時にそれを読んで既存の onOpenURL 経路と合流させる。
struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "記録を開始"
    static var description = IntentDescription("選んだカテゴリの記録を開始します")
    /// 実行したらアプリを前面に出す(記録画面はアプリ側にあるため)
    static var openAppWhenRun: Bool = true

    /// App Group に置く「保留中のディープリンク」のキー
    static let pendingDeepLinkKey = "pendingDeepLink"

    @Parameter(title: "カテゴリ")
    var categoryRaw: String

    init() {}

    init(category: ActivityCategory) {
        self.categoryRaw = category.rawValue
    }

    /// DeepLink.parse が解釈できる URL 文字列を組み立てる純粋関数(テスト対象)
    static func deepLinkString(for categoryRaw: String) -> String {
        "hitotsumi://start?category=\(categoryRaw)"
    }

    static func deepLinkString(for category: ActivityCategory) -> String {
        deepLinkString(for: category.rawValue)
    }

    /// ウィジェット側: 開きたいディープリンクを App Group に置く。
    static func storePendingDeepLink(categoryRaw: String, in defaults: UserDefaults = WidgetSnapshot.store) {
        defaults.set(deepLinkString(for: categoryRaw), forKey: pendingDeepLinkKey)
    }

    /// アプリ側: 保留中のディープリンクを取り出す。同じリンクを二度処理しないよう、
    /// 取り出しと同時にキーを消す。置かれていない/壊れていれば nil。
    static func takePendingDeepLink(from defaults: UserDefaults = WidgetSnapshot.store) -> URL? {
        guard let string = defaults.string(forKey: pendingDeepLinkKey) else { return nil }
        defaults.removeObject(forKey: pendingDeepLinkKey)
        return URL(string: string)
    }

    func perform() async throws -> some IntentResult {
        Self.storePendingDeepLink(categoryRaw: categoryRaw)
        return .result()
    }
}
