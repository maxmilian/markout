import AppKit
import UniformTypeIdentifiers

/// NSTextView subclass adding Markdown editing behaviors: automatic list continuation on Return
/// and image paste/drag-drop. Built on TextKit 1 (explicit layout manager) so the syntax
/// highlighter and top-visible-line calculation have a populated `layoutManager`/`textStorage`.
final class MarkoutTextView: NSTextView {
    /// Called with a pasted or dropped image; the coordinator saves it and inserts a Markdown link.
    var onInsertImage: ((NSImage) -> Void)?

    // MARK: List continuation

    override func insertNewline(_ sender: Any?) {
        if let edit = currentLineListEdit() {
            apply(edit)
            return
        }
        super.insertNewline(sender)
    }

    private func currentLineListEdit() -> ListEdit? {
        guard let storage = textStorage else { return nil }
        let caret = selectedRange().location
        let ns = storage.string as NSString
        guard caret <= ns.length else { return nil }
        let lineRange = ns.lineRange(for: NSRange(location: caret, length: 0))
        let prefixLength = caret - lineRange.location
        guard prefixLength >= 0 else { return nil }
        let lineText = ns.substring(with: NSRange(location: lineRange.location, length: prefixLength))
        return ListContinuation.onReturn(line: lineText)
    }

    private func apply(_ edit: ListEdit) {
        let caret = selectedRange().location
        if edit.removeCurrentMarker {
            guard let storage = textStorage else { super.insertNewline(nil); return }
            let ns = storage.string as NSString
            let lineRange = ns.lineRange(for: NSRange(location: caret, length: 0))
            let markerRange = NSRange(location: lineRange.location, length: caret - lineRange.location)
            insertText("", replacementRange: markerRange)
        } else {
            insertText(edit.insert, replacementRange: selectedRange())
        }
    }

    // MARK: Image paste / drop

    override func paste(_ sender: Any?) {
        // Prefer image insertion only when the clipboard has no text (avoids hijacking normal paste).
        let hasText = NSPasteboard.general.canReadObject(forClasses: [NSString.self], options: nil)
        if let handler = onInsertImage, !hasText, let image = NSImage(pasteboard: .general) {
            handler(image)
            return
        }
        super.paste(sender)
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        if onInsertImage != nil, pasteboardHasImage(sender.draggingPasteboard) {
            return .copy
        }
        return super.draggingEntered(sender)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        if let handler = onInsertImage, let image = image(from: sender.draggingPasteboard) {
            handler(image)
            return true
        }
        return super.performDragOperation(sender)
    }

    private func pasteboardHasImage(_ pasteboard: NSPasteboard) -> Bool {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingContentsConformToTypes: [UTType.image.identifier]
        ]
        if pasteboard.canReadObject(forClasses: [NSURL.self], options: options) { return true }
        return pasteboard.canReadItem(
            withDataConformingToTypes: [UTType.png.identifier, UTType.tiff.identifier])
    }

    private func image(from pasteboard: NSPasteboard) -> NSImage? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingContentsConformToTypes: [UTType.image.identifier]
        ]
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
           let url = urls.first, let image = NSImage(contentsOf: url) {
            return image
        }
        return NSImage(pasteboard: pasteboard)
    }
}

/// Builds a configured `MarkoutTextView` inside a scroll view.
enum MarkdownTextViewFactory {
    static func make() -> (scroll: NSScrollView, textView: MarkoutTextView) {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.autohidesScrollers = true

        let contentSize = scroll.contentSize
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(
            containerSize: NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        let textView = MarkoutTextView(
            frame: NSRect(origin: .zero, size: contentSize), textContainer: container)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 12)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.registerForDraggedTypes([.fileURL, .png, .tiff])

        scroll.documentView = textView
        return (scroll, textView)
    }
}
