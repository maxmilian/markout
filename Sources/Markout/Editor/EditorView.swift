import SwiftUI
import AppKit

struct EditorView: NSViewRepresentable {
    @Binding var text: String
    /// Called with the 1-based source line at the top of the visible area as the user scrolls/edits.
    var onVisibleLineChange: ((Int) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(text: $text, onVisibleLineChange: onVisibleLineChange) }

    func makeNSView(context: Context) -> NSScrollView {
        let (scroll, textView) = MarkdownTextViewFactory.make()
        textView.delegate = context.coordinator
        textView.string = text
        context.coordinator.textView = textView
        context.coordinator.rehighlight()
        context.coordinator.observeScrolling(of: scroll)
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.onVisibleLineChange = onVisibleLineChange
        guard let textView = context.coordinator.textView else { return }
        if textView.string != text {
            let selected = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selected
            context.coordinator.rehighlight()
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        var onVisibleLineChange: ((Int) -> Void)?
        weak var textView: NSTextView?
        private var lastReportedLine = -1

        init(text: Binding<String>, onVisibleLineChange: ((Int) -> Void)?) {
            _text = text
            self.onVisibleLineChange = onVisibleLineChange
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            text = textView.string
            rehighlight()
        }

        func rehighlight() {
            guard let textView, let storage = textView.textStorage else { return }
            let color = NSColor.textColor
            let font = textView.font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            storage.beginEditing()
            SyntaxHighlighter.apply(to: storage, baseFont: font, textColor: color)
            storage.endEditing()
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
