import Testing
import Foundation
@testable import Markout

struct PreviewThemeStoreTests {
    /// Writes CSS fixtures into a fresh temp directory and returns its URL.
    private func fixtureDirectory(_ files: [String: String]) throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("markout-themes-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        for (name, contents) in files {
            try contents.write(to: base.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        return base
    }

    @Test func loadsThemesFromDirectory() throws {
        let dir = try fixtureDirectory([
            "github.css": "body{color:black}",
            "dracula.css": "body{color:pink}",
            "notes.txt": "ignore me",
        ])
        defer { try? FileManager.default.removeItem(at: dir) }

        let themes = PreviewThemeStore.themes(inDirectory: dir)
        #expect(themes.count == 2)
        #expect(themes.map(\.id).sorted() == ["dracula", "github"])
        let github = themes.first { $0.id == "github" }
        #expect(github?.css == "body{color:black}")
    }

    @Test func prettifiesName() throws {
        let dir = try fixtureDirectory(["github-dark-dimmed.css": "/*x*/"])
        defer { try? FileManager.default.removeItem(at: dir) }
        let theme = PreviewThemeStore.themes(inDirectory: dir).first
        #expect(theme?.name == "Github Dark Dimmed")
    }

    @Test func customThemeLoadsFileContents() throws {
        let dir = try fixtureDirectory(["mine.css": "body{color:teal}"])
        defer { try? FileManager.default.removeItem(at: dir) }
        let theme = PreviewThemeStore.custom(fromFileURL: dir.appendingPathComponent("mine.css"))
        #expect(theme?.css == "body{color:teal}")
        #expect(theme?.name == "mine")
    }

    @Test func customThemeNilForMissingFile() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("nope-\(UUID()).css")
        #expect(PreviewThemeStore.custom(fromFileURL: missing) == nil)
    }
}
