import Testing
@testable import Markout

struct RenderOptionsTests {
    @Test func defaultOmitsSourcePositions() {
        let html = MarkdownRenderer.renderHTMLBody("# Title")
        #expect(!html.contains("data-sourcepos"))
    }

    @Test func sourcePositionsAddDataAttribute() {
        let html = MarkdownRenderer.renderHTMLBody(
            "# Title\n\npara", options: .init(sourcePositions: true))
        #expect(html.contains("data-sourcepos"))
    }

    @Test func p1CallSiteStillCompilesAndRenders() {
        // The zero-argument P1 signature must keep working via the default argument.
        let html = MarkdownRenderer.renderHTMLBody("**bold**")
        #expect(html.contains("<strong>bold</strong>"))
    }
}
