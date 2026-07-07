import Testing
import Foundation
@testable import Markout

struct MarkdownDocumentTests {
    @Test func roundTripsUTF8Text() throws {
        let original = "# Hello\n\nWorld 世界 🌍"
        let doc = MarkdownDocument(text: original)
        let data = Data(doc.text.utf8)
        let decoded = String(decoding: data, as: UTF8.self)
        #expect(decoded == original)
    }

    @Test func defaultTextIsEmpty() {
        #expect(MarkdownDocument().text == "")
    }
}
