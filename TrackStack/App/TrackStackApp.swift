import SwiftUI
import SwiftData

@main
struct TrackStackApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Session.self, Book.self, BookGenre.self, Subject.self,
                Exercise.self, ExerciseLog.self, WorkoutMenu.self
            )
        } catch {
            fatalError("ModelContainer の初期化に失敗: \(error)")
        }
        migrateLegacyKindsIfNeeded()
        seedPresetsIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }

    /// 初回起動時にプリセット種目を投入する
    private func seedPresetsIfNeeded() {
        let context = ModelContext(container)
        let count = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        guard count == 0 else { return }
        for (name, bodyPart) in Exercise.presets {
            context.insert(Exercise(name: name, bodyPart: bodyPart))
        }
        try? context.save()
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
