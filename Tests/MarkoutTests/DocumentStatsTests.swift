import Testing
@testable import Markout

struct DocumentStatsTests {
    @Test func countsWordsAndChars() {
        let s = DocumentStats.compute("hello world")
        #expect(s.words == 2)
        #expect(s.characters == 11)
    }

    @Test func countsLines() {
        #expect(DocumentStats.compute("a\nb\nc").lines == 3)
    }

    @Test func emptyIsAllZero() {
        #expect(DocumentStats.compute("") == DocumentStats(words: 0, characters: 0, lines: 0, readingMinutes: 0))
    }

    @Test func whitespaceOnlyHasNoWords() {
        #expect(DocumentStats.compute("   \n  ").words == 0)
    }

    @Test func readingTimeRoundsUp() {
        let text = Array(repeating: "word", count: 250).joined(separator: " ")
        #expect(DocumentStats.compute(text).readingMinutes == 2)
    }

    @Test func unicodeWordsCounted() {
        #expect(DocumentStats.compute("héllo 世界 🌍").words == 3)
    }
}
