import Testing
import Foundation
@testable import Markout

struct MarkdownDocumentTests {
    @Test func roundTripsUTF8Text() throws {
        // Exercises the real serialization functions the app uses on save/open,
        // since the SDK offers no public way to build a Read/WriteConfiguration.
        let original = "# Hello\n\nWorld 世界 🌍"
        let data = MarkdownDocument.encode(original)
        let decoded = MarkdownDocument.decode(data)
        #expect(decoded == original)
    }

    @Test func encodeProducesUTF8Bytes() {
        #expect(MarkdownDocument.encode("世界") == Data("世界".utf8))
    }

    @Test func decodeRecoversFromInvalidUTF8() {
        // Lenient fallback must never crash and always return a String.
        let invalid = Data([0xFF, 0xFE, 0x41])
        #expect(!MarkdownDocument.decode(invalid).isEmpty)
    }

    @Test func defaultTextIsEmpty() {
        #expect(MarkdownDocument().text == "")
    }
}
