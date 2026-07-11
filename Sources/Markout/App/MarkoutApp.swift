import AppKit
import SwiftUI

/// Routes a Find action to whichever `NSTextView` is first responder, driving its built-in
/// `NSTextFinder` (the editor enables `usesFindBar`). The action is carried as the sender's `tag`,
/// which is how `performTextFinderAction(_:)` reads which operation to perform.
private func performTextFinderAction(_ action: NSTextFinder.Action) {
    let sender = NSMenuItem()
    sender.tag = action.rawValue
    NSApp.sendAction(#selector(NSTextView.performTextFinderAction(_:)), to: nil, from: sender)
}

@main
struct MarkoutApp: App {
    @FocusedValue(\.documentActions) private var documentActions

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document, documentURL: file.fileURL)
        }
        .commands {
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Find…") { performTextFinderAction(.showFindInterface) }
                    .keyboardShortcut("f", modifiers: .command)
                Button("Find Next") { performTextFinderAction(.nextMatch) }
                    .keyboardShortcut("g", modifiers: .command)
                Button("Find Previous") { performTextFinderAction(.previousMatch) }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                Button("Use Selection for Find") { performTextFinderAction(.setSearchString) }
                    .keyboardShortcut("e", modifiers: .command)
            }
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
