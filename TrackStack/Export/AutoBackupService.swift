import Foundation
import SwiftData

/// 自動バックアップの実行本体。UserDefaults に保存したフォルダのブックマークを解決し、
/// ExportService の純粋関数(JSON / Markdown)で作った内容をそのフォルダへ書き込む。
enum AutoBackupService {
    /// アプリを開いたとき・バックグラウンドタスク発火時の入り口。
    /// 有効化されていて、フォルダが選ばれていて、かつ「まだ今日分を実行していない」ときだけ実行する。
    static func runIfDue(container: ModelContainer, now: Date = Date()) async {
        guard AutoBackupSettings.loadEnabled(), AutoBackupSettings.loadFolderBookmark() != nil else { return }
        guard AutoBackupPolicy.isDue(lastRun: AutoBackupSettings.loadLastRun(), now: now) else { return }
        try? await run(container: container, now: now)
    }

    /// 手動の「今すぐバックアップ」からも呼ばれる実行本体。
    @MainActor
    static func run(container: ModelContainer, now: Date = Date()) async throws {
        do {
            guard let bookmarkData = AutoBackupSettings.loadFolderBookmark() else {
                throw AutoBackupServiceError.folderNotSelected
            }

            var isStale = false
            let folderURL: URL
            do {
                folderURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [.withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
            } catch {
                throw AutoBackupServiceError.bookmarkResolutionFailed
            }

            guard folderURL.startAccessingSecurityScopedResource() else {
                throw AutoBackupServiceError.accessDenied
            }
            defer { folderURL.stopAccessingSecurityScopedResource() }

            if isStale {
                // 権限は維持されているはずなので、取り直して保存し直すだけで次回以降も使える
                if let refreshed = try? folderURL.bookmarkData() {
                    AutoBackupSettings.saveFolderBookmark(refreshed)
                }
            }

            let context = ModelContext(container)
            let sessions = try context.fetch(
                FetchDescriptor<Session>(sortBy: [SortDescriptor(\.startedAt, order: .forward)])
            )
            let books = try context.fetch(FetchDescriptor<Book>())
            let subjects = try context.fetch(FetchDescriptor<Subject>())
            let exercises = try context.fetch(FetchDescriptor<Exercise>())

            let jsonData = try ExportService.makeJSON(
                sessions: sessions, books: books, subjects: subjects, exercises: exercises,
                exportedAt: now
            )
            let markdownFiles = ExportService.makeMarkdownFiles(sessions: sessions)

            try writeBackup(jsonData: jsonData, markdownFiles: markdownFiles, to: folderURL, now: now)

            AutoBackupSettings.saveLastRun(now)
            AutoBackupSettings.saveLastError(nil)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            AutoBackupSettings.saveLastError(message)
            throw error
        }
    }

    /// 保存先フォルダ直下に「ひとつみ」サブフォルダを作り、JSON(latest / 日付付き)と
    /// 日別 Markdown を書き込む。保存先URLを直接受け取る形にして、テストから一時ディレクトリで検証できるようにしている。
    static func writeBackup(
        jsonData: Data,
        markdownFiles: [(filename: String, content: String)],
        to rootURL: URL,
        now: Date
    ) throws {
        let fileManager = FileManager.default
        let folderURL = rootURL.appendingPathComponent("ひとつみ", isDirectory: true)
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let names = AutoBackupPolicy.backupFileNames(now: now)
        try coordinatedWrite(jsonData, to: folderURL.appendingPathComponent(names.latest))
        try coordinatedWrite(jsonData, to: folderURL.appendingPathComponent(names.dated))

        guard !markdownFiles.isEmpty else { return }
        let dailyURL = folderURL.appendingPathComponent("daily", isDirectory: true)
        try fileManager.createDirectory(at: dailyURL, withIntermediateDirectories: true)
        for file in markdownFiles {
            guard let data = file.content.data(using: .utf8) else { continue }
            try coordinatedWrite(data, to: dailyURL.appendingPathComponent(file.filename))
        }
    }

    /// クラウド同期フォルダ(iCloud Drive / Google Drive 等)対策で NSFileCoordinator を通して書き込む。
    private static func coordinatedWrite(_ data: Data, to url: URL) throws {
        var coordinatorError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: [.forReplacing], error: &coordinatorError) { writingURL in
            do {
                try data.write(to: writingURL, options: .atomic)
            } catch {
                writeError = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let writeError { throw writeError }
    }
}

enum AutoBackupServiceError: LocalizedError {
    case folderNotSelected
    case bookmarkResolutionFailed
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .folderNotSelected: "保存先フォルダが設定されていません"
        case .bookmarkResolutionFailed: "保存先フォルダを開けませんでした。フォルダを選び直してください"
        case .accessDenied: "保存先フォルダへのアクセスが許可されませんでした"
        }
    }
}
