import Foundation
import UserNotifications

/// 局面の切り替わりをローカル通知で知らせる。
/// アプリがフォアグラウンドにあるときは TimerView が音と振動で知らせるので、
/// 通知はバックグラウンド・ロック中のための保険。
enum PomodoroNotifier {
    static let identifier = "pomodoro-phase-end"

    /// 初回に通知許可を求める。拒否されても音と振動は動くので結果は無視してよい。
    static func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    /// 現局面の終了時刻に 1 件だけ通知を予約する(既存の予約は先に消す)。
    static func schedule(for state: PomodoroState, now: Date = Date()) {
        cancel()
        let interval = Pomodoro.phaseEndDate(state: state).timeIntervalSince(now)
        guard interval >= 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = "ポモドーロ"
        content.body = state.phase == .work
            ? "作業おつかれさま。休憩しましょう"
            : "休憩おわり。作業に戻りましょう"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
