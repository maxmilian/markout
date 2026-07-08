import Testing
@testable import Markout

struct PreviewInjectionTests {
    @Test func scriptEscapesQuotesAndBackslashes() {
        let body = "<p>He said \"hi\" \\ done</p>"
        let js = PreviewInjection.script(forBody: body)
        #expect(js.hasPrefix("setContent("))
        #expect(js.contains("\\\""))
        #expect(js.contains("\\\\"))
        #expect(!js.contains("\"hi\""))
    }

    @Test func scriptHandlesNewlines() {
        let js = PreviewInjection.script(forBody: "a\nb")
        #expect(js.contains("\\n"))
    }

    @Test func themeScriptReflectsFlag() {
        #expect(PreviewInjection.themeScript(isDark: true).contains("true"))
        #expect(PreviewInjection.themeScript(isDark: false).contains("false"))
    }
}
