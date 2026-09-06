import SwiftUI
import SwiftData
import BackgroundTasks

/// TrackStackApp からの呼び出し窓口。scenePhase の変化や BGAppRefreshTask をここに集約し、
/// App 本体(TrackStackApp.swift)への追記を1行呼び出しに留める。
enum AutoBackupTrigger {
    static let backgroundTaskIdentifier = "com.taguchi.TrackStack.autobackup"

    /// BGTaskScheduler への登録。App の init から、起動処理が完了する前に呼ぶこと。
    static func registerBackgroundTask(container: ModelContainer) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handleBackgroundTask(refreshTask, container: container)
        }
    }

    /// scenePhase の変化を受けての処理。.active でその日分がまだなら自動バックアップ、
    /// .background で次回のバックグラウンド実行をスケジュールし直す。
    static func handle(phase: ScenePhase, container: ModelContainer) {
        switch phase {
        case .active:
            Task { await AutoBackupService.runIfDue(container: container) }
        case .background:
            scheduleNextBackgroundTask()
        default:
            break
        }
    }

    private static func handleBackgroundTask(_ task: BGAppRefreshTask, container: ModelContainer) {
        // 次回分は先に積んでおく(この実行が失敗・タイムアウトしても以降の機会が失われないように)
        scheduleNextBackgroundTask()

        let work = Task {
            await AutoBackupService.runIfDue(container: container)
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            work.cancel()
        }
    }

    private static func scheduleNextBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = nextRunDate()
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // シミュレータや権限未許可時は失敗しうるが、次回アプリを開いたときの .active チェックで補われる
        }
    }

    /// 翌日午前3時
    private static func nextRunDate(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return calendar.date(bySettingHour: 3, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }
}
