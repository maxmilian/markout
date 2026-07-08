import SwiftUI

/// A Markdown formatting command the toolbar and Format menu apply to the focused editor's selection.
enum FormatCommand: Equatable {
    case bold, italic, inlineCode, blockquote, list, link
    case heading(Int)
}

/// Actions the focused document window exposes to the app's menu commands. Each closure captures
/// the window's state (document text, rendered HTML, active theme, preview WebView) and presents its
/// own save/open panels, so the menu layer stays decoupled from any single window.
struct DocumentActions {
    var exportHTML: () -> Void
    var exportPDF: () -> Void
    var insertTableOfContents: () -> Void
    var format: (FormatCommand) -> Void
}

private struct DocumentActionsKey: FocusedValueKey {
    typealias Value = DocumentActions
}

extension FocusedValues {
    var documentActions: DocumentActions? {
        get { self[DocumentActionsKey.self] }
        set { self[DocumentActionsKey.self] = newValue }
    }
}
