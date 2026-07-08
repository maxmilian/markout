import SwiftUI
import AppKit

struct EditorView: NSViewRepresentable {
    @Binding var text: String
    /// Called with the 1-based source line at the top of the visible area as the user scrolls/edits.
    var onVisibleLineChange: ((Int) -> Void)? = nil
    /// The document's file URL, used to save pasted/dropped images beside it.
    var documentURL: URL? = nil
    /// Called once with the text view, so the owner can insert text at the caret (e.g. a TOC).
    var onEditorReady: ((MarkoutTextView) -> Void)? = nil
    /// Editor font size, editor color theme id, soft-wrap, and line numbers — driven by settings.
    var fontSize: Double = SettingsDefault.editorFontSize
    var editorThemeID: String = SettingsDefault.editorThemeID
    var softWrap: Bool = SettingsDefault.softWrap
    var showLineNumbers: Bool = SettingsDefault.showLineNumbers

    private var theme: EditorTheme {
        EditorThemeStore.theme(id: editorThemeID)
            ?? EditorThemeStore.theme(id: SettingsDefault.editorThemeID)!
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onVisibleLineChange: onVisibleLineChange, documentURL: documentURL)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let (scroll, textView) = MarkdownTextViewFactory.make()
        textView.delegate = context.coordinator
        textView.string = text
        context.coordinator.textView = textView
        context.coordinator.theme = theme
        context.coordinator.fontSize = fontSize
        context.coordinator.softWrap = softWrap
        context.coordinator.showLineNumbers = showLineNumbers
        MarkdownTextViewFactory.configure(
            textView, in: scroll, fontSize: fontSize, theme: theme, softWrap: softWrap,
            showLineNumbers: showLineNumbers)
        textView.onInsertImage = { [weak textView] image in
            guard let textView else { return }
            guard let markdown = try? ImagePasteHandler.markdownLink(
                for: image, documentURL: context.coordinator.documentURL), !markdown.isEmpty
            else { return }
            textView.insertText(markdown, replacementRange: textView.selectedRange())
        }
        context.coordinator.rehighlight()
        context.coordinator.observeScrolling(of: scroll)
        onEditorReady?(textView)
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.onVisibleLineChange = onVisibleLineChange
        context.coordinator.documentURL = documentURL
        guard let textView = context.coordinator.textView else { return }

        let appearanceChanged = context.coordinator.fontSize != fontSize
            || context.coordinator.theme.id != theme.id
            || context.coordinator.softWrap != softWrap
            || context.coordinator.showLineNumbers != showLineNumbers
        if appearanceChanged {
            context.coordinator.fontSize = fontSize
            context.coordinator.theme = theme
            context.coordinator.softWrap = softWrap
            context.coordinator.showLineNumbers = showLineNumbers
            MarkdownTextViewFactory.configure(
                textView, in: nsView, fontSize: fontSize, theme: theme, softWrap: softWrap,
                showLineNumbers: showLineNumbers)
        }

        if textView.string != text {
            let selected = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selected
            context.coordinator.rehighlight()
        } else if appearanceChanged {
            context.coordinator.rehighlight()
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        var onVisibleLineChange: ((Int) -> Void)?
        var documentURL: URL?
        weak var textView: MarkoutTextView?
        var theme: EditorTheme = EditorThemeStore.theme(id: SettingsDefault.editorThemeID)!
        var fontSize: Double = SettingsDefault.editorFontSize
        var softWrap: Bool = SettingsDefault.softWrap
        var showLineNumbers: Bool = SettingsDefault.showLineNumbers
        private var lastReportedLine = -1

        init(text: Binding<String>, onVisibleLineChange: ((Int) -> Void)?, documentURL: URL?) {
            _text = text
            self.onVisibleLineChange = onVisibleLineChange
            self.documentURL = documentURL
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            text = textView.string
            rehighlight()
        }

        func rehighlight() {
            guard let textView, let storage = textView.textStorage else { return }
            let font = textView.font ?? NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
            storage.beginEditing()
            SyntaxHighlighter.apply(to: storage, baseFont: font, theme: theme)
            storage.endEditing()
            (textView.enclosingScrollView?.verticalRulerView as? LineNumberRulerView)?.refresh()
        }

        func observeScrolling(of scroll: NSScrollView) {
            let clip = scroll.contentView
            clip.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self, selector: #selector(boundsDidChange(_:)),
                name: NSView.boundsDidChangeNotification, object: clip)
        }

        @objc private func boundsDidChange(_ note: Notification) {
            guard let onVisibleLineChange, let line = topVisibleLine() else { return }
            if line != lastReportedLine {
                lastReportedLine = line
                onVisibleLineChange(line)
            }
        }

        /// The 1-based source line at the top of the visible rect, or nil if unavailable.
        private func topVisibleLine() -> Int? {
            guard let textView,
                  let layoutManager = textView.layoutManager,
                  let container = textView.textContainer else { return nil }
            let visible = textView.visibleRect
            let point = CGPoint(x: 0, y: max(0, visible.minY - textView.textContainerInset.height))
            let glyphIndex = layoutManager.glyphIndex(for: point, in: container)
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            let ns = textView.string as NSString
            guard charIndex <= ns.length else { return nil }
            var line = 1
            ns.enumerateSubstrings(in: NSRange(location: 0, length: charIndex),
                                   options: [.byLines, .substringNotRequired]) { _, _, _, _ in
                line += 1
            }
            return line
        }
    }
}
