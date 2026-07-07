import Testing
@testable import Markout

struct HTMLTemplateTests {
    @Test func pageContainsContentContainerAndSetter() {
        let page = HTMLTemplate.page(theme: .light)
        #expect(page.contains("<div id=\"content\">"))
        #expect(page.contains("function setContent"))
        #expect(page.contains("<style>"))
    }

    @Test func lightThemeHtmlTagHasNoThemeAttribute() {
        let page = HTMLTemplate.page(theme: .light)
        let htmlLine = page.split(separator: "\n").first { $0.contains("<html") }
        #expect(htmlLine != nil)
        #expect(!htmlLine!.contains("data-theme"))
    }

    @Test func darkThemeSetsDataAttribute() {
        let page = HTMLTemplate.page(theme: .dark)
        #expect(page.contains("data-theme=\"dark\""))
    }
}
