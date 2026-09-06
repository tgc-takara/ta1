import SwiftUI
import SwiftData
import UIKit

@main
struct TrackStackApp: App {
    let container: ModelContainer

    /// ウィジェットのディープリンクを画面へ受け渡す入れ物
    @State private var deepLinkRouter = DeepLinkRouter()
    @Environment(\.scenePhase) private var scenePhase

    /// 起動時のデータ準備(旧データ移行・プリセット投入)を何回目まで済ませたか。
    /// この値を上げたときだけ再実行し、通常の起動では SwiftData に一切触らない。
    /// 2: 新聞→記事 / ポッドキャスト→動画・音声 のカテゴリ統合
    /// 3: 読書/勉強/動画音声のスナップショット埋め戻し
    /// 4: 記事/動画音声カテゴリの廃止に伴う記録の削除
    /// 5: 有酸素プリセット「階段」の追加
    private static let setupVersion = 5
    private static let setupVersionKey = "startupSetupVersion"

    init() {
        do {
            container = try ModelContainer(
                for: Session.self, Book.self, BookGenre.self, Subject.self,
                Exercise.self, ExerciseLog.self, WorkoutMenu.self
            )
        } catch {
            fatalError("ModelContainer の初期化に失敗: \(error)")
        }
        // BGTaskScheduler への登録は起動完了前(init)で行う必要がある
        AutoBackupTrigger.registerBackgroundTask(container: container)
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
        deleteRemovedCategorySessions(in: context)
        seedPresets(in: context)
        seedSubjectPresets(in: context)
        backfillSessionSnapshots(in: context)
        guard context.hasChanges else {
            defaults.set(setupVersion, forKey: setupVersionKey)
            return
        }
        do {
            try context.save()
            defaults.set(setupVersion, forKey: setupVersionKey)
        } catch {
            // 保存できなかったときは次回起動でやり直せるよう、版数は上げない
        }
    }

    /// 本・科目の名前を Session 側のスナップショットへ埋め戻す。
    /// マスタを削除しても、その記録が「どれだったか」を残すため。
    private static func backfillSessionSnapshots(in context: ModelContext) {
        guard let sessions = try? context.fetch(FetchDescriptor<Session>()) else { return }
        for session in sessions {
            if session.bookTitle == nil, let title = session.book?.title {
                session.bookTitle = title
            }
            if session.subjectName == nil, let name = session.subject?.name {
                session.subjectName = name
            }
        }
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
                .environment(deepLinkRouter)
                .onOpenURL { url in
                    // 解釈できない URL は無視する(pending は上書きしない)
                    if let link = DeepLink.parse(url) {
                        deepLinkRouter.pending = link
                    }
                }
        }
        .modelContainer(container)
        // ウィジェット用スナップショットの更新。起動・復帰時と、バックグラウンドへ退くときに書き出す
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active || newPhase == .background {
                WidgetSnapshotWriter.update(container: container)
            }
        }
        // 自動バックアップ(有効なら .active で当日未実行なら実行、.background で次回をスケジュール)
        .onChange(of: scenePhase) { _, newPhase in
            AutoBackupTrigger.handle(phase: newPhase, container: container)
        }
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
            let exercise = Exercise(name: name, bodyPart: bodyPart)
            if Exercise.floorsPresetNames.contains(name) {
                exercise.cardioMetric = .floors
            }
            context.insert(exercise)
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

    /// 記事・動画音声のカテゴリ廃止。統合前の名前("newspaper" / "podcast")で
    /// 保存された記録も拾って削除する。
    /// クリップ等の子は旧スキーマごと消えるので Session だけ消せばよい。
    private static func deleteRemovedCategorySessions(in context: ModelContext) {
        let removedRawValues: Set<String> = ["article", "media", "newspaper", "podcast"]
        guard let sessions = try? context.fetch(FetchDescriptor<Session>()) else { return }
        for session in sessions where removedRawValues.contains(session.categoryRaw) {
            context.delete(session)
        }
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
