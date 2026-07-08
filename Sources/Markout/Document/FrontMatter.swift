import Foundation

/// Parsed YAML front matter: the raw inner block plus shallow `key: value` scalars.
struct FrontMatter: Equatable {
    let raw: String
    let values: [String: String]
}

/// Splits a leading `---` YAML front-matter block off a document.
///
/// A block is recognized only when the document's first line is exactly `---`, terminated by a
/// later line that is exactly `---` or `...`. Otherwise the whole text is returned as the body.
/// Only leaf `key: value` scalars are parsed into `values`; the full inner text is kept in `raw`
/// (nested YAML is preserved there but not deep-parsed). Pure, never throws.
enum FrontMatterParser {
    static func split(_ text: String) -> (front: FrontMatter?, body: String) {
        let lines = text.components(separatedBy: "\n")
        guard lines.first == "---" else { return (nil, text) }

        // Find the closing delimiter.
        var closing = -1
        for i in 1..<lines.count where lines[i] == "---" || lines[i] == "..." {
            closing = i
            break
        }
        guard closing > 0 else { return (nil, text) }

        let inner = lines[1..<closing]
        var values: [String: String] = [:]
        for line in inner {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            values[key] = value
        }

        let front = FrontMatter(raw: inner.joined(separator: "\n"), values: values)
        let body = lines[(closing + 1)...].joined(separator: "\n")
        return (front, body)
    }
}
