import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("ホーム", systemImage: "house.fill") }
            HistoryView()
                .tabItem { Label("記録", systemImage: "list.bullet.rectangle") }
            LibraryView()
                .tabItem { Label("ライブラリ", systemImage: "books.vertical.fill") }
            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape.fill") }
        }
        .tint(Theme.ink)
    }
}

#Preview {
    RootTabView()
        .modelContainer(
            for: [Session.self, Book.self, Subject.self,
                  Exercise.self, ExerciseLog.self, WorkoutMenu.self],
            inMemory: true
        )
}
