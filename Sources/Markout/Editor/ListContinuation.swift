import Foundation

/// The edit to apply when Return is pressed inside a list item.
/// `insert` is the text to insert at the caret; `removeCurrentMarker` signals an empty item
/// whose marker should be cleared (terminating the list) instead of continuing it.
struct ListEdit: Equatable {
    let insert: String
    let removeCurrentMarker: Bool
}

/// Computes automatic list continuation for the Return key. Pure; returns nil for non-list lines
/// (the caller then inserts a plain newline).
enum ListContinuation {
    static func onReturn(line: String) -> ListEdit? {
        let chars = Array(line)
        var i = 0
        while i < chars.count, chars[i] == " " || chars[i] == "\t" { i += 1 }
        let indent = String(chars[0..<i])
        guard i < chars.count else { return nil }
        let afterIndent = String(chars[i...])

        // Unordered / task list: "- ", "* ", "+ ", optionally "[ ] " / "[x] ".
        for bullet in ["-", "*", "+"] {
            let prefix = "\(bullet) "
            guard afterIndent.hasPrefix(prefix) else { continue }
            let remainder = String(afterIndent.dropFirst(prefix.count))
            let taskPrefixes = ["[ ] ", "[x] ", "[X] "]
            if let task = taskPrefixes.first(where: { remainder.hasPrefix($0) }) {
                let content = String(remainder.dropFirst(task.count))
                if content.trimmingCharacters(in: .whitespaces).isEmpty {
                    return ListEdit(insert: "", removeCurrentMarker: true)
                }
                return ListEdit(insert: "\n\(indent)\(bullet) [ ] ", removeCurrentMarker: false)
            }
            if remainder.trimmingCharacters(in: .whitespaces).isEmpty {
                return ListEdit(insert: "", removeCurrentMarker: true)
            }
            return ListEdit(insert: "\n\(indent)\(bullet) ", removeCurrentMarker: false)
        }

        // Ordered: "<digits>. ".
        if let first = afterIndent.first, first.isNumber {
            let digits = afterIndent.prefix { $0.isNumber }
            let rest = afterIndent.dropFirst(digits.count)
            if rest.hasPrefix(". ") {
                let content = String(rest.dropFirst(2))
                if content.trimmingCharacters(in: .whitespaces).isEmpty {
                    return ListEdit(insert: "", removeCurrentMarker: true)
                }
                let next = (Int(digits) ?? 1) + 1
                return ListEdit(insert: "\n\(indent)\(next). ", removeCurrentMarker: false)
            }
        }

        return nil
    }
}
