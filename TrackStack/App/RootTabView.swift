import SwiftUI

struct RootTabView: View {
    /// タブの識別子。ディープリンクで開いたときにホームへ戻すために selection を持つ。
    enum Tab: Hashable {
        case home, history, library, settings
    }

    @Environment(DeepLinkRouter.self) private var router
    @State private var selection: Tab = .home

    var body: some View {
        TabView(selection: $selection) {
            DashboardView()
                .tabItem { Label("ホーム", systemImage: "house.fill") }
                .tag(Tab.home)
            HistoryView()
                .tabItem { Label("記録", systemImage: "list.bullet.rectangle") }
                .tag(Tab.history)
            LibraryView()
                .tabItem { Label("ライブラリ", systemImage: "books.vertical.fill") }
                .tag(Tab.library)
            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .tint(Theme.ink)
        // ウィジェットから開いたときは、どのタブにいてもホームへ切り替える。
        // 実際の処理(タイマー開始・記録フォーム)は DashboardView が消費する。
        .onChange(of: router.pending) { _, newValue in
            if newValue != nil { selection = .home }
        }
        .onAppear {
            if router.pending != nil { selection = .home }
        }
    }
}

#Preview {
    RootTabView()
        .environment(DeepLinkRouter())
        .modelContainer(
            for: [Session.self, Book.self, Subject.self,
                  Exercise.self, ExerciseLog.self, WorkoutMenu.self],
            inMemory: true
        )
}
