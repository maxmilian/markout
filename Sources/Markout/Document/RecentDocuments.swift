import Foundation

/// One entry in Markout's own recent-documents list.
///
/// Markout cannot use `NSDocumentController.recentDocumentURLs`: the app is ad-hoc signed, and
/// macOS discards the shared-file-list entries it cannot match to a stable code-signing identity,
/// so that list is empty on every launch. See the design doc's Spike Findings.
struct RecentDocument: Equatable, Codable {
    var path: String
    var openedAt: Date
}

/// Pure list operations over `[RecentDocument]`. All I/O lives in `RecentDocumentsStore`.
enum RecentDocumentsList {
    static let maxCount = 10

    /// Moves `url` to the front, replacing any existing entry for the same file, and caps the list.
    static func record(_ url: URL, at date: Date, into entries: [RecentDocument]) -> [RecentDocument] {
        let path = standardizedPath(for: url)
        var result = entries.filter { $0.path != path }
        result.insert(RecentDocument(path: path, openedAt: date), at: 0)
        return Array(result.prefix(maxCount))
    }

    /// The canonical form used to compare two URLs for the same file.
    static func standardizedPath(for url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    static func encode(_ entries: [RecentDocument]) -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let file = StoredFile(version: 1, entries: entries)
        return (try? encoder.encode(file)) ?? Data()
    }

    /// Decodes the store file. Missing or malformed data is an empty list, never an error:
    /// recents are a convenience and must not block opening or saving a document.
    static func decode(_ data: Data?) -> [RecentDocument] {
        guard let data, !data.isEmpty else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let file = try? decoder.decode(StoredFile.self, from: data),
              file.version == 1 else { return [] }
        return file.entries
    }

    private struct StoredFile: Codable {
        var version: Int
        var entries: [RecentDocument]
    }
}
