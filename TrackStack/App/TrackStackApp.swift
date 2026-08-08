import SwiftUI
import SwiftData

@main
struct TrackStackApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Session.self, Book.self, Subject.self,
                Exercise.self, ExerciseLog.self, WorkoutMenu.self
            )
        } catch {
            fatalError("ModelContainer の初期化に失敗: \(error)")
        }
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
        for (name, kind) in Exercise.presets {
            context.insert(Exercise(name: name, kind: kind))
        }
        try? context.save()
    }
}
