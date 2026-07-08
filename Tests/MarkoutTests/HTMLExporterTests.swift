import Testing
@testable import Markout

struct HTMLExporterTests {
    @Test func includesTitleCSSAndBody() {
        let out = HTMLExporter.standaloneHTML(
            body: "<h1>Hi</h1>", css: "body{color:red}", title: "My Doc")
        #expect(out.contains("<title>My Doc</title>"))
        #expect(out.contains("body{color:red}"))
        #expect(out.contains("<h1>Hi</h1>"))
        #expect(out.contains("id=\"content\""))
        #expect(out.hasPrefix("<!DOCTYPE html>"))
    }

    @Test func escapesTitle() {
        let out = HTMLExporter.standaloneHTML(body: "", css: "", title: "a<b>&c")
        #expect(!out.contains("<title>a<b>&c</title>"))
        #expect(out.contains("a&lt;b&gt;&amp;c"))
    }
}
