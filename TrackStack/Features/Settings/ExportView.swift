import SwiftUI
import SwiftData
import UIKit

/// 設定 > データ > エクスポート。JSON / CSV / Obsidian Markdown の3形式をファイル化してシェアシートで共有する。
struct ExportView: View {
    @Query private var sessions: [Session]
    @Query private var books: [Book]
    @Query private var subjects: [Subject]
    @Query private var exercises: [Exercise]
    @Query private var podcastShows: [PodcastShow]

    @State private var isExporting = false
    @State private var shareURL: URL?
    @State private var isShowingShareSheet = false
    @State private var errorMessage: String?
    @State private var showingError = false

    // この画面は静的な3行だけなので List は使わず、素の VStack + ScrollView で組む
    // (Dashboard 等、既存画面の cardStyle() パターンに合わせる)。
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                exportRow(
                    title: "JSON(AI分析用)",
                    subtitle: "全記録を1ファイルに。AIに渡して分析できます",
                    action: exportJSON
                )
                Divider().padding(.leading, 16)
                exportRow(
                    title: "CSV(表計算用)",
                    subtitle: "セッション一覧を表計算ソフトで開けます",
                    action: exportCSV
                )
                Divider().padding(.leading, 16)
                exportRow(
                    title: "Obsidian用 Markdown",
                    subtitle: "日ごとのノートにまとめてzip書き出し。Vaultにそのまま取り込めます",
                    action: exportMarkdown
                )
            }
            .cardStyle()
            .padding(.horizontal)
            .padding(.top)

            if isExporting {
                HStack(spacing: 6) {
                    ProgressView()
                    Text("書き出し中…")
                }
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
                .padding(.top, 8)
            }
        }
        .background(Theme.paper)
        .navigationTitle("エクスポート")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingShareSheet, onDismiss: { shareURL = nil }) {
            if let shareURL {
                ShareSheet(items: [shareURL])
            }
        }
        .alert("エクスポートに失敗しました", isPresented: $showingError, presenting: errorMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    @ViewBuilder
    private func exportRow(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isExporting)
    }

    // MARK: - Actions

    private func exportJSON() {
        isExporting = true
        defer { isExporting = false }
        do {
            let data = try ExportService.makeJSON(
                sessions: sessions, books: books, subjects: subjects, exercises: exercises,
                podcastShows: podcastShows,
                exportedAt: Date()
            )
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName(ext: "json"))
            try data.write(to: url, options: .atomic)
            presentShare(url)
        } catch {
            presentError(error)
        }
    }

    private func exportCSV() {
        isExporting = true
        defer { isExporting = false }
        let csv = ExportService.makeCSV(sessions: sessions)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName(ext: "csv"))
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            presentShare(url)
        } catch {
            presentError(error)
        }
    }

    private func exportMarkdown() {
        isExporting = true
        defer { isExporting = false }

        let files = ExportService.makeMarkdownFiles(sessions: sessions)
        guard !files.isEmpty else {
            presentError(ExportViewError.noRecords)
            return
        }

        // zip を展開したときのフォルダ名が「ひとつみ」になるよう、
        // 作業用ディレクトリ(UUID付き)の中に「ひとつみ」フォルダを作り、そちらを zip 化する。
        // (作業用ディレクトリ名をそのまま zip 化すると Vault に UUID 付きのフォルダができてしまう)
        let workURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-\(UUID().uuidString)", isDirectory: true)
        let folderURL = workURL.appendingPathComponent("ひとつみ", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: workURL) }

            for file in files {
                let fileURL = folderURL.appendingPathComponent(file.filename)
                try file.content.write(to: fileURL, atomically: true, encoding: .utf8)
            }

            let zipURL = try zipFolder(named: "hitotsumi-\(dateStamp())", at: folderURL)
            presentShare(zipURL)
        } catch {
            presentError(error)
        }
    }

    // MARK: - Helpers

    /// フォルダを zip 化する。外部ライブラリを使わず、標準の NSFileCoordinator(.forUploading)を利用する。
    private func zipFolder(named name: String, at folderURL: URL) throws -> URL {
        // coordinate() が accessor に渡す URL はクロージャ実行中しか有効でない(戻った後は破棄されうる)ため、
        // コピーは必ずクロージャの内側で行う。
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).zip")
        if FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.removeItem(at: destination)
        }

        var coordinatorError: NSError?
        var copyError: Error?

        NSFileCoordinator().coordinate(readingItemAt: folderURL, options: [.forUploading], error: &coordinatorError) { zippedURL in
            do {
                try FileManager.default.copyItem(at: zippedURL, to: destination)
            } catch {
                copyError = error
            }
        }

        if let coordinatorError {
            throw coordinatorError
        }
        if let copyError {
            throw copyError
        }
        guard FileManager.default.fileExists(atPath: destination.path) else {
            throw ExportViewError.zipFailed
        }
        return destination
    }

    private func presentShare(_ url: URL) {
        shareURL = url
        isShowingShareSheet = true
    }

    private func presentError(_ error: Error) {
        errorMessage = error.localizedDescription
        showingError = true
    }

    private func fileName(ext: String) -> String {
        "hitotsumi-\(dateStamp()).\(ext)"
    }

    private func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

private enum ExportViewError: LocalizedError {
    case zipFailed
    case noRecords

    var errorDescription: String? {
        switch self {
        case .zipFailed: "zip ファイルの作成に失敗しました"
        case .noRecords: "書き出せる記録がありません"
        }
    }
}

/// UIActivityViewController を SwiftUI から使うためのラッパー。
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
