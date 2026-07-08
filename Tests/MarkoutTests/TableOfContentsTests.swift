import Testing
@testable import Markout

struct TableOfContentsTests {
    @Test func extractsHeadingsWithLevels() {
        let h = TableOfContents.headings(in: "# A\n## B\n### C")
        #expect(h.map(\.level) == [1, 2, 3])
        #expect(h.map(\.text) == ["A", "B", "C"])
    }

    @Test func skipsHeadingsInsideCodeFence() {
        let h = TableOfContents.headings(in: "# Real\n```\n# Fake\n```")
        #expect(h.map(\.text) == ["Real"])
    }

    @Test func slugsMatchGitHubRules() {
        let h = TableOfContents.headings(in: "# Hello, World!")
        #expect(h[0].slug == "hello-world")
    }

    @Test func deduplicatesSlugs() {
        let h = TableOfContents.headings(in: "# Dup\n# Dup")
        #expect(h[0].slug == "dup")
        #expect(h[1].slug == "dup-1")
    }

    @Test func stripsClosingHashes() {
        let h = TableOfContents.headings(in: "## Title ##")
        #expect(h[0].text == "Title")
    }

    @Test func ignoresNonHeadingHash() {
        // No space after the hashes -> not an ATX heading.
        let h = TableOfContents.headings(in: "#nothashtag")
        #expect(h.isEmpty)
    }

    @Test func buildsNestedMarkdownList() {
        let list = TableOfContents.markdownList([
            Heading(level: 1, text: "A", slug: "a"),
            Heading(level: 2, text: "B", slug: "b"),
        ])
        #expect(list.contains("- [A](#a)"))
        #expect(list.contains("  - [B](#b)"))
    }
}
