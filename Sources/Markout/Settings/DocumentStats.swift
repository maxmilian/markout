import Foundation

struct DocumentStats: Equatable {
    let words: Int
    let characters: Int
    let lines: Int
    let readingMinutes: Int
}

extension DocumentStats {
    static func compute(_ text: String) -> DocumentStats {
        let words = text.split(whereSeparator: { $0.isWhitespace }).count
        let characters = text.count
        let lines = text.isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count
        let readingMinutes = words == 0 ? 0 : Int(ceil(Double(words) / 200))
        return DocumentStats(words: words, characters: characters, lines: lines, readingMinutes: readingMinutes)
    }
}
