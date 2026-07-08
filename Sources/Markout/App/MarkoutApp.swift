import SwiftUI

@main
struct MarkoutApp: App {
    @FocusedValue(\.documentActions) private var documentActions

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document, documentURL: file.fileURL)
        }
        .commands {
            CommandGroup(after: .saveItem) {
                Divider()
                Button("Export as HTML…") { documentActions?.exportHTML() }
                    .disabled(documentActions == nil)
                Button("Export as PDF…") { documentActions?.exportPDF() }
                    .disabled(documentActions == nil)
            }
            CommandGroup(after: .textEditing) {
                Button("Insert Table of Contents") { documentActions?.insertTableOfContents() }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                    .disabled(documentActions == nil)
            }
        }
    }
}
