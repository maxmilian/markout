import Foundation
import Testing
@testable import Markout

struct RecentDocumentsTests {
    private let now = Date(timeIntervalSince1970: 1_789_041_600)   // 2026-09-10 12:00 UTC

    @Test func recordingPutsNewestFirst() {
        var entries = RecentDocumentsList.record(
            URL(fileURLWithPath: "/tmp/a.md"), at: now, into: [])
        entries = RecentDocumentsList.record(
            URL(fileURLWithPath: "/tmp/b.md"), at: now.addingTimeInterval(60), into: entries)

        #expect(entries.map(\.path) == ["/tmp/b.md", "/tmp/a.md"])
    }

    @Test func recordingAnExistingPathMovesItWithoutDuplicating() {
        var entries = RecentDocumentsList.record(
            URL(fileURLWithPath: "/tmp/a.md"), at: now, into: [])
        entries = RecentDocumentsList.record(
            URL(fileURLWithPath: "/tmp/b.md"), at: now.addingTimeInterval(60), into: entries)
        entries = RecentDocumentsList.record(
            URL(fileURLWithPath: "/tmp/a.md"), at: now.addingTimeInterval(120), into: entries)

        #expect(entries.map(\.path) == ["/tmp/a.md", "/tmp/b.md"])
        #expect(entries.count == 2)
        #expect(entries[0].openedAt == now.addingTimeInterval(120))
    }

    @Test func relativePathComponentsResolveToTheSameEntry() {
        var entries = RecentDocumentsList.record(
            URL(fileURLWithPath: "/tmp/notes/a.md"), at: now, into: [])
        entries = RecentDocumentsList.record(
            URL(fileURLWithPath: "/tmp/notes/../notes/a.md"),
            at: now.addingTimeInterval(60), into: entries)

        #expect(entries.count == 1)
        #expect(entries[0].path == "/tmp/notes/a.md")
    }

    @Test func listIsCappedAtTenDroppingTheOldest() {
        var entries: [RecentDocument] = []
        for index in 0..<12 {
            entries = RecentDocumentsList.record(
                URL(fileURLWithPath: "/tmp/file\(index).md"),
                at: now.addingTimeInterval(Double(index)), into: entries)
        }

        #expect(entries.count == RecentDocumentsList.maxCount)
        #expect(entries.first?.path == "/tmp/file11.md")
        #expect(entries.last?.path == "/tmp/file2.md")
    }

    @Test func encodingRoundTripsEntriesAndOrder() {
        let entries = [
            RecentDocument(path: "/tmp/b.md", openedAt: now.addingTimeInterval(60)),
            RecentDocument(path: "/tmp/a.md", openedAt: now)
        ]

        #expect(RecentDocumentsList.decode(RecentDocumentsList.encode(entries)) == entries)
    }

    @Test func missingOrCorruptDataDecodesToEmpty() {
        #expect(RecentDocumentsList.decode(nil).isEmpty)
        #expect(RecentDocumentsList.decode(Data("not json".utf8)).isEmpty)
        #expect(RecentDocumentsList.decode(Data()).isEmpty)
    }

    @Test func anUnknownVersionDecodesToEmpty() {
        let future = Data(#"{"version": 2, "entries": [{"path": "/tmp/a.md", "openedAt": 1}]}"#.utf8)
        #expect(RecentDocumentsList.decode(future).isEmpty)
    }
}

extension RecentDocumentsTests {
    private var enUS: Locale { Locale(identifier: "en_US_POSIX") }

    private func calendar(_ timeZone: String = "UTC") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    @Test func nameIsTheFileName() {
        #expect(RecentDocumentDisplay.name(for: "/Users/u/notes/spec.md") == "spec.md")
    }

    @Test func directoryAbbreviatesTheHomeFolder() {
        #expect(RecentDocumentDisplay.directory(
            for: "/Users/u/notes/spec.md", homeDirectory: "/Users/u") == "~/notes")
        #expect(RecentDocumentDisplay.directory(
            for: "/opt/data/spec.md", homeDirectory: "/Users/u") == "/opt/data")
        #expect(RecentDocumentDisplay.directory(
            for: "/Users/u/spec.md", homeDirectory: "/Users/u") == "~")
    }

    @Test func directoryDoesNotAbbreviateAnotherUsersHome() {
        #expect(RecentDocumentDisplay.directory(
            for: "/Users/uu/notes/spec.md", homeDirectory: "/Users/u") == "/Users/uu/notes")
    }

    @Test func timestampShowsTimeForToday() {
        let calendar = calendar()
        let now = Date(timeIntervalSince1970: 1_789_041_600)          // 2026-09-10 12:00 UTC
        let earlier = now.addingTimeInterval(-3600)                   // same day, 11:00 UTC

        #expect(RecentDocumentDisplay.timestamp(
            earlier, now: now, calendar: calendar, locale: enUS) == "Today 11:00")
    }

    @Test func timestampShowsYesterday() {
        let calendar = calendar()
        let now = Date(timeIntervalSince1970: 1_789_041_600)          // 2026-09-10 12:00 UTC
        let yesterday = now.addingTimeInterval(-24 * 3600)            // 2026-09-09

        #expect(RecentDocumentDisplay.timestamp(
            yesterday, now: now, calendar: calendar, locale: enUS) == "Yesterday")
    }

    @Test func timestampShowsDateWithinTheYearAndYearBeyondIt() {
        let calendar = calendar()
        let now = Date(timeIntervalSince1970: 1_789_041_600)          // 2026-09-10 12:00 UTC
        let sameYear = now.addingTimeInterval(-3 * 24 * 3600)         // 2026-09-07
        let earlierYear = now.addingTimeInterval(-400 * 24 * 3600)    // 2025-08-06

        #expect(RecentDocumentDisplay.timestamp(
            sameYear, now: now, calendar: calendar, locale: enUS) == "Sep 7")
        #expect(RecentDocumentDisplay.timestamp(
            earlierYear, now: now, calendar: calendar, locale: enUS) == "Aug 6, 2025")
    }
}

extension RecentDocumentsTests {
    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("markout-recents-tests", isDirectory: true)
            .appendingPathComponent("\(UUID().uuidString).json")
    }

    @Test func storeWritesAndReadsBackEntries() {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let store = RecentDocumentsStore(fileURL: url)
        store.record(URL(fileURLWithPath: "/tmp/a.md"), at: now)
        store.record(URL(fileURLWithPath: "/tmp/b.md"), at: now.addingTimeInterval(60))

        let reopened = RecentDocumentsStore(fileURL: url)
        #expect(reopened.entries.map(\.path) == ["/tmp/b.md", "/tmp/a.md"])
    }

    @Test func storeStartsEmptyWhenTheFileIsAbsent() {
        let store = RecentDocumentsStore(fileURL: temporaryStoreURL())
        #expect(store.entries.isEmpty)
    }

    @Test func storeStartsEmptyWhenTheFileIsCorrupt() throws {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: url)

        let store = RecentDocumentsStore(fileURL: url)
        #expect(store.entries.isEmpty)

        store.record(URL(fileURLWithPath: "/tmp/a.md"), at: now)
        #expect(RecentDocumentsStore(fileURL: url).entries.map(\.path) == ["/tmp/a.md"])
    }
}
