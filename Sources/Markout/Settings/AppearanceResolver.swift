import Foundation

/// A pane's appearance choice. Persisted as its raw string via `@AppStorage`.
enum AppearanceMode: String, CaseIterable {
    case system, light, dark
}

/// Pure mapping from an `AppearanceMode` (+ the OS appearance) to concrete appearance.
enum AppearanceResolver {
    /// `.system` follows the OS; `.light`/`.dark` override it.
    static func isDark(mode: AppearanceMode, systemIsDark: Bool) -> Bool {
        switch mode {
        case .system: return systemIsDark
        case .light:  return false
        case .dark:   return true
        }
    }

    /// The editor theme id for a given darkness (fixed Markout light/dark pair).
    static func editorThemeID(isDark: Bool) -> String {
        isDark ? "markout-dark" : "markout-light"
    }
}
