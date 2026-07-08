import Foundation

/// `@AppStorage`/`UserDefaults` keys for persisted settings, kept in one place so the editor,
/// preview, and Settings window all agree on names.
enum SettingsKey {
    static let editorFontSize = "editorFontSize"
    static let editorThemeID = "editorThemeID"
    static let previewThemeID = "previewThemeID"
    static let showWordCount = "showWordCount"
    static let softWrap = "softWrap"
    static let showLineNumbers = "showLineNumbers"
    static let customPreviewCSSPath = "customPreviewCSSPath"
}

/// Default values for each setting; used as the `@AppStorage` fallbacks.
enum SettingsDefault {
    static let editorFontSize = 13.0
    static let editorThemeID = "markout-light"
    static let previewThemeID = "github"
    static let showWordCount = true
    static let softWrap = true
    static let showLineNumbers = false
    static let customPreviewCSSPath = ""
}

/// Sentinel `previewThemeID` selecting the user's custom CSS file (see `customPreviewCSSPath`).
let customPreviewThemeID = "custom"
