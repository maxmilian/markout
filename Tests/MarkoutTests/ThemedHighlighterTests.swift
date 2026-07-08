import Testing
import AppKit
@testable import Markout

struct ThemedHighlighterTests {
    @Test func headingUsesThemeColor() {
        let theme = EditorThemeStore.theme(id: "markout-dark")!
        let storage = NSTextStorage(string: "# Title")
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        SyntaxHighlighter.apply(to: storage, baseFont: font, theme: theme)
        var found = false
        storage.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: storage.length)) { value, _, _ in
            if let c = value as? NSColor, c == theme.colors[.heading] { found = true }
        }
        #expect(found)
    }

    @Test func baseTextUsesThemeForeground() {
        let theme = EditorThemeStore.theme(id: "markout-light")!
        let storage = NSTextStorage(string: "plain")
        SyntaxHighlighter.apply(to: storage, baseFont: .monospacedSystemFont(ofSize: 13, weight: .regular), theme: theme)
        let c = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(c == theme.foreground)
    }
}
