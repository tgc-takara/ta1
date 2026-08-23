import XCTest
import SwiftData
@testable import TrackStack

final class RecentBooksTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

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

    @discardableResult
    private func makeReadingSession(on date: Date, book: Book) -> Session {
        let session = Session(category: .reading, startedAt: date, durationMinutes: 30)
        session.book = book
        session.bookTitle = book.title
        context.insert(session)
        return session
    }

    func testLatestReturnsMostRecentBooksWithoutDuplicates() {
        let bookA = Book(title: "本A", status: .reading)
        let bookB = Book(title: "本B", status: .reading)
        let bookC = Book(title: "本C", status: .wantToRead)
        context.insert(bookA)
        context.insert(bookB)
        context.insert(bookC)

        let older = Date(timeIntervalSince1970: 1_000_000)
        let newer = Date(timeIntervalSince1970: 2_000_000)
        makeReadingSession(on: older, book: bookA)
        makeReadingSession(on: newer, book: bookB)
        // 本Aにもう一件記録(重複を避けるため、latest には1回しか出ないはず)
        makeReadingSession(on: Date(timeIntervalSince1970: 500_000), book: bookA)

        let result = RecentBooks.latest(limit: 5, in: context)

        XCTAssertEqual(result.map(\.title), ["本B", "本A"])
    }

    func testMostRecentUnfinishedSkipsFinishedBook() {
        let finishedBook = Book(title: "読了本", status: .finished)
        let unfinishedBook = Book(title: "読書中本", status: .reading)
        context.insert(finishedBook)
        context.insert(unfinishedBook)

        let older = Date(timeIntervalSince1970: 1_000_000)
        let newer = Date(timeIntervalSince1970: 2_000_000)
        makeReadingSession(on: older, book: unfinishedBook)
        makeReadingSession(on: newer, book: finishedBook)

        let result = RecentBooks.mostRecentUnfinished(in: context)

        XCTAssertEqual(result?.title, "読書中本")
    }

    func testMostRecentUnfinishedReturnsNilWhenAllFinished() {
        let bookA = Book(title: "本A", status: .finished)
        let bookB = Book(title: "本B", status: .finished)
        context.insert(bookA)
        context.insert(bookB)

        makeReadingSession(on: Date(timeIntervalSince1970: 1_000_000), book: bookA)
        makeReadingSession(on: Date(timeIntervalSince1970: 2_000_000), book: bookB)

        let result = RecentBooks.mostRecentUnfinished(in: context)

        XCTAssertNil(result)
    }
}
