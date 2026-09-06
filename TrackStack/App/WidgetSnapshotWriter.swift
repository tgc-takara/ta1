import Foundation
import SwiftData
import WidgetKit

/// 今日の積み上げを App Group に書き出し、ウィジェットの再描画を促す。
/// アプリがフォアグラウンドに来たとき / バックグラウンドへ退くときのほか、
/// 計測の開始・終了など「進行中」の状態が変わった直後にも呼ぶ。
enum WidgetSnapshotWriter {

    @MainActor
    static func update(container: ModelContainer, now: Date = Date(), calendar: Calendar = .current) {
        let context = ModelContext(container)
        // ストリークの計算に全期間の記録日が必要なため、Session は全件フェッチする
        guard let sessions = try? context.fetch(FetchDescriptor<Session>()) else { return }

        let todaySessions = StatsCalculator.sessions(sessions, on: now, calendar: calendar)
        let byCategory = StatsCalculator.minutesByCategory(todaySessions)
        let active = activeRecording()

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
            ),
            activeCategoryRaw: active?.categoryRaw,
            activeStartedAt: active?.startedAt
        )
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// いま計測中のもの。読書・勉強はタイマー(ActiveTimer)、トレーニングは
    /// ライブ記録フォームのフラグ(LiveTrainingState)から拾う。
    /// 両方立っていることは通常ないが、その場合はタイマーを優先する。
    private static func activeRecording() -> (categoryRaw: String, startedAt: Date)? {
        if let state = ActiveTimer.loadState() {
            return (state.categoryRaw, state.startedAt)
        }
        if let startedAt = LiveTrainingState.startedAt {
            return (ActivityCategory.training.rawValue, startedAt)
        }
        return nil
    }
}
