import Testing
@testable import Markout

struct FrontMatterTests {
    @Test func splitsValidBlock() {
        let doc = "---\ntitle: Hello\nauthor: Max\n---\n# Body"
        let (front, body) = FrontMatterParser.split(doc)
        #expect(front?.values["title"] == "Hello")
        #expect(front?.values["author"] == "Max")
        #expect(body == "# Body")
    }

    @Test func closingWithDotsAlsoWorks() {
        let (front, body) = FrontMatterParser.split("---\nk: v\n...\nbody")
        #expect(front?.values["k"] == "v")
        #expect(body == "body")
    }

    @Test func noBlockWhenNotAtTop() {
        let doc = "intro\n---\nk: v\n---\n"
        let (front, body) = FrontMatterParser.split(doc)
        #expect(front == nil)
        #expect(body == doc)
    }

    @Test func unterminatedIsTreatedAsBody() {
        let doc = "---\nk: v\nno close"
        let (front, body) = FrontMatterParser.split(doc)
        #expect(front == nil)
        #expect(body == doc)
    }

    @Test func absentFrontMatterReturnsWholeBody() {
        let (front, body) = FrontMatterParser.split("# Just markdown")
        #expect(front == nil)
        #expect(body == "# Just markdown")
    }

    @Test func preservesBodyNewlines() {
        let (_, body) = FrontMatterParser.split("---\nk: v\n---\nline1\nline2\n")
        #expect(body == "line1\nline2\n")
    }
}
