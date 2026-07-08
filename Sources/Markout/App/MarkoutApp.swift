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
            CommandMenu("Format") {
                Button("Bold") { documentActions?.format(.bold) }
                    .keyboardShortcut("b", modifiers: .command)
                Button("Italic") { documentActions?.format(.italic) }
                    .keyboardShortcut("i", modifiers: .command)
                Button("Inline Code") { documentActions?.format(.inlineCode) }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                Divider()
                Button("Heading 1") { documentActions?.format(.heading(1)) }
                    .keyboardShortcut("1", modifiers: [.command, .control])
                Button("Heading 2") { documentActions?.format(.heading(2)) }
                    .keyboardShortcut("2", modifiers: [.command, .control])
                Button("Heading 3") { documentActions?.format(.heading(3)) }
                    .keyboardShortcut("3", modifiers: [.command, .control])
                Divider()
                Button("Blockquote") { documentActions?.format(.blockquote) }
                Button("List") { documentActions?.format(.list) }
                Button("Link") { documentActions?.format(.link) }
                    .keyboardShortcut("k", modifiers: .command)
            }
        }
        Settings {
            SettingsView()
        }
    }
}
