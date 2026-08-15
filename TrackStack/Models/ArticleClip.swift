import Foundation
import SwiftData

/// 新聞の記録にぶら下がる「読んだ記事」1件。
/// 1日1件の新聞セッションに対して、読んだ記事を何本でも足せるようにする。
@Model
final class ArticleClip {
    var id: UUID
    var title: String
    /// 記事URL(任意)。空文字ではなく nil で持つ。
    var urlString: String?
    var memo: String?
    /// セッション内の並び順(入力順を保つ)
    var order: Int
    var session: Session?

    /// 開ける URL があれば返す。スキームのない入力は https:// を補う。
    var url: URL? {
        guard let urlString, !urlString.isEmpty else { return nil }
        if let url = URL(string: urlString), url.scheme != nil { return url }
        return URL(string: "https://\(urlString)")
    }

    init(title: String, urlString: String? = nil, memo: String? = nil, order: Int = 0) {
        self.id = UUID()
        self.title = title
        self.urlString = urlString
        self.memo = memo
        self.order = order
    }
}
