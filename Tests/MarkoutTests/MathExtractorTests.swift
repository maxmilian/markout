import Testing
@testable import Markout

struct MathExtractorTests {
    @Test func extractsInlineMath() {
        let (protected, spans) = MathExtractor.extract("energy is $E=mc^2$ ok")
        #expect(spans.count == 1)
        #expect(spans[0].display == false)
        #expect(spans[0].tex == "E=mc^2")
        #expect(!protected.contains("$"))
    }

    @Test func extractsDisplayMath() {
        let (_, spans) = MathExtractor.extract("$$\n\\frac{a}{b}\n$$")
        #expect(spans.count == 1)
        #expect(spans[0].display == true)
        #expect(spans[0].tex.contains("\\frac{a}{b}"))
    }

    @Test func ignoresMathInsideInlineCode() {
        let (_, spans) = MathExtractor.extract("use `$x$` literally")
        #expect(spans.isEmpty)
    }

    @Test func ignoresMathInsideFencedCode() {
        let md = "```\n$not math$\n```"
        let (_, spans) = MathExtractor.extract(md)
        #expect(spans.isEmpty)
    }

    @Test func unbalancedDollarIsLeftLiteral() {
        let (protected, spans) = MathExtractor.extract("price is $5 today")
        #expect(spans.isEmpty)
        #expect(protected.contains("$5"))
    }

    @Test func reinsertWrapsAndEscapes() {
        let (_, spans) = MathExtractor.extract("$a<b$")
        let html = MathExtractor.reinsert("<p>\u{FFFC}MATH0\u{FFFC}</p>", spans: spans)
        #expect(html.contains("math-inline"))
        #expect(html.contains("a&lt;b"))
        #expect(!html.contains("\u{FFFC}"))
    }

    @Test func displayReinsertUsesBlockWrapper() {
        let (_, spans) = MathExtractor.extract("$$x$$")
        let html = MathExtractor.reinsert("\u{FFFC}MATH0\u{FFFC}", spans: spans)
        #expect(html.contains("math-display"))
    }

    @Test func plainTextUnchanged() {
        let (protected, spans) = MathExtractor.extract("no math here")
        #expect(spans.isEmpty)
        #expect(protected == "no math here")
    }
}
