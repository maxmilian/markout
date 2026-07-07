import Testing
import Foundation
@testable import Markout

struct SyntaxHighlighterTests {
    private func tokens(_ s: String) -> [(range: NSRange, token: MarkdownToken)] {
        SyntaxHighlighter.tokens(in: s)
    }

    @Test func detectsATXHeading() {
        let result = tokens("# Title")
        #expect(result.contains { $0.token == .heading })
    }

    @Test func detectsInlineCode() {
        let result = tokens("use `code` here")
        #expect(result.contains { $0.token == .inlineCode })
    }

    @Test func detectsStrongAndEmphasis() {
        let strong = tokens("**bold**")
        #expect(strong.contains { $0.token == .strong })
        let emph = tokens("*italic*")
        #expect(emph.contains { $0.token == .emphasis })
    }

    @Test func detectsFencedCodeBlock() {
        let result = tokens("```\nx\n```")
        #expect(result.contains { $0.token == .codeBlock })
    }

    @Test func detectsLink() {
        let result = tokens("[text](https://example.com)")
        #expect(result.contains { $0.token == .link })
    }

    @Test func detectsBlockquoteAndListMarker() {
        #expect(tokens("> quote").contains { $0.token == .blockquote })
        #expect(tokens("- item").contains { $0.token == .listMarker })
    }

    @Test func plainTextHasNoTokens() {
        #expect(tokens("just words").isEmpty)
    }
}
