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

    static func apply(to textStorage: NSTextStorage, baseFont: NSFont, textColor: NSColor) {
        let full = NSRange(location: 0, length: textStorage.length)
        textStorage.setAttributes([.font: baseFont, .foregroundColor: textColor], range: full)
        let text = textStorage.string
        for (range, token) in tokens(in: text) {
            var attrs: [NSAttributedString.Key: Any] = [:]
            switch token {
            case .heading:
                attrs[.font] = NSFont.monospacedSystemFont(ofSize: baseFont.pointSize + 3, weight: .bold)
                attrs[.foregroundColor] = NSColor.systemBlue
            case .strong:
                attrs[.font] = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
            case .emphasis:
                attrs[.font] = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
            case .inlineCode, .codeBlock:
                attrs[.foregroundColor] = NSColor.systemPurple
            case .link:
                attrs[.foregroundColor] = NSColor.linkColor
            case .blockquote:
                attrs[.foregroundColor] = NSColor.secondaryLabelColor
            case .listMarker:
                attrs[.foregroundColor] = NSColor.systemOrange
            }
            textStorage.addAttributes(attrs, range: range)
        }
    }
}
