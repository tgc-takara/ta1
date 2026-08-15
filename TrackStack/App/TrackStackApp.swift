import SwiftUI
import SwiftData
import UIKit

@main
struct TrackStackApp: App {
    let container: ModelContainer

    /// 起動時のデータ準備(旧データ移行・プリセット投入)を何回目まで済ませたか。
    /// この値を上げたときだけ再実行し、通常の起動では SwiftData に一切触らない。
    private static let setupVersion = 1
    private static let setupVersionKey = "startupSetupVersion"

    init() {
        do {
            container = try ModelContainer(
                for: Session.self, Book.self, BookGenre.self, Subject.self,
                Exercise.self, ExerciseLog.self, WorkoutMenu.self,
                ArticleClip.self, PodcastShow.self
            )
        } catch {
            fatalError("ModelContainer の初期化に失敗: \(error)")
        }
        Self.runSetupIfNeeded(container: container)
        configureNavigationBarAppearance()
    }

    /// 移行・シードは初回(と setupVersion を上げたとき)だけ実行する。
    /// 毎回走らせると起動のたびに全種目・全記録をフェッチすることになり、
    /// 記録が増えるほど起動が遅くなるため。
    private static func runSetupIfNeeded(container: ModelContainer) {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: setupVersionKey) < setupVersion else { return }

        let context = ModelContext(container)
        migrateLegacyKinds(in: context)
        seedPresets(in: context)
        seedSubjectPresets(in: context)
        if context.hasChanges {
            try? context.save()
        }
        defaults.set(setupVersion, forKey: setupVersionKey)
    }

    /// 画面タイトル(ナビゲーションバーの大見出し)を明朝体にする。
    /// フォント未対応環境では自動的にシステムフォントへフォールバックする。
    private func configureNavigationBarAppearance() {
        let largeTitleFont = UIFont(name: "HiraMinProN-W6", size: 34)
            ?? UIFont.systemFont(ofSize: 34, weight: .bold)
        let titleFont = UIFont(name: "HiraMinProN-W6", size: 17)
            ?? UIFont.systemFont(ofSize: 17, weight: .semibold)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.largeTitleTextAttributes = [.font: largeTitleFont]
        appearance.titleTextAttributes = [.font: titleFont]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }

    /// まだ投入したことのないプリセット種目だけを追加する。
    /// 投入済みの名前は UserDefaults に記録し、ユーザーが削除した種目を復活させない。
    /// (プリセット追加後のアップデートでは新種目だけが既存データに反映される)
    private static func seedPresets(in context: ModelContext) {
        let defaults = UserDefaults.standard
        let seededKey = "seededPresetNames"
        let seededNames = Set(defaults.stringArray(forKey: seededKey) ?? [])

        let existing = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let existingNames = Set(existing.map(\.name))

        for (name, bodyPart) in Exercise.presets
        where !seededNames.contains(name) && !existingNames.contains(name) {
            context.insert(Exercise(name: name, bodyPart: bodyPart))
        }
        defaults.set(Array(seededNames.union(Exercise.presets.map(\.0))), forKey: seededKey)
    }

    /// まだ投入したことのないプリセット科目(中小企業診断士7科目)だけを追加する。
    /// 投入済みの名前は UserDefaults に記録し、ユーザーが削除した科目を復活させない。
    private static func seedSubjectPresets(in context: ModelContext) {
        let defaults = UserDefaults.standard
        let seededKey = "seededSubjectNames"
        let seededNames = Set(defaults.stringArray(forKey: seededKey) ?? [])

        let existing = (try? context.fetch(FetchDescriptor<Subject>())) ?? []
        let existingNames = Set(existing.map(\.name))

        for name in Subject.presets
        where !seededNames.contains(name) && !existingNames.contains(name) {
            context.insert(Subject(name: name))
        }
        defaults.set(Array(seededNames.union(Subject.presets)), forKey: seededKey)
    }

    /// 旧2分類(筋トレ/有酸素)時代の kindRaw("strength")を部位分類へ移行する。
    /// "cardio" は新分類でもそのまま有効なため対象外。
    private static func migrateLegacyKinds(in context: ModelContext) {
        if let exercises = try? context.fetch(FetchDescriptor<Exercise>()) {
            for exercise in exercises where BodyPart(rawValue: exercise.kindRaw) == nil {
                exercise.kindRaw = Exercise.migratedBodyPart(name: exercise.name).rawValue
            }
        }
        if let logs = try? context.fetch(FetchDescriptor<ExerciseLog>()) {
            for log in logs where BodyPart(rawValue: log.kindRaw) == nil {
                log.kindRaw = Exercise.migratedBodyPart(name: log.exerciseName).rawValue
            }
        }
        if let menus = try? context.fetch(FetchDescriptor<WorkoutMenu>()) {
            for menu in menus where menu.items.contains(where: { BodyPart(rawValue: $0.kindRaw) == nil }) {
                menu.items = menu.items.map { item in
                    var item = item
                    if BodyPart(rawValue: item.kindRaw) == nil {
                        item.kindRaw = Exercise.migratedBodyPart(name: item.exerciseName).rawValue
                    }
                    return item
                }
            }
        }
    }
}
