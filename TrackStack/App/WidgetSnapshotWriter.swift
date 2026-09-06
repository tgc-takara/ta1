import Foundation
import SwiftData
import WidgetKit

/// 今日の積み上げを App Group に書き出し、ウィジェットの再描画を促す。
/// アプリがフォアグラウンドに来たとき / バックグラウンドへ退くときに呼ぶ。
enum WidgetSnapshotWriter {

    @MainActor
    static func update(container: ModelContainer, now: Date = Date(), calendar: Calendar = .current) {
        let context = ModelContext(container)
        // ストリークの計算に全期間の記録日が必要なため、Session は全件フェッチする
        guard let sessions = try? context.fetch(FetchDescriptor<Session>()) else { return }

        let todaySessions = StatsCalculator.sessions(sessions, on: now, calendar: calendar)
        let byCategory = StatsCalculator.minutesByCategory(todaySessions)

        let snapshot = WidgetSnapshot(
            date: calendar.startOfDay(for: now),
            totalMinutes: StatsCalculator.totalMinutes(todaySessions),
            minutesByCategory: byCategory.reduce(into: [:]) { result, pair in
                result[pair.key.rawValue] = pair.value
            },
            streak: StatsCalculator.streak(
                recordedDays: Set(sessions.map(\.startedAt)),
                today: now,
                calendar: calendar
            )
        )
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
