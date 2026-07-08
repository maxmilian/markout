import Testing
@testable import Markout

struct HTMLTemplateP2Tests {
    @Test func linksBundledAssets() {
        let page = HTMLTemplate.page(theme: .light, previewCSS: "/*x*/")
        #expect(page.contains("highlight.min.js"))
        #expect(page.contains("katex.min.js"))
        #expect(page.contains("katex.min.css"))
        #expect(page.contains("mermaid.min.js"))
    }

    @Test func embedsPassedPreviewCSS() {
        let page = HTMLTemplate.page(theme: .light, previewCSS: "BODY{color:hotpink}")
        #expect(page.contains("BODY{color:hotpink}"))
    }

    @Test func definesAfterRenderPipeline() {
        let page = HTMLTemplate.page(theme: .dark, previewCSS: "")
        #expect(page.contains("function afterRender"))
        #expect(page.contains("katex.render"))
        #expect(page.contains("mermaid"))
        #expect(page.contains("hljs"))
    }

    @Test func setContentCallsAfterRender() {
        let page = HTMLTemplate.page(theme: .light, previewCSS: "")
        #expect(page.contains("afterRender()"))
    }

    @Test func definesScrollHooks() {
        let page = HTMLTemplate.page(theme: .light, previewCSS: "")
        #expect(page.contains("function scrollToSourceLine"))
        #expect(page.contains("function scrollToFraction"))
    }

    @Test func p1OverloadStillWorks() {
        let page = HTMLTemplate.page(theme: .light)
        #expect(page.contains("<div id=\"content\">"))
        #expect(page.contains("function setContent"))
    }
}
