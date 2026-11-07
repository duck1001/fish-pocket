import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// 文件选择器，`asCopy: true`：系统把选中的文件**复制**进 App 的临时目录再给 URL，
/// 不涉及 security-scoped 授权，iCloud 的占位也由系统负责下载。
/// `.fileImporter` 在 iOS 16 上给的还是外部容器 URL，读字节这一步经常失败。
struct DocumentPicker: UIViewControllerRepresentable {
    var types: [UTType] = [.item]
    var allowsMultiple = true
    let onPick: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = allowsMultiple
        picker.shouldShowFileExtensions = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void

        init(onPick: @escaping ([URL]) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}
