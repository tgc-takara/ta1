import SwiftUI
import UniformTypeIdentifiers

/// フォルダ選択(iOSの「ファイル」アプリ)。選んだフォルダのブックマークを AutoBackupSettings に保存する。
/// iCloud Drive・Google Drive・Obsidian の vault フォルダなど、ファイルアプリから見えるフォルダなら選べる。
struct FolderPicker: UIViewControllerRepresentable {
    var onPicked: (Result<Void, Error>) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPicked: (Result<Void, Error>) -> Void

        init(onPicked: @escaping (Result<Void, Error>) -> Void) {
            self.onPicked = onPicked
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            do {
                guard url.startAccessingSecurityScopedResource() else {
                    throw FolderPickerError.accessDenied
                }
                defer { url.stopAccessingSecurityScopedResource() }
                let bookmark = try url.bookmarkData()
                AutoBackupSettings.saveFolderBookmark(bookmark)
                AutoBackupSettings.saveFolderName(url.lastPathComponent)
                onPicked(.success(()))
            } catch {
                onPicked(.failure(error))
            }
        }
    }
}

private enum FolderPickerError: LocalizedError {
    case accessDenied

    var errorDescription: String? {
        "フォルダへのアクセスが許可されませんでした"
    }
}
