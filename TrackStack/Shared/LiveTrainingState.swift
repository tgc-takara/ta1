import Foundation

/// トレーニングの「ライブ記録フォーム」を開いている間だけ立てるフラグ。
///
/// 読書・勉強は ActiveTimer が状態を永続化するが、トレーニングは計測画面を持たず
/// 記録フォームを開くだけなので、ウィジェットへ「いま計測中」を伝える手段が無い。
/// そのため開始時刻だけを UserDefaults に置いて、フォームが閉じたら消す。
///
/// フォーム自体はアプリ再起動で復元できないため、起動時に残っていたら破棄する(`clearStale()`)。
enum LiveTrainingState {
    static let key = "liveTrainingStartedAt"

    private static var store: UserDefaults { .standard }

    /// 記録フォームを開いている場合の開始時刻。閉じていれば nil
    static var startedAt: Date? {
        store.object(forKey: key) as? Date
    }

    static func begin(at date: Date) {
        store.set(date, forKey: key)
    }

    static func clear() {
        store.removeObject(forKey: key)
    }

    /// 起動時に呼ぶ。前回の実行中に残ったフラグを掃除する。
    static func clearStale() {
        clear()
    }
}
