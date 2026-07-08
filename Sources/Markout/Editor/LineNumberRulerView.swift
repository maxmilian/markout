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

        // Restrict work to the glyphs currently visible.
        let visibleGlyphs = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: container)
        let visibleChars = layoutManager.characterRange(forGlyphRange: visibleGlyphs, actualGlyphRange: nil)

        // Line number of the first visible character.
        var lineNumber = 1
        content.enumerateSubstrings(
            in: NSRange(location: 0, length: visibleChars.location),
            options: [.byLines, .substringNotRequired]) { _, _, _, _ in lineNumber += 1 }

        // Draw one number per logical line, at its first fragment's top.
        content.enumerateSubstrings(in: visibleChars, options: [.byLines, .substringNotRequired]) {
            _, lineRange, _, _ in
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: lineRange.location)
            let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let label = "\(lineNumber)" as NSString
            let size = label.size(withAttributes: attrs)
            let y = fragment.minY + inset + yOffset + (fragment.height - size.height) / 2
            label.draw(at: NSPoint(x: thickness - size.width - 5, y: y), withAttributes: attrs)
            lineNumber += 1
        }

        // A trailing empty line (text ending in "\n") gets its own number.
        if visibleChars.location + visibleChars.length >= content.length,
           content.length == 0 || content.hasSuffix("\n") {
            let glyphIndex = max(0, layoutManager.numberOfGlyphs - 1)
            let fragment = layoutManager.numberOfGlyphs == 0
                ? NSRect(x: 0, y: 0, width: 0, height: textView.font?.pointSize ?? 13)
                : layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let extraY = (content.length == 0 ? 0 : fragment.maxY)
            let label = "\(lineNumber)" as NSString
            let size = label.size(withAttributes: attrs)
            label.draw(at: NSPoint(x: thickness - size.width - 5,
                                   y: extraY + inset + yOffset), withAttributes: attrs)
        }
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
