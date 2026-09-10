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

/// How one recents row is worded. Pure, so the wording is unit-tested rather than eyeballed.
enum RecentDocumentDisplay {
    static func name(for path: String) -> String {
        (path as NSString).lastPathComponent
    }

    /// The containing directory, with the user's home folder shown as `~`.
    static func directory(for path: String, homeDirectory: String) -> String {
        let directory = (path as NSString).deletingLastPathComponent
        if directory == homeDirectory { return "~" }
        if directory.hasPrefix(homeDirectory + "/") {
            return "~" + directory.dropFirst(homeDirectory.count)
        }
        return directory
    }

    /// `Today 14:02` / `Yesterday` / `Sep 7` / `Sep 7, 2025`.
    static func timestamp(_ date: Date, now: Date, calendar: Calendar, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone

        if calendar.isDate(date, inSameDayAs: now) {
            formatter.dateFormat = "HH:mm"
            return "Today " + formatter.string(from: date)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        formatter.dateFormat = sameYear ? "MMM d" : "MMM d, yyyy"
        return formatter.string(from: date)
    }
}
