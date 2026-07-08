import AppKit

struct EditorTheme: Identifiable, Hashable {
    let id: String
    let name: String
    let background: NSColor
    let foreground: NSColor
    let caret: NSColor
    let selection: NSColor
    let colors: [MarkdownToken: NSColor]
}

enum EditorThemeStore {
    static var all: [EditorTheme] {
        [markoutLight, markoutDark, solarizedLight, dracula]
    }

    static func theme(id: String) -> EditorTheme? {
        all.first { $0.id == id }
    }

    private static let markoutLight = EditorTheme(
        id: "markout-light",
        name: "Markout Light",
        background: NSColor(srgbRed: 1.00, green: 1.00, blue: 1.00, alpha: 1.0),
        foreground: NSColor(srgbRed: 0.13, green: 0.13, blue: 0.13, alpha: 1.0),
        caret: NSColor(srgbRed: 0.10, green: 0.10, blue: 0.10, alpha: 1.0),
        selection: NSColor(srgbRed: 0.78, green: 0.88, blue: 1.00, alpha: 1.0),
        colors: [
            .heading: NSColor(srgbRed: 0.10, green: 0.30, blue: 0.60, alpha: 1.0),
            .emphasis: NSColor(srgbRed: 0.30, green: 0.30, blue: 0.30, alpha: 1.0),
            .strong: NSColor(srgbRed: 0.05, green: 0.05, blue: 0.05, alpha: 1.0),
            .inlineCode: NSColor(srgbRed: 0.65, green: 0.10, blue: 0.10, alpha: 1.0),
            .codeBlock: NSColor(srgbRed: 0.55, green: 0.10, blue: 0.10, alpha: 1.0),
            .link: NSColor(srgbRed: 0.05, green: 0.45, blue: 0.75, alpha: 1.0),
            .blockquote: NSColor(srgbRed: 0.40, green: 0.40, blue: 0.40, alpha: 1.0),
            .listMarker: NSColor(srgbRed: 0.45, green: 0.25, blue: 0.65, alpha: 1.0),
        ]
    )

    private static let markoutDark = EditorTheme(
        id: "markout-dark",
        name: "Markout Dark",
        background: NSColor(srgbRed: 0.11, green: 0.11, blue: 0.13, alpha: 1.0),
        foreground: NSColor(srgbRed: 0.88, green: 0.88, blue: 0.88, alpha: 1.0),
        caret: NSColor(srgbRed: 0.95, green: 0.95, blue: 0.95, alpha: 1.0),
        selection: NSColor(srgbRed: 0.25, green: 0.35, blue: 0.50, alpha: 1.0),
        colors: [
            .heading: NSColor(srgbRed: 0.45, green: 0.65, blue: 0.95, alpha: 1.0),
            .emphasis: NSColor(srgbRed: 0.75, green: 0.75, blue: 0.75, alpha: 1.0),
            .strong: NSColor(srgbRed: 1.00, green: 1.00, blue: 1.00, alpha: 1.0),
            .inlineCode: NSColor(srgbRed: 0.95, green: 0.55, blue: 0.45, alpha: 1.0),
            .codeBlock: NSColor(srgbRed: 0.85, green: 0.50, blue: 0.40, alpha: 1.0),
            .link: NSColor(srgbRed: 0.40, green: 0.75, blue: 0.95, alpha: 1.0),
            .blockquote: NSColor(srgbRed: 0.60, green: 0.60, blue: 0.60, alpha: 1.0),
            .listMarker: NSColor(srgbRed: 0.75, green: 0.60, blue: 0.95, alpha: 1.0),
        ]
    )

    private static let solarizedLight = EditorTheme(
        id: "solarized-light",
        name: "Solarized Light",
        background: NSColor(srgbRed: 0.99, green: 0.96, blue: 0.89, alpha: 1.0),
        foreground: NSColor(srgbRed: 0.40, green: 0.48, blue: 0.51, alpha: 1.0),
        caret: NSColor(srgbRed: 0.28, green: 0.36, blue: 0.38, alpha: 1.0),
        selection: NSColor(srgbRed: 0.93, green: 0.91, blue: 0.84, alpha: 1.0),
        colors: [
            .heading: NSColor(srgbRed: 0.15, green: 0.35, blue: 0.60, alpha: 1.0),
            .emphasis: NSColor(srgbRed: 0.52, green: 0.60, blue: 0.00, alpha: 1.0),
            .strong: NSColor(srgbRed: 0.80, green: 0.29, blue: 0.09, alpha: 1.0),
            .inlineCode: NSColor(srgbRed: 0.86, green: 0.20, blue: 0.18, alpha: 1.0),
            .codeBlock: NSColor(srgbRed: 0.71, green: 0.54, blue: 0.00, alpha: 1.0),
            .link: NSColor(srgbRed: 0.15, green: 0.55, blue: 0.82, alpha: 1.0),
            .blockquote: NSColor(srgbRed: 0.58, green: 0.63, blue: 0.63, alpha: 1.0),
            .listMarker: NSColor(srgbRed: 0.42, green: 0.44, blue: 0.77, alpha: 1.0),
        ]
    )

    private static let dracula = EditorTheme(
        id: "dracula",
        name: "Dracula",
        background: NSColor(srgbRed: 0.16, green: 0.16, blue: 0.21, alpha: 1.0),
        foreground: NSColor(srgbRed: 0.97, green: 0.97, blue: 0.95, alpha: 1.0),
        caret: NSColor(srgbRed: 0.97, green: 0.97, blue: 0.95, alpha: 1.0),
        selection: NSColor(srgbRed: 0.27, green: 0.28, blue: 0.35, alpha: 1.0),
        colors: [
            .heading: NSColor(srgbRed: 0.74, green: 0.58, blue: 0.98, alpha: 1.0),
            .emphasis: NSColor(srgbRed: 0.95, green: 0.98, blue: 0.55, alpha: 1.0),
            .strong: NSColor(srgbRed: 1.00, green: 0.47, blue: 0.78, alpha: 1.0),
            .inlineCode: NSColor(srgbRed: 0.31, green: 0.98, blue: 0.48, alpha: 1.0),
            .codeBlock: NSColor(srgbRed: 0.55, green: 0.91, blue: 0.99, alpha: 1.0),
            .link: NSColor(srgbRed: 0.55, green: 0.91, blue: 0.99, alpha: 1.0),
            .blockquote: NSColor(srgbRed: 0.63, green: 0.63, blue: 0.70, alpha: 1.0),
            .listMarker: NSColor(srgbRed: 1.00, green: 0.72, blue: 0.42, alpha: 1.0),
        ]
    )
}
