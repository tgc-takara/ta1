import Foundation

/// 自動バックアップの設定(UserDefaults)の読み書き。値そのものの意味判断は AutoBackupPolicy / AutoBackupService に任せる。
enum AutoBackupSettings {
    private static let enabledKey = "autoBackupEnabled"
    private static let bookmarkKey = "autoBackupFolderBookmark"
    private static let folderNameKey = "autoBackupFolderName"
    private static let lastRunKey = "autoBackupLastRun"
    private static let lastErrorKey = "autoBackupLastError"

    static func loadEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static func saveEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
    }

    static func loadFolderBookmark() -> Data? {
        UserDefaults.standard.data(forKey: bookmarkKey)
    }

    static func saveFolderBookmark(_ bookmark: Data?) {
        UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
    }

    /// 表示用のフォルダ名(選んだフォルダの lastPathComponent)。
    static func loadFolderName() -> String? {
        UserDefaults.standard.string(forKey: folderNameKey)
    }

    static func saveFolderName(_ name: String?) {
        UserDefaults.standard.set(name, forKey: folderNameKey)
    }

    static func loadLastRun() -> Date? {
        UserDefaults.standard.object(forKey: lastRunKey) as? Date
    }

    static func saveLastRun(_ date: Date) {
        UserDefaults.standard.set(date, forKey: lastRunKey)
    }

    static func loadLastError() -> String? {
        UserDefaults.standard.string(forKey: lastErrorKey)
    }

    static func saveLastError(_ message: String?) {
        UserDefaults.standard.set(message, forKey: lastErrorKey)
    }
}

/// 「毎日1回」の判定と、バックアップファイル名の組み立て。副作用のない純粋関数だけを置く(ユニットテスト対象)。
enum AutoBackupPolicy {
    /// lastRun が nil、または now と lastRun が暦日で異なるとき true。
    /// lastRun が未来(不正な値)の場合は due としない。
    static func isDue(lastRun: Date?, now: Date, calendar: Calendar = .current) -> Bool {
        guard let lastRun else { return true }
        guard lastRun <= now else { return false }
        return !calendar.isDate(lastRun, inSameDayAs: now)
    }

    /// "hitotsumi-latest.json" と "hitotsumi-yyyy-MM-dd.json"。
    static func backupFileNames(now: Date) -> (latest: String, dated: String) {
        (latest: "hitotsumi-latest.json", dated: "hitotsumi-\(dateStamp(now)).json")
    }

    private static func dateStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
