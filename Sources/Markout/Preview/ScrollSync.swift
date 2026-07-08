import Foundation

/// Maps a preview block's source line to its vertical position (0…1) in the rendered document.
struct ScrollAnchor: Equatable {
    let sourceLine: Int
    let fraction: Double
}

/// Pure editor→preview scroll mapping.
///
/// Given the anchors reported from the preview (each `data-sourcepos` block's top offset as a
/// fraction of scroll height) and the editor's top visible source line, returns the preview scroll
/// fraction. Falls back to proportional scrolling when anchors are unavailable. Kept pure so the
/// mapping is unit-tested without a WebView.
enum ScrollSync {
    static func previewFraction(
        forEditorLine line: Int,
        totalLines: Int,
        anchors: [ScrollAnchor]
    ) -> Double {
        guard !anchors.isEmpty else {
            let total = max(totalLines, 1)
            return clamp(Double(line) / Double(total))
        }

        let sorted = anchors.sorted { $0.sourceLine < $1.sourceLine }

        if line <= sorted.first!.sourceLine {
            return clamp(sorted.first!.fraction)
        }
        if line >= sorted.last!.sourceLine {
            return clamp(sorted.last!.fraction)
        }

        // Find the bracketing pair and interpolate.
        for i in 0..<(sorted.count - 1) {
            let lo = sorted[i]
            let hi = sorted[i + 1]
            if line >= lo.sourceLine, line <= hi.sourceLine {
                let span = hi.sourceLine - lo.sourceLine
                guard span > 0 else { return clamp(lo.fraction) }
                let t = Double(line - lo.sourceLine) / Double(span)
                return clamp(lo.fraction + t * (hi.fraction - lo.fraction))
            }
        }

        return clamp(sorted.last!.fraction)
    }

    private static func clamp(_ x: Double) -> Double {
        min(1.0, max(0.0, x))
    }
}
