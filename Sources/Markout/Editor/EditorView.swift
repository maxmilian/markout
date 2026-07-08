import SwiftUI
import AppKit

struct EditorView: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let (scroll, textView) = MarkdownTextViewFactory.make()
        textView.delegate = context.coordinator
        textView.string = text
        context.coordinator.textView = textView
        context.coordinator.rehighlight()
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
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
        weak var textView: NSTextView?

        init(text: Binding<String>) { _text = text }

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
    }
}
