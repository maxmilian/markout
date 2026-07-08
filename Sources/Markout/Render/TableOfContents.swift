import Foundation

/// A document heading with its GitHub-compatible anchor slug.
struct Heading: Equatable {
    let level: Int
    let text: String
    let slug: String
}

/// A heading paired with its 1-based source line (for scroll-to navigation).
struct LocatedHeading: Equatable {
    let heading: Heading
    let line: Int
}

/// Extracts ATX headings and builds a table of contents.
///
/// Slugs follow the GitHub/cmark scheme (lowercase, punctuation dropped, whitespace → `-`,
/// duplicates suffixed `-1`, `-2`, …) so `[text](#slug)` links resolve against the rendered HTML.
/// Pure; headings inside fenced code are ignored.
enum TableOfContents {
    static func headings(in markdown: String) -> [Heading] {
        located(in: markdown).map(\.heading)
    }

    /// Headings with their 1-based source line numbers.
    static func located(in markdown: String) -> [LocatedHeading] {
        var result: [LocatedHeading] = []
        var seen: [String: Int] = [:]
        var inFence = false
        var fenceMarker: Character = "`"

        for (index, rawLine) in markdown.components(separatedBy: "\n").enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            // Track fenced code blocks.
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                let marker: Character = trimmed.first == "`" ? "`" : "~"
                if !inFence {
                    inFence = true
                    fenceMarker = marker
                } else if marker == fenceMarker {
                    inFence = false
                }
                continue
            }
            if inFence { continue }

            guard let heading = parseHeading(trimmed) else { continue }
            let base = slug(heading.text)
            let uniqueSlug: String
            if let count = seen[base] {
                seen[base] = count + 1
                uniqueSlug = "\(base)-\(count)"
            } else {
                seen[base] = 1
                uniqueSlug = base
            }
            let full = Heading(level: heading.level, text: heading.text, slug: uniqueSlug)
            result.append(LocatedHeading(heading: full, line: index + 1))
        }
        return result
    }

    static func markdownList(_ headings: [Heading]) -> String {
        guard let minLevel = headings.map(\.level).min() else { return "" }
        return headings.map { heading in
            let indent = String(repeating: "  ", count: heading.level - minLevel)
            return "\(indent)- [\(heading.text)](#\(heading.slug))"
        }.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func parseHeading(_ line: String) -> (level: Int, text: String)? {
        var level = 0
        var idx = line.startIndex
        while idx < line.endIndex, line[idx] == "#", level < 6 {
            level += 1
            idx = line.index(after: idx)
        }
        guard level > 0, idx < line.endIndex, line[idx] == " " else { return nil }
        var text = String(line[idx...]).trimmingCharacters(in: .whitespaces)
        // Strip an optional closing run of '#'.
        while text.hasSuffix("#") { text.removeLast() }
        text = text.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return (level, text)
    }

    private static func slug(_ text: String) -> String {
        let lowered = text.lowercased()
        var kept = ""
        for scalar in lowered.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == " " {
                kept.unicodeScalars.append(scalar)
            }
        }
        return kept.split(whereSeparator: { $0 == " " }).joined(separator: "-")
    }
}
