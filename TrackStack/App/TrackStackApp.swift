import SwiftUI
import SwiftData
import UIKit

@main
struct TrackStackApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Session.self, Book.self, BookGenre.self, Subject.self,
                Exercise.self, ExerciseLog.self, WorkoutMenu.self, ReadingNote.self
            )
        } catch {
            fatalError("ModelContainer の初期化に失敗: \(error)")
        }
        migrateLegacyKindsIfNeeded()
        seedPresetsIfNeeded()
        seedSubjectPresetsIfNeeded()
        configureNavigationBarAppearance()
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
    private func seedPresetsIfNeeded() {
        let defaults = UserDefaults.standard
        let seededKey = "seededPresetNames"
        let seededNames = Set(defaults.stringArray(forKey: seededKey) ?? [])

        let context = ModelContext(container)
        let existing = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let existingNames = Set(existing.map(\.name))

        var inserted = false
        for (name, bodyPart) in Exercise.presets
        where !seededNames.contains(name) && !existingNames.contains(name) {
            context.insert(Exercise(name: name, bodyPart: bodyPart))
            inserted = true
        }
        if inserted {
            try? context.save()
        }
        defaults.set(Array(seededNames.union(Exercise.presets.map(\.0))), forKey: seededKey)
    }

    /// まだ投入したことのないプリセット科目(中小企業診断士7科目)だけを追加する。
    /// 投入済みの名前は UserDefaults に記録し、ユーザーが削除した科目を復活させない。
    private func seedSubjectPresetsIfNeeded() {
        let defaults = UserDefaults.standard
        let seededKey = "seededSubjectNames"
        let seededNames = Set(defaults.stringArray(forKey: seededKey) ?? [])

        let context = ModelContext(container)
        let existing = (try? context.fetch(FetchDescriptor<Subject>())) ?? []
        let existingNames = Set(existing.map(\.name))

        var inserted = false
        for name in Subject.presets
        where !seededNames.contains(name) && !existingNames.contains(name) {
            context.insert(Subject(name: name))
            inserted = true
        }
        if inserted {
            try? context.save()
        }
        defaults.set(Array(seededNames.union(Subject.presets)), forKey: seededKey)
    }

    /// 旧2分類(筋トレ/有酸素)時代の kindRaw("strength")を部位分類へ移行する。
    /// "cardio" は新分類でもそのまま有効なため対象外。
    private func migrateLegacyKindsIfNeeded() {
        let context = ModelContext(container)
        var changed = false

        if let exercises = try? context.fetch(FetchDescriptor<Exercise>()) {
            for exercise in exercises where BodyPart(rawValue: exercise.kindRaw) == nil {
                exercise.kindRaw = Exercise.migratedBodyPart(name: exercise.name).rawValue
                changed = true
            }
        }
        if let logs = try? context.fetch(FetchDescriptor<ExerciseLog>()) {
            for log in logs where BodyPart(rawValue: log.kindRaw) == nil {
                log.kindRaw = Exercise.migratedBodyPart(name: log.exerciseName).rawValue
                changed = true
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
                changed = true
            }
        }

        if changed {
            try? context.save()
        }
    }
}
