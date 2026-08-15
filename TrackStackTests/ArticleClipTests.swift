import XCTest
@testable import TrackStack

/// 記事クリップの URL 解釈(スキーム補完)を検証する。
/// 入力欄には "nikkei.com/..." のようにスキームなしで貼られることが多いため。
final class ArticleClipTests: XCTestCase {

    func testURLKeepsExplicitScheme() {
        let clip = ArticleClip(title: "記事", urlString: "https://example.com/a")
        XCTAssertEqual(clip.url?.absoluteString, "https://example.com/a")
    }

    func testURLAddsHTTPSWhenSchemeIsMissing() {
        let clip = ArticleClip(title: "記事", urlString: "nikkei.com/article/1")
        XCTAssertEqual(clip.url?.absoluteString, "https://nikkei.com/article/1")
    }

    func testURLIsNilWhenNotEntered() {
        XCTAssertNil(ArticleClip(title: "記事").url)
        XCTAssertNil(ArticleClip(title: "記事", urlString: "").url)
    }
}
