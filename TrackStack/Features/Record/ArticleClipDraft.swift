import Foundation

/// 新聞の記録を入力中の「読んだ記事」1件分の編集用値型。
/// 保存されていない新規セッションでも入力できるよう、値型で持ってから ArticleClip に変換する。
struct ArticleClipDraft: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var urlString: String
    var memo: String

    init(title: String = "", urlString: String = "", memo: String = "") {
        self.title = title
        self.urlString = urlString
        self.memo = memo
    }

    init(clip: ArticleClip) {
        self.title = clip.title
        self.urlString = clip.urlString ?? ""
        self.memo = clip.memo ?? ""
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// URL かメモのどちらかが入っていれば保存対象にする
    /// (見出しは入力欄から外したので、空でも捨てない)
    var hasContent: Bool {
        !trimmedTitle.isEmpty
            || !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func makeClip(order: Int) -> ArticleClip {
        ArticleClip(
            title: trimmedTitle,
            urlString: urlString.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            memo: memo.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            order: order
        )
    }
}

extension String {
    /// 空文字を nil に落とす(未入力を nil で保存するため)
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
