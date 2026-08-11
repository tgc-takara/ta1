import XCTest
import SwiftData
@testable import TrackStack

final class ExportServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    /// タイムゾーンに依存せずテストを再現できるよう、Markdown 系テストは固定タイムゾーンの Calendar を使う。
    private var jstCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    override func setUpWithError() throws {
        let schema = Schema([
            Session.self, Book.self, BookGenre.self, Subject.self,
            Exercise.self, ExerciseLog.self, WorkoutMenu.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    // MARK: - JSON

    func testJSONBasicFieldsAndSessionCount() throws {
        let book = Book(title: "テスト本", author: "著者A")
        context.insert(book)
        let reading = Session(category: .reading, startedAt: Date(), durationMinutes: 30)
        reading.book = book
        context.insert(reading)

        let subject = Subject(name: "簿記2級")
        context.insert(subject)
        let study = Session(category: .study, startedAt: Date(), durationMinutes: 45, note: "過去問3回分")
        study.subject = subject
        context.insert(study)

        let data = try ExportService.makeJSON(
            sessions: [reading, study], books: [book], subjects: [subject], exercises: [],
            exportedAt: Date()
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["app"] as? String, "hitotsumi")
        XCTAssertEqual(json["schemaVersion"] as? Int, 1)
        let sessions = try XCTUnwrap(json["sessions"] as? [[String: Any]])
        XCTAssertEqual(sessions.count, 2)
    }

    func testJSONTrainingSessionIncludesExercisesAndSets() throws {
        let exercise = Exercise(name: "ベンチプレス", bodyPart: .chest)
        context.insert(exercise)

        let training = Session(category: .training, startedAt: Date(), durationMinutes: 60)
        training.menuName = "胸の日"
        let log = ExerciseLog(exerciseName: "ベンチプレス", bodyPart: .chest, order: 0)
        log.sets = [
            SetRecord(weightKg: 60, reps: 10),
            SetRecord(weightKg: -20, reps: 8, isSingleArm: true),
        ]
        log.session = training
        training.exerciseLogs = [log]
        context.insert(training)
        context.insert(log)

        let data = try ExportService.makeJSON(
            sessions: [training], books: [], subjects: [], exercises: [exercise],
            exportedAt: Date()
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let sessions = try XCTUnwrap(json["sessions"] as? [[String: Any]])
        let trainingJSON = try XCTUnwrap(sessions.first)

        XCTAssertEqual(trainingJSON["menu"] as? String, "胸の日")
        let exercises = try XCTUnwrap(trainingJSON["exercises"] as? [[String: Any]])
        XCTAssertEqual(exercises.count, 1)
        XCTAssertEqual(exercises.first?["bodyPart"] as? String, "chest")

        let sets = try XCTUnwrap(exercises.first?["sets"] as? [[String: Any]])
        XCTAssertEqual(sets.count, 2)
        XCTAssertEqual(sets.first?["weightKg"] as? Double, 60)
        XCTAssertEqual(sets.first?["isSingleArm"] as? Bool, false)
        XCTAssertEqual(sets.last?["weightKg"] as? Double, -20)
        XCTAssertEqual(sets.last?["isSingleArm"] as? Bool, true)
    }

    /// 本の「読んだ記録」は読書セッションそのもの。セッション側に本の情報が出ることを確認する。
    func testJSONReadingSessionCarriesBook() throws {
        let book = Book(title: "テスト本", author: "著者A")
        context.insert(book)
        let session = Session(
            category: .reading,
            startedAt: Date(timeIntervalSince1970: 1000),
            durationMinutes: 45,
            note: "第1章まで"
        )
        session.book = book
        context.insert(session)

        let data = try ExportService.makeJSON(
            sessions: [session], books: [book], subjects: [], exercises: [],
            exportedAt: Date()
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let sessions = try XCTUnwrap(json["sessions"] as? [[String: Any]])
        let sessionJSON = try XCTUnwrap(sessions.first)
        let bookJSON = try XCTUnwrap(sessionJSON["book"] as? [String: Any])

        XCTAssertEqual(bookJSON["title"] as? String, "テスト本")
        XCTAssertEqual(sessionJSON["durationMinutes"] as? Int, 45)
        XCTAssertEqual(sessionJSON["note"] as? String, "第1章まで")
    }

    // MARK: - CSV

    func testCSVHeaderRow() {
        let csv = ExportService.makeCSV(sessions: [])
        let firstLine = csv.split(separator: "\n", maxSplits: 1).first.map(String.init)
        XCTAssertEqual(firstLine, "date,category,duration_minutes,title,detail,note")
    }

    func testCSVRowCountMatchesSessionCountPlusHeader() {
        let sessions = [
            Session(category: .study, startedAt: Date(), durationMinutes: 30),
            Session(category: .reading, startedAt: Date(), durationMinutes: 20),
            Session(category: .training, startedAt: Date(), durationMinutes: 60),
        ]
        let csv = ExportService.makeCSV(sessions: sessions)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(lines.count, sessions.count + 1)
    }

    func testCSVEscapesCommaAndQuoteInNote() {
        let session = Session(
            category: .study, startedAt: Date(), durationMinutes: 30,
            note: "感想: \"良い\", 面白かった"
        )
        let csv = ExportService.makeCSV(sessions: [session])
        // RFC4180: フィールド全体を "" で囲み、内部の " は "" にエスケープする
        XCTAssertTrue(csv.contains("\"感想: \"\"良い\"\", 面白かった\""))
    }

    func testCSVEscapesNewlineInNote() {
        let session = Session(
            category: .study, startedAt: Date(), durationMinutes: 30,
            note: "1行目\n2行目"
        )
        let csv = ExportService.makeCSV(sessions: [session])
        XCTAssertTrue(csv.contains("\"1行目\n2行目\""))
    }

    // MARK: - Markdown

    func testMarkdownCreatesOneFilePerDayWithRecords() {
        let day1 = jstCalendar.date(from: DateComponents(year: 2026, month: 8, day: 1, hour: 9))!
        let day2 = jstCalendar.date(from: DateComponents(year: 2026, month: 8, day: 2, hour: 9))!

        let readingDay1 = Session(category: .reading, startedAt: day1, durationMinutes: 30)
        let trainingDay1 = Session(category: .training, startedAt: day1.addingTimeInterval(3600), durationMinutes: 30)
        let studyDay2 = Session(category: .study, startedAt: day2, durationMinutes: 45)

        let files = ExportService.makeMarkdownFiles(
            sessions: [readingDay1, trainingDay1, studyDay2],
            calendar: jstCalendar
        )

        XCTAssertEqual(files.count, 2)
        XCTAssertEqual(files.map(\.filename).sorted(), ["2026-08-01.md", "2026-08-02.md"])
    }

    func testMarkdownFrontmatterTotalMinutesIsCorrect() throws {
        let day1 = jstCalendar.date(from: DateComponents(year: 2026, month: 8, day: 1, hour: 9))!
        let readingDay1 = Session(category: .reading, startedAt: day1, durationMinutes: 30)
        let trainingDay1 = Session(category: .training, startedAt: day1.addingTimeInterval(3600), durationMinutes: 30)

        let files = ExportService.makeMarkdownFiles(sessions: [readingDay1, trainingDay1], calendar: jstCalendar)
        let file = try XCTUnwrap(files.first { $0.filename == "2026-08-01.md" })

        XCTAssertTrue(file.content.contains("total_minutes: 60"))
        XCTAssertTrue(file.content.contains("reading_minutes: 30"))
        XCTAssertTrue(file.content.contains("training_minutes: 30"))
        XCTAssertTrue(file.content.contains("study_minutes: 0"))
    }

    func testMarkdownHeadingsOnlyForCategoriesPresentThatDay() throws {
        let day1 = jstCalendar.date(from: DateComponents(year: 2026, month: 8, day: 1, hour: 9))!
        let day2 = jstCalendar.date(from: DateComponents(year: 2026, month: 8, day: 2, hour: 9))!

        let readingDay1 = Session(category: .reading, startedAt: day1, durationMinutes: 30)
        let trainingDay1 = Session(category: .training, startedAt: day1.addingTimeInterval(3600), durationMinutes: 30)
        let studyDay2 = Session(category: .study, startedAt: day2, durationMinutes: 45)

        let files = ExportService.makeMarkdownFiles(
            sessions: [readingDay1, trainingDay1, studyDay2],
            calendar: jstCalendar
        )

        let day1File = try XCTUnwrap(files.first { $0.filename == "2026-08-01.md" })
        XCTAssertTrue(day1File.content.contains("## 📚 読書"))
        XCTAssertTrue(day1File.content.contains("## 💪 トレーニング"))
        XCTAssertFalse(day1File.content.contains("## ✏️ 勉強"))

        let day2File = try XCTUnwrap(files.first { $0.filename == "2026-08-02.md" })
        XCTAssertTrue(day2File.content.contains("## ✏️ 勉強"))
        XCTAssertFalse(day2File.content.contains("## 📚 読書"))
        XCTAssertFalse(day2File.content.contains("## 💪 トレーニング"))
    }

    func testMarkdownOmitsNoteSuffixWhenNoteIsNil() throws {
        let day1 = jstCalendar.date(from: DateComponents(year: 2026, month: 8, day: 1, hour: 9))!
        let subject = Subject(name: "簿記2級")
        let study = Session(category: .study, startedAt: day1, durationMinutes: 45)
        study.subject = subject

        let files = ExportService.makeMarkdownFiles(sessions: [study], calendar: jstCalendar)
        let file = try XCTUnwrap(files.first)

        XCTAssertTrue(file.content.contains("- 簿記2級\n") || file.content.hasSuffix("- 簿記2級\n"))
        XCTAssertFalse(file.content.contains("簿記2級 — "))
    }

    func testMarkdownStrengthAndCardioLineFormats() throws {
        let day1 = jstCalendar.date(from: DateComponents(year: 2026, month: 8, day: 1, hour: 9))!
        let training = Session(category: .training, startedAt: day1, durationMinutes: 60)
        training.menuName = "胸の日"

        let strengthLog = ExerciseLog(exerciseName: "ベンチプレス", bodyPart: .chest, order: 0)
        strengthLog.sets = [
            SetRecord(weightKg: 60, reps: 10),
            SetRecord(weightKg: 60, reps: 8),
        ]
        let cardioLog = ExerciseLog(exerciseName: "ランニング", bodyPart: .cardio, order: 1)
        cardioLog.distanceKm = 3.0
        cardioLog.durationMinutes = 20
        training.exerciseLogs = [strengthLog, cardioLog]

        let files = ExportService.makeMarkdownFiles(sessions: [training], calendar: jstCalendar)
        let file = try XCTUnwrap(files.first)

        XCTAssertTrue(file.content.contains("- ベンチプレス 60kg×10, 60kg×8"))
        XCTAssertTrue(file.content.contains("- ランニング 3.0km 20分"))
    }
}
