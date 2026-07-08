import Testing
import AppKit
@testable import Markout

struct EditorThemeStoreTests {
    @Test func hasDefaultTheme() {
        #expect(EditorThemeStore.theme(id: "markout-light") != nil)
    }

    @Test func unknownIdIsNil() {
        #expect(EditorThemeStore.theme(id: "nope") == nil)
    }

    @Test func everyThemeCoversAllTokens() {
        let allTokens: [MarkdownToken] = [.heading, .emphasis, .strong, .inlineCode, .codeBlock, .link, .blockquote, .listMarker]
        for theme in EditorThemeStore.all {
            for token in allTokens {
                #expect(theme.colors[token] != nil, "\(theme.id) missing \(token)")
            }
        }
    }

    @Test func providesAtLeastLightAndDark() {
        let ids = Set(EditorThemeStore.all.map(\.id))
        #expect(ids.contains("markout-light"))
        #expect(ids.contains("markout-dark"))
    }
}
