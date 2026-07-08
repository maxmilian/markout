import AppKit

enum MarkdownToken: Hashable {
    case heading, emphasis, strong, inlineCode, codeBlock, link, blockquote, listMarker
}

struct SyntaxHighlighter {
    private struct Rule {
        let token: MarkdownToken
        let regex: NSRegularExpression
    }

    private static let rules: [Rule] = {
        func re(_ pattern: String, _ opts: NSRegularExpression.Options = []) -> NSRegularExpression {
            try! NSRegularExpression(pattern: pattern, options: opts)
        }
        return [
            Rule(token: .codeBlock, regex: re("(?ms)^```.*?^```", [])),
            Rule(token: .heading, regex: re("(?m)^#{1,6}\\s.*$")),
            Rule(token: .blockquote, regex: re("(?m)^>\\s.*$")),
            Rule(token: .listMarker, regex: re("(?m)^\\s*([-*+]|\\d+\\.)\\s")),
            Rule(token: .strong, regex: re("\\*\\*[^*\\n]+\\*\\*")),
            Rule(token: .emphasis, regex: re("(?<!\\*)\\*[^*\\n]+\\*(?!\\*)")),
            Rule(token: .inlineCode, regex: re("`[^`\\n]+`")),
            Rule(token: .link, regex: re("\\[[^\\]\\n]+\\]\\([^)\\n]+\\)")),
        ]
    }()

    static func tokens(in text: String) -> [(range: NSRange, token: MarkdownToken)] {
        let full = NSRange(text.startIndex..., in: text)
        var out: [(range: NSRange, token: MarkdownToken)] = []
        for rule in rules {
            rule.regex.enumerateMatches(in: text, range: full) { match, _, _ in
                if let m = match {
                    out.append((m.range, rule.token))
                }
            }
        }
        return out
    }

    /// Themed highlighting: base text uses `theme.foreground`, each token its `theme.colors[token]`,
    /// with bold/italic traits for strong/emphasis and a larger bold font for headings.
    static func apply(to textStorage: NSTextStorage, baseFont: NSFont, theme: EditorTheme) {
        let full = NSRange(location: 0, length: textStorage.length)
        textStorage.setAttributes([.font: baseFont, .foregroundColor: theme.foreground], range: full)
        let text = textStorage.string
        for (range, token) in tokens(in: text) {
            var attrs: [NSAttributedString.Key: Any] = [:]
            if let color = theme.colors[token] {
                attrs[.foregroundColor] = color
            }
            switch token {
            case .heading:
                attrs[.font] = NSFont.monospacedSystemFont(ofSize: baseFont.pointSize + 3, weight: .bold)
            case .strong:
                attrs[.font] = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
            case .emphasis:
                attrs[.font] = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
            default:
                break
            }
            textStorage.addAttributes(attrs, range: range)
        }
    }

    /// P1 shim: keep the original `textColor`-based signature working by delegating to the themed
    /// path with a theme whose foreground is `textColor` and token colors come from `markout-light`.
    static func apply(to textStorage: NSTextStorage, baseFont: NSFont, textColor: NSColor) {
        let tokenColors = EditorThemeStore.theme(id: "markout-light")?.colors ?? [:]
        let theme = EditorTheme(
            id: "p1-shim", name: "P1",
            background: .textBackgroundColor, foreground: textColor,
            caret: textColor, selection: .selectedTextBackgroundColor,
            colors: tokenColors)
        apply(to: textStorage, baseFont: baseFont, theme: theme)
    }
}
