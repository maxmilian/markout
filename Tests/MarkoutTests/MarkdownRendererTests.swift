import Testing
@testable import Markout

struct MarkdownRendererTests {
    @Test func rendersHeading() {
        let html = MarkdownRenderer.renderHTMLBody("# Title")
        #expect(html.contains("<h1>Title</h1>"))
    }

    @Test func rendersBoldAndItalic() {
        let html = MarkdownRenderer.renderHTMLBody("**bold** and *italic*")
        #expect(html.contains("<strong>bold</strong>"))
        #expect(html.contains("<em>italic</em>"))
    }

    @Test func rendersGFMTable() {
        let md = """
        | A | B |
        |---|---|
        | 1 | 2 |
        """
        let html = MarkdownRenderer.renderHTMLBody(md)
        #expect(html.contains("<table>"))
        #expect(html.contains("<th>A</th>"))
        #expect(html.contains("<td>1</td>"))
    }

    @Test func rendersStrikethrough() {
        let html = MarkdownRenderer.renderHTMLBody("~~gone~~")
        #expect(html.contains("<del>gone</del>"))
    }

    @Test func rendersTaskList() {
        let html = MarkdownRenderer.renderHTMLBody("- [x] done\n- [ ] todo")
        #expect(html.contains("type=\"checkbox\""))
        #expect(html.contains("checked"))
    }

    @Test func rendersFencedCode() {
        let html = MarkdownRenderer.renderHTMLBody("```\ncode\n```")
        #expect(html.contains("<pre>"))
        #expect(html.contains("<code>"))
    }

    @Test func autolinksBareURL() {
        let html = MarkdownRenderer.renderHTMLBody("see https://example.com now")
        #expect(html.contains("<a href=\"https://example.com\">"))
    }

    @Test func escapesRawHTMLByDefault() {
        let html = MarkdownRenderer.renderHTMLBody("<script>alert(1)</script>")
        #expect(!html.contains("<script>alert(1)</script>"))
    }

    @Test func emptyInputReturnsEmptyish() {
        #expect(MarkdownRenderer.renderHTMLBody("").isEmpty)
    }
}
