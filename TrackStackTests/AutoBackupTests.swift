import XCTest
import SwiftData
@testable import TrackStack

final class AutoBackupPolicyTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testIsDueWhenLastRunIsNil() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertTrue(AutoBackupPolicy.isDue(lastRun: nil, now: now, calendar: calendar))
    }

    func testNotDueWhenLastRunIsSameDay() {
        var components = DateComponents()
        components.year = 2026; components.month = 9; components.day = 6
        components.hour = 9; components.minute = 0
        let lastRun = calendar.date(from: components)!
        components.hour = 21; components.minute = 30
        let now = calendar.date(from: components)!

        XCTAssertFalse(AutoBackupPolicy.isDue(lastRun: lastRun, now: now, calendar: calendar))
    }

    func testDueWhenDateHasChangedEvenByOneMinute() {
        var components = DateComponents()
        components.year = 2026; components.month = 9; components.day = 5
        components.hour = 23; components.minute = 59
        let lastRun = calendar.date(from: components)!

        components.day = 6
        components.hour = 0; components.minute = 1
        let now = calendar.date(from: components)!

        XCTAssertTrue(AutoBackupPolicy.isDue(lastRun: lastRun, now: now, calendar: calendar))
    }

    func testNotDueWhenLastRunIsInTheFuture() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let future = now.addingTimeInterval(60 * 60 * 24 * 3)
        XCTAssertFalse(AutoBackupPolicy.isDue(lastRun: future, now: now, calendar: calendar))
    }

    func testBackupFileNamesFormat() {
        var components = DateComponents()
        components.year = 2026; components.month = 9; components.day = 5
        components.hour = 12
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let now = utcCalendar.date(from: components)!

        let names = AutoBackupPolicy.backupFileNames(now: now)
        XCTAssertEqual(names.latest, "hitotsumi-latest.json")
        // ローカルタイムゾーンで yyyy-MM-dd を組み立てるため、実行環境によって前後1日ずれうる日付部分ではなく
        // ファイル名の形式(接頭辞・拡張子)を検証する
        XCTAssertTrue(names.dated.hasPrefix("hitotsumi-"))
        XCTAssertTrue(names.dated.hasSuffix(".json"))
        XCTAssertNotEqual(names.dated, names.latest)
    }
}

final class AutoBackupServiceWriteTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoBackupServiceWriteTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
    }

    func testWriteBackupCreatesLatestAndDatedJSONAndDailyMarkdown() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let jsonData = try XCTUnwrap("{\"app\":\"hitotsumi\"}".data(using: .utf8))
        let markdownFiles: [(filename: String, content: String)] = [
            (filename: "2026-09-05.md", content: "# 9月5日\n"),
            (filename: "2026-09-06.md", content: "# 9月6日\n"),
        ]

        try AutoBackupService.writeBackup(
            jsonData: jsonData, markdownFiles: markdownFiles, to: tempDirectory, now: now
        )

        let folderURL = tempDirectory.appendingPathComponent("ひとつみ", isDirectory: true)
        let names = AutoBackupPolicy.backupFileNames(now: now)

        let latestData = try Data(contentsOf: folderURL.appendingPathComponent(names.latest))
        XCTAssertEqual(latestData, jsonData)

        let datedData = try Data(contentsOf: folderURL.appendingPathComponent(names.dated))
        XCTAssertEqual(datedData, jsonData)

        let dailyURL = folderURL.appendingPathComponent("daily", isDirectory: true)
        for file in markdownFiles {
            let content = try String(contentsOf: dailyURL.appendingPathComponent(file.filename), encoding: .utf8)
            XCTAssertEqual(content, file.content)
        }
    }

    func testWriteBackupOverwritesLatestAndTodaysDatedFileButKeepsOtherDates() throws {
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = day1.addingTimeInterval(60 * 60 * 24)

        let firstData = try XCTUnwrap("{\"day\":1}".data(using: .utf8))
        let secondData = try XCTUnwrap("{\"day\":2}".data(using: .utf8))

        try AutoBackupService.writeBackup(jsonData: firstData, markdownFiles: [], to: tempDirectory, now: day1)
        try AutoBackupService.writeBackup(jsonData: secondData, markdownFiles: [], to: tempDirectory, now: day2)

        let folderURL = tempDirectory.appendingPathComponent("ひとつみ", isDirectory: true)
        let day1Names = AutoBackupPolicy.backupFileNames(now: day1)
        let day2Names = AutoBackupPolicy.backupFileNames(now: day2)

        // latest は常に最新の内容に上書きされる
        let latestData = try Data(contentsOf: folderURL.appendingPathComponent(day1Names.latest))
        XCTAssertEqual(latestData, secondData)

        // 日付付きファイルはそれぞれの日の内容のまま残る
        let day1DatedData = try Data(contentsOf: folderURL.appendingPathComponent(day1Names.dated))
        XCTAssertEqual(day1DatedData, firstData)
        let day2DatedData = try Data(contentsOf: folderURL.appendingPathComponent(day2Names.dated))
        XCTAssertEqual(day2DatedData, secondData)
    }

    func testWriteBackupWithNoMarkdownFilesSkipsDailyFolder() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let jsonData = try XCTUnwrap("{}".data(using: .utf8))

        try AutoBackupService.writeBackup(jsonData: jsonData, markdownFiles: [], to: tempDirectory, now: now)

        let dailyURL = tempDirectory.appendingPathComponent("ひとつみ/daily", isDirectory: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dailyURL.path))
    }
}

final class AutoBackupServiceRunTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        let schema = Schema([
            Session.self, Book.self, BookGenre.self, Subject.self,
            Exercise.self, ExerciseLog.self, WorkoutMenu.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)

        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoBackupServiceRunTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        container = nil
        context = nil
        tempDirectory = nil
    }

    /// run() 本体はセキュリティスコープ付きブックマークの解決に依存し、通常のフォルダURLからは
    /// テストで再現できないため、run() が使う ExportService の出力を writeBackup へ渡す経路だけを検証する。
    func testExportedSessionsCanBeWrittenViaWriteBackup() throws {
        let subject = Subject(name: "簿記2級")
        context.insert(subject)
        let session = Session(category: .study, startedAt: Date(timeIntervalSince1970: 1_700_000_000), durationMinutes: 30)
        session.subject = subject
        context.insert(session)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<Session>(sortBy: [SortDescriptor(\.startedAt, order: .forward)]))
        let jsonData = try ExportService.makeJSON(
            sessions: sessions, books: [], subjects: [subject], exercises: [],
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let markdownFiles = ExportService.makeMarkdownFiles(sessions: sessions)

        try AutoBackupService.writeBackup(
            jsonData: jsonData, markdownFiles: markdownFiles, to: tempDirectory, now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let folderURL = tempDirectory.appendingPathComponent("ひとつみ", isDirectory: true)
        let names = AutoBackupPolicy.backupFileNames(now: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folderURL.appendingPathComponent(names.latest).path))
        XCTAssertFalse(markdownFiles.isEmpty)
    }
}
