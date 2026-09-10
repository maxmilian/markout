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
