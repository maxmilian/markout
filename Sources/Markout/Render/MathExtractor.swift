import Foundation

/// One extracted TeX math span. `display` distinguishes `$$…$$` (block) from `$…$` (inline).
struct MathSpan: Equatable {
    let display: Bool
    let tex: String
}

/// Protects TeX math from Markdown parsing.
///
/// cmark would otherwise treat `_`, `*`, `\`, etc. inside math as Markdown syntax. `extract`
/// pulls each `$…$` / `$$…$$` span out into a placeholder (inert to Markdown and skipping any
/// fenced/inline code regions, where `$` is literal); `reinsert` swaps the placeholders back for
/// `<span class="math-inline">` / `<div class="math-display">` elements the preview renders with KaTeX.
///
/// Both functions are pure and never throw; on any ambiguity they prefer leaving text literal
/// over corrupting the output.
enum MathExtractor {
    /// Object Replacement Character — unlikely to appear in prose and inert to Markdown.
    private static let sentinel = "\u{FFFC}"

    private static func placeholder(_ index: Int) -> String {
        "\(sentinel)MATH\(index)\(sentinel)"
    }

    static func extract(_ text: String) -> (protected: String, spans: [MathSpan]) {
        let chars = Array(text)
        let n = chars.count
        var out = ""
        var spans: [MathSpan] = []
        var i = 0
        var atLineStart = true
        var inFence = false
        var fenceMarker: Character = "`"

        while i < n {
            let c = chars[i]

            // Fenced code block open/close (``` or ~~~, 3+), only at the start of a line.
            if atLineStart, c == "`" || c == "~" {
                var j = i
                while j < n, chars[j] == c { j += 1 }
                if j - i >= 3 {
                    if !inFence {
                        inFence = true
                        fenceMarker = c
                    } else if c == fenceMarker {
                        inFence = false
                    }
                    while i < n, chars[i] != "\n" {
                        out.append(chars[i]); i += 1
                    }
                    atLineStart = true
                    continue
                }
            }

            if inFence {
                out.append(c)
                atLineStart = (c == "\n")
                i += 1
                continue
            }

            // Inline code span: copy verbatim, math inside is literal.
            if c == "`" {
                var j = i
                while j < n, chars[j] == "`" { j += 1 }
                let runLen = j - i
                var k = j
                var close = -1
                while k < n {
                    if chars[k] == "`" {
                        var m = k
                        while m < n, chars[m] == "`" { m += 1 }
                        if m - k == runLen { close = k; break }
                        k = m
                    } else {
                        k += 1
                    }
                }
                if close >= 0 {
                    let end = close + runLen
                    for idx in i..<end { out.append(chars[idx]) }
                    i = end
                    atLineStart = false
                    continue
                }
                out.append(c); i += 1; atLineStart = false
                continue
            }

            // Math.
            if c == "$" {
                if i + 1 < n, chars[i + 1] == "$" {
                    // Display math $$…$$ (may span newlines).
                    var k = i + 2
                    var close = -1
                    while k + 1 < n {
                        if chars[k] == "$", chars[k + 1] == "$" { close = k; break }
                        k += 1
                    }
                    if close >= 0 {
                        spans.append(MathSpan(display: true, tex: String(chars[(i + 2)..<close])))
                        out.append(placeholder(spans.count - 1))
                        i = close + 2
                        atLineStart = false
                        continue
                    }
                    out.append(c); i += 1; atLineStart = false
                    continue
                } else {
                    // Inline math $…$ (single line, non-empty).
                    var k = i + 1
                    var close = -1
                    while k < n {
                        if chars[k] == "\n" { break }
                        if chars[k] == "$" { close = k; break }
                        k += 1
                    }
                    if close > i + 1 {
                        spans.append(MathSpan(display: false, tex: String(chars[(i + 1)..<close])))
                        out.append(placeholder(spans.count - 1))
                        i = close + 1
                        atLineStart = false
                        continue
                    }
                    out.append(c); i += 1; atLineStart = false
                    continue
                }
            }

            out.append(c)
            atLineStart = (c == "\n")
            i += 1
        }

        return (out, spans)
    }

    static func reinsert(_ html: String, spans: [MathSpan]) -> String {
        var result = html
        for (index, span) in spans.enumerated() {
            let escaped = escapeHTML(span.tex)
            let replacement = span.display
                ? "<div class=\"math-display\">\(escaped)</div>"
                : "<span class=\"math-inline\">\(escaped)</span>"
            result = result.replacingOccurrences(of: placeholder(index), with: replacement)
        }
        return result
    }

    private static func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
