import Testing
import SwiftUI
import AppKit
@testable import Markout

/// Regression: rehighlighting must not compound the editor font size.
///
/// The bug read `textView.font` back as the base font in `Coordinator.rehighlight()`.
/// When the first line is a heading, that getter returns the enlarged heading font, so every
/// keystroke re-based the whole document larger — the left pane grew without bound.
@MainActor
struct EditorFontStabilityTests {
    @Test func repeatedRehighlightKeepsFontSizeStable() {
        var text = "# Heading\nplain body"
        let binding = Binding(get: { text }, set: { text = $0 })
        let coordinator = EditorView.Coordinator(text: binding, onVisibleLineChange: nil, documentURL: nil)

        let (scroll, textView) = MarkdownTextViewFactory.make()
        textView.string = text
        coordinator.textView = textView
        coordinator.theme = EditorThemeStore.theme(id: "markout-light")!
        coordinator.fontSize = 13
        MarkdownTextViewFactory.configure(
            textView, in: scroll, fontSize: 13, theme: coordinator.theme,
            softWrap: false, showLineNumbers: false)

        // Simulate ten keystrokes' worth of rehighlight passes.
        for _ in 0..<10 { coordinator.rehighlight() }

        // The plain body must stay at the base size, not grow.
        let plainIndex = ("# Heading\n" as NSString).length + 1
        let bodyFont = textView.textStorage?.attribute(.font, at: plainIndex, effectiveRange: nil) as? NSFont
        #expect(bodyFont?.pointSize == 13)
    }
}
