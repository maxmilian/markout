import Testing
@testable import Markout

struct ScrollSyncTests {
    let anchors = [
        ScrollAnchor(sourceLine: 1, fraction: 0.0),
        ScrollAnchor(sourceLine: 11, fraction: 0.5),
        ScrollAnchor(sourceLine: 21, fraction: 1.0),
    ]

    @Test func interpolatesBetweenAnchors() {
        let f = ScrollSync.previewFraction(forEditorLine: 6, totalLines: 21, anchors: anchors)
        #expect(abs(f - 0.25) < 0.01)
    }

    @Test func clampsBelowFirstAnchor() {
        #expect(ScrollSync.previewFraction(forEditorLine: 0, totalLines: 21, anchors: anchors) == 0.0)
    }

    @Test func clampsAboveLastAnchor() {
        #expect(ScrollSync.previewFraction(forEditorLine: 99, totalLines: 21, anchors: anchors) == 1.0)
    }

    @Test func proportionalFallbackWithoutAnchors() {
        let f = ScrollSync.previewFraction(forEditorLine: 5, totalLines: 10, anchors: [])
        #expect(abs(f - 0.5) < 0.01)
    }

    @Test func handlesUnsortedAnchors() {
        let unsorted = [
            ScrollAnchor(sourceLine: 21, fraction: 1.0),
            ScrollAnchor(sourceLine: 1, fraction: 0.0),
            ScrollAnchor(sourceLine: 11, fraction: 0.5),
        ]
        let f = ScrollSync.previewFraction(forEditorLine: 11, totalLines: 21, anchors: unsorted)
        #expect(abs(f - 0.5) < 0.01)
    }
}
