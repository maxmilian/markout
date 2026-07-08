import Testing
import AppKit
@testable import Markout

struct LineNumberRulerTests {
    @Test func firstLineIsOne() {
        #expect(LineNumberRulerView.lineNumber(atCharacterIndex: 0, in: "a\nb\nc" as NSString) == 1)
    }

    @Test func countsNewlinesBeforeLineStart() {
        let s = "a\nb\nc" as NSString  // logical line starts at 0, 2, 4
        #expect(LineNumberRulerView.lineNumber(atCharacterIndex: 2, in: s) == 2)
        #expect(LineNumberRulerView.lineNumber(atCharacterIndex: 4, in: s) == 3)
    }

    @Test func midLineIndexResolvesToContainingLine() {
        // Guards the soft-wrap fix: an index inside a wrapped line still maps to that logical line.
        let s = "a\nbb\nc" as NSString  // line 2 spans indices 2...3
        #expect(LineNumberRulerView.lineNumber(atCharacterIndex: 3, in: s) == 2)
    }

    @Test func clampsOutOfRangeIndices() {
        let s = "a\nb" as NSString
        #expect(LineNumberRulerView.lineNumber(atCharacterIndex: 999, in: s) == 2)
        #expect(LineNumberRulerView.lineNumber(atCharacterIndex: -5, in: s) == 1)
    }
}
