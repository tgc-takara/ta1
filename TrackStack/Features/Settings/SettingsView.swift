import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("データ") {
                    LabeledContent("エクスポート") {
                        Text("M5 で実装予定")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("このアプリ") {
                    LabeledContent("バージョン") {
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                    }
                }
            }
            .navigationTitle("設定")
        }
    }
}
