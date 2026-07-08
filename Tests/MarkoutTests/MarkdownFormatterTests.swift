import Testing
import Foundation
@testable import Markout

struct MarkdownFormatterTests {
    private func sel(_ s: String, _ loc: Int, _ len: Int) -> NSRange { NSRange(location: loc, length: len) }

    @Test func boldWrapsSelection() {
        let r = MarkdownFormatter.toggleBold(text: "hello", selection: sel("hello", 0, 5))
        #expect(r.text == "**hello**")
    }

    @Test func boldUnwrapsWhenAlreadyBold() {
        let r = MarkdownFormatter.toggleBold(text: "**hello**", selection: sel("**hello**", 0, 9))
        #expect(r.text == "hello")
    }

    @Test func italicWraps() {
        let r = MarkdownFormatter.toggleItalic(text: "x", selection: sel("x", 0, 1))
        #expect(r.text == "*x*")
    }

    @Test func inlineCodeWraps() {
        let r = MarkdownFormatter.toggleInlineCode(text: "x", selection: sel("x", 0, 1))
        #expect(r.text == "`x`")
    }

    @Test func setHeadingAddsPrefix() {
        let r = MarkdownFormatter.setHeading(text: "Title", level: 2, selection: sel("Title", 0, 0))
        #expect(r.text == "## Title")
    }

    @Test func setHeadingReplacesExistingPrefix() {
        let r = MarkdownFormatter.setHeading(text: "# Title", level: 3, selection: sel("# Title", 0, 0))
        #expect(r.text == "### Title")
    }

    @Test func toggleListPrefixesLine() {
        let r = MarkdownFormatter.toggleList(text: "item", selection: sel("item", 0, 0))
        #expect(r.text == "- item")
    }

    @Test func toggleBlockquotePrefixesLine() {
        let r = MarkdownFormatter.toggleBlockquote(text: "quote", selection: sel("quote", 0, 0))
        #expect(r.text == "> quote")
    }

    @Test func makeLinkWrapsSelection() {
        let r = MarkdownFormatter.makeLink(text: "site", url: "https://x.com", selection: sel("site", 0, 4))
        #expect(r.text == "[site](https://x.com)")
    }

    @Test func makeLinkWithEmptySelectionInsertsTemplate() {
        let r = MarkdownFormatter.makeLink(text: "", url: "https://x.com", selection: sel("", 0, 0))
        #expect(r.text == "[](https://x.com)")
    }

    // MARK: - Review fixes

    @Test func italicOnBoldWrapsInsteadOfCorruptingBold() {
        // ⌘I over a bold selection must not strip a `*` off each side (which would break the bold).
        let r = MarkdownFormatter.toggleItalic(text: "**hello**", selection: sel("**hello**", 0, 9))
        #expect(r.text == "***hello***")
    }

    @Test func inlineCodeDoesNotUnwrapLongerBacktickRun() {
        let r = MarkdownFormatter.toggleInlineCode(text: "``x``", selection: sel("``x``", 0, 5))
        #expect(r.text == "```x```")
    }

    @Test func toggleListPrefixesEverySelectedLine() {
        let r = MarkdownFormatter.toggleList(text: "a\nb\nc", selection: NSRange(location: 0, length: 3))
        #expect(r.text == "- a\n- b\nc")
    }

    @Test func toggleBlockquotePrefixesEverySelectedLine() {
        let r = MarkdownFormatter.toggleBlockquote(text: "x\ny", selection: NSRange(location: 0, length: 3))
        #expect(r.text == "> x\n> y")
    }
}
