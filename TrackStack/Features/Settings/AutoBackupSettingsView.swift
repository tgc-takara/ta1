import SwiftUI
import SwiftData

/// 設定 > データ > 自動バックアップ。保存先フォルダの選択、有効/無効の切り替え、
/// 最終実行状況の確認、手動での即時バックアップができる。
struct AutoBackupSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var enabled = false
    @State private var folderName: String?
    @State private var hasFolder = false
    @State private var lastRun: Date?
    @State private var lastError: String?
    @State private var isShowingFolderPicker = false
    @State private var isRunning = false
    @State private var showingSavedMessage = false
    @State private var folderPickerErrorMessage: String?
    @State private var showingFolderPickerError = false

    var body: some View {
        List {
            Section("自動バックアップ") {
                Toggle("自動バックアップ", isOn: $enabled)
                    .onChange(of: enabled) { _, newValue in
                        AutoBackupSettings.saveEnabled(newValue)
                    }
            }
            .listRowBackground(Theme.surface)

            Section("保存先") {
                LabeledContent("フォルダ") {
                    Text(folderName ?? "未設定")
                        .foregroundStyle(folderName == nil ? Theme.inkSecondary : Theme.ink)
                }
                Button("フォルダを選ぶ") {
                    isShowingFolderPicker = true
                }
            }
            .listRowBackground(Theme.surface)

            Section {
                LabeledContent("最終バックアップ") {
                    Text(lastRun.map(formattedDateTime) ?? "まだありません")
                        .foregroundStyle(Theme.inkSecondary)
                }
                if let lastError {
                    Text(lastError)
                        .foregroundStyle(.red)
                }
                Button(action: runNow) {
                    if isRunning {
                        HStack(spacing: 6) {
                            ProgressView()
                            Text("バックアップ中…")
                        }
                    } else if showingSavedMessage {
                        Text("保存しました")
                    } else {
                        Text("今すぐバックアップ")
                    }
                }
                .disabled(isRunning || !hasFolder)
            } header: {
                Text("状況")
            } footer: {
                Text("iCloud Drive・Google Drive・Obsidian のフォルダなどを選べます。アプリを開いたとき、前回から日付が変わっていれば自動で保存します。選んだフォルダの中に「ひとつみ」フォルダを作り、JSON(完全なデータ)と日別の Markdown を保存します。")
            }
            .listRowBackground(Theme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .navigationTitle("自動バックアップ")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .sheet(isPresented: $isShowingFolderPicker) {
            FolderPicker { result in
                switch result {
                case .success:
                    reload()
                case .failure(let error):
                    folderPickerErrorMessage = error.localizedDescription
                    showingFolderPickerError = true
                }
            }
        }
        .alert("フォルダを選べませんでした", isPresented: $showingFolderPickerError, presenting: folderPickerErrorMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private func reload() {
        enabled = AutoBackupSettings.loadEnabled()
        folderName = AutoBackupSettings.loadFolderName()
        hasFolder = AutoBackupSettings.loadFolderBookmark() != nil
        lastRun = AutoBackupSettings.loadLastRun()
        lastError = AutoBackupSettings.loadLastError()
    }

    private func runNow() {
        isRunning = true
        showingSavedMessage = false
        let container = modelContext.container
        Task {
            do {
                try await AutoBackupService.run(container: container, now: Date())
                await MainActor.run {
                    reload()
                    isRunning = false
                    showingSavedMessage = true
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    showingSavedMessage = false
                }
            } catch {
                await MainActor.run {
                    reload()
                    isRunning = false
                }
            }
        }
    }

    private func formattedDateTime(_ date: Date) -> String {
        "\(Formatters.dayHeader(date)) \(Formatters.time(date))"
    }
}
