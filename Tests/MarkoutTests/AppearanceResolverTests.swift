import Testing
@testable import Markout

struct AppearanceResolverTests {
    @Test func systemFollowsOS() {
        #expect(AppearanceResolver.isDark(mode: .system, systemIsDark: true) == true)
        #expect(AppearanceResolver.isDark(mode: .system, systemIsDark: false) == false)
    }

    @Test func lightAndDarkOverrideOS() {
        #expect(AppearanceResolver.isDark(mode: .light, systemIsDark: true) == false)
        #expect(AppearanceResolver.isDark(mode: .light, systemIsDark: false) == false)
        #expect(AppearanceResolver.isDark(mode: .dark, systemIsDark: true) == true)
        #expect(AppearanceResolver.isDark(mode: .dark, systemIsDark: false) == true)
    }

    @Test func editorThemeMapping() {
        #expect(AppearanceResolver.editorThemeID(isDark: true) == "markout-dark")
        #expect(AppearanceResolver.editorThemeID(isDark: false) == "markout-light")
    }

    @Test func rawValuesAreStable() {
        #expect(AppearanceMode(rawValue: "system") == .system)
        #expect(AppearanceMode(rawValue: "light") == .light)
        #expect(AppearanceMode(rawValue: "dark") == .dark)
        #expect(AppearanceMode(rawValue: "garbage") == nil)
    }
}
