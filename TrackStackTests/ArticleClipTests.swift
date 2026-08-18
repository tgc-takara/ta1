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

/// 見出し欄を入力欄から外したため、一覧の表示名はメモ→URL で代用する
extension ArticleClipTests {

    func testDisplayTitleUsesTitleWhenPresent() {
        let clip = ArticleClip(title: "日銀、利上げ判断へ", urlString: "https://example.com/a", memo: "後で読む")
        XCTAssertEqual(clip.displayTitle, "日銀、利上げ判断へ")
    }

    func testDisplayTitleFallsBackToFirstLineOfMemo() {
        let clip = ArticleClip(title: "", urlString: "https://example.com/a", memo: "所感の1行目\n2行目")
        XCTAssertEqual(clip.displayTitle, "所感の1行目")
    }

    func testDisplayTitleFallsBackToURL() {
        let clip = ArticleClip(title: "", urlString: "nikkei.com/article/1")
        XCTAssertEqual(clip.displayTitle, "nikkei.com/article/1")
    }
}

final class ArticleClipDraftTests: XCTestCase {

    func testDraftWithOnlyURLIsSaved() {
        XCTAssertTrue(ArticleClipDraft(urlString: "nikkei.com/a").hasContent)
    }

    func testDraftWithOnlyMemoIsSaved() {
        XCTAssertTrue(ArticleClipDraft(memo: "所感").hasContent)
    }

    func testEmptyDraftIsNotSaved() {
        XCTAssertFalse(ArticleClipDraft().hasContent)
        XCTAssertFalse(ArticleClipDraft(urlString: "  ", memo: "  ").hasContent)
    }
}
