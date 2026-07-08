import AppKit

/// A gutter that draws 1-based line numbers next to a `NSTextView`, aligned to each logical line's
/// first line fragment (so soft-wrapped lines get a single number). Redrawn as the text scrolls or
/// changes; `refresh()` recomputes the gutter width for the current line count.
final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 40
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Widen the gutter to fit the highest line number, and repaint.
    func refresh() {
        guard let textView else { return }
        let lines = max(1, (textView.string as NSString).numberOfLines())
        let digits = max(2, String(lines).count)
        let sample = String(repeating: "8", count: digits) as NSString
        let width = sample.size(withAttributes: [.font: labelFont(for: textView)]).width
        ruleThickness = ceil(width) + 10
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return }

        let content = textView.string as NSString
        let inset = textView.textContainerInset.height
        let yOffset = convert(NSPoint.zero, from: textView).y
        let thickness = ruleThickness
        let attrs: [NSAttributedString.Key: Any] = [
            .font: labelFont(for: textView),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]

        func drawNumber(_ number: Int, atY y: CGFloat, height: CGFloat) {
            let label = "\(number)" as NSString
            let size = label.size(withAttributes: attrs)
            let drawY = y + inset + yOffset + (height - size.height) / 2
            label.draw(at: NSPoint(x: thickness - size.width - 5, y: drawY), withAttributes: attrs)
        }

        // Restrict work to the glyphs currently visible.
        let visibleGlyphs = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: container)
        let visibleChars = layoutManager.characterRange(forGlyphRange: visibleGlyphs, actualGlyphRange: nil)
        let visibleEnd = NSMaxRange(visibleChars)

        // Normalize to the start of the logical line containing the first visible character —
        // otherwise a soft-wrapped continuation at the top would offset every number by one.
        let firstLineStart = content.lineRange(
            for: NSRange(location: min(visibleChars.location, content.length), length: 0)).location
        var lineNumber = Self.lineNumber(atCharacterIndex: firstLineStart, in: content)

        // Draw one number per logical line, at its first fragment's top, over the visible range only.
        var lineStart = firstLineStart
        while lineStart < content.length && lineStart <= visibleEnd {
            let lineRange = content.lineRange(for: NSRange(location: lineStart, length: 0))
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: lineRange.location)
            let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            drawNumber(lineNumber, atY: fragment.minY, height: fragment.height)
            lineNumber += 1
            let next = NSMaxRange(lineRange)
            if next == lineStart { break }  // no progress guard
            lineStart = next
        }

        // A trailing empty line (empty doc, or text ending in "\n") gets its own number.
        if visibleEnd >= content.length, content.length == 0 || content.hasSuffix("\n") {
            if content.length == 0 {
                drawNumber(lineNumber, atY: 0, height: textView.font?.pointSize ?? 13)
            } else {
                let lastGlyph = max(0, layoutManager.numberOfGlyphs - 1)
                let fragment = layoutManager.lineFragmentRect(forGlyphAt: lastGlyph, effectiveRange: nil)
                drawNumber(lineNumber, atY: fragment.maxY, height: fragment.height)
            }
        }
    }

    /// 1-based line number of the logical line containing `index` = (line terminators before it) + 1.
    /// Counts `\n`, `\r`, and `\r\n` so it is correct for any index, not just line starts.
    static func lineNumber(atCharacterIndex index: Int, in content: NSString) -> Int {
        let bound = min(max(index, 0), content.length)
        var number = 1
        var i = 0
        while i < bound {
            let c = content.character(at: i)
            if c == 0x0A {  // \n
                number += 1
            } else if c == 0x0D {  // \r not immediately followed by \n
                if i + 1 >= content.length || content.character(at: i + 1) != 0x0A { number += 1 }
            }
            i += 1
        }
        return number
    }

    private func labelFont(for textView: NSTextView) -> NSFont {
        let size = (textView.font?.pointSize ?? 13) - 2
        return NSFont.monospacedDigitSystemFont(ofSize: size, weight: .regular)
    }
}

private extension NSString {
    /// Number of logical lines (a trailing newline adds a final empty line).
    func numberOfLines() -> Int {
        if length == 0 { return 1 }
        var count = 0
        enumerateSubstrings(in: NSRange(location: 0, length: length),
                            options: [.byLines, .substringNotRequired]) { _, _, _, _ in count += 1 }
        if hasSuffix("\n") { count += 1 }
        return count
    }
}
