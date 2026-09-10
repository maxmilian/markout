# Document Tabs and Recent Documents Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Open several Markdown documents as native macOS tabs in one window, and give a welcome window that lists recently opened documents for one-click reopening.

**Architecture:** `DocumentGroup` is untouched — each tab stays a full document window, joined into one tab group by an `NSViewRepresentable` that calls `addTabbedWindow`. Because the system's recent-documents list never persists for this ad-hoc-signed app, Markout keeps its own list in `~/Library/Application Support/Markout/recents.json`, split into pure list/format functions (unit-tested) and a thin store that does the file I/O. An `NSApplicationDelegate` closes the blank document SwiftUI creates at launch and puts an AppKit-hosted welcome window in its place.

**Tech Stack:** Swift 5.9, SwiftUI + AppKit, Swift Testing, XcodeGen, macOS 14.0 deployment target.

**Spec:** `docs/superpowers/specs/2026-09-10-tabs-and-recents-design.md`

## Global Constraints

- Deployment target macOS 14.0, Swift 5.9. No API newer than macOS 14 (`defaultLaunchBehavior` is macOS 15+ and must not be used).
- The Xcode project is generated. **After creating or deleting any source file, run `xcodegen generate` before building.**
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`) in `Tests/MarkoutTests/`. Pure logic is unit-tested; AppKit/WebKit wiring is verified by launching the app.
- Backward compatibility is preserved additively — existing signatures keep working, existing tests stay green.
- Commit messages are Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`).
- Recents list cap: **10** entries. Store path: `~/Library/Application Support/Markout/recents.json`, format `{"version": 1, "entries": [{"path": String, "openedAt": Double}]}` with dates encoded as seconds since 1970.
- Tabbing identifier: `tech.ankey.Markout.document`.
- **UI copy is English**, matching the rest of the app (`Reload from Disk`, `Export as HTML…`). The spec's row examples are written in Chinese (`今天 14:02`); implement them as `Today 14:02` / `Yesterday` / `Sep 7` / `Sep 7, 2025`.

Build and test commands:

```sh
xcodegen generate
xcodebuild test -project Markout.xcodeproj -scheme Markout \
  -destination 'platform=macOS' -derivedDataPath .build/dd \
  -only-testing:MarkoutTests/RecentDocumentsTests
xcodebuild build -project Markout.xcodeproj -scheme Markout \
  -destination 'platform=macOS' -derivedDataPath .build/dd
open .build/dd/Build/Products/Debug/Markout.app
```

## File Structure

| File | Responsibility |
|---|---|
| `Sources/Markout/Document/RecentDocuments.swift` (create) | `RecentDocument`, `RecentDocumentsList` (pure record/cap/order/codec), `RecentDocumentDisplay` (pure path + time formatting), `RecentDocumentsStore` (file I/O, `ObservableObject`) |
| `Sources/Markout/App/WindowTabbing.swift` (create) | `WindowTabbingAccessor` — tags the document window and joins the tab group |
| `Sources/Markout/App/WelcomeView.swift` (create) | The welcome window's SwiftUI content |
| `Sources/Markout/App/WelcomeWindowController.swift` (create) | Creates/holds the AppKit welcome window, opens documents |
| `Sources/Markout/App/AppDelegate.swift` (create) | Launch handling: suppress the open panel, close the blank document, show the welcome window |
| `Sources/Markout/App/ContentView.swift` (modify) | Add `.background(WindowTabbingAccessor())` and record the open document |
| `Sources/Markout/App/MarkoutApp.swift` (modify) | `@NSApplicationDelegateAdaptor`, `Window ▸ Welcome to Markout` command |
| `Tests/MarkoutTests/RecentDocumentsTests.swift` (create) | Unit tests for the pure functions and the store |

---

### Task 1: Recent documents list model

**Files:**
- Create: `Sources/Markout/Document/RecentDocuments.swift`
- Test: `Tests/MarkoutTests/RecentDocumentsTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `struct RecentDocument: Equatable, Codable { var path: String; var openedAt: Date }`
  - `enum RecentDocumentsList` with `static let maxCount = 10`, `static func record(_ url: URL, at date: Date, into entries: [RecentDocument]) -> [RecentDocument]`, `static func encode(_ entries: [RecentDocument]) -> Data`, `static func decode(_ data: Data?) -> [RecentDocument]`

- [ ] **Step 1: Write the failing tests**

Create `Tests/MarkoutTests/RecentDocumentsTests.swift`:

```swift
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
```

- [ ] **Step 2: Run the tests to verify they fail**

```sh
xcodegen generate
xcodebuild test -project Markout.xcodeproj -scheme Markout \
  -destination 'platform=macOS' -derivedDataPath .build/dd \
  -only-testing:MarkoutTests/RecentDocumentsTests 2>&1 | tail -20
```

Expected: FAIL — `cannot find 'RecentDocumentsList' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Sources/Markout/Document/RecentDocuments.swift`:

```swift
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
```

- [ ] **Step 4: Run the tests to verify they pass**

```sh
xcodegen generate
xcodebuild test -project Markout.xcodeproj -scheme Markout \
  -destination 'platform=macOS' -derivedDataPath .build/dd \
  -only-testing:MarkoutTests/RecentDocumentsTests 2>&1 | tail -20
```

Expected: PASS, 7 tests.

Note on the `/tmp` literals: `resolvingSymlinksInPath()` resolves `/tmp` to `/private/tmp` and then strips the `/private` prefix again, so `/tmp/...` paths round-trip unchanged whether or not the file exists (verified on macOS 26.6.2). The expectations can safely use `/tmp/...`.

- [ ] **Step 5: Commit**

```sh
git add Sources/Markout/Document/RecentDocuments.swift Tests/MarkoutTests/RecentDocumentsTests.swift
git commit -m "feat: add recent documents list model"
```

---

### Task 2: Row display formatting

**Files:**
- Modify: `Sources/Markout/Document/RecentDocuments.swift` (append)
- Test: `Tests/MarkoutTests/RecentDocumentsTests.swift` (append)

**Interfaces:**
- Consumes: `RecentDocument` from Task 1.
- Produces: `enum RecentDocumentDisplay` with
  - `static func name(for path: String) -> String`
  - `static func directory(for path: String, homeDirectory: String) -> String`
  - `static func timestamp(_ date: Date, now: Date, calendar: Calendar, locale: Locale) -> String`

- [ ] **Step 1: Write the failing tests**

Append to the end of `Tests/MarkoutTests/RecentDocumentsTests.swift` as an extension — do **not** try to splice these into the struct body from Task 1:

```swift
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
```

- [ ] **Step 2: Run the tests to verify they fail**

```sh
xcodebuild test -project Markout.xcodeproj -scheme Markout \
  -destination 'platform=macOS' -derivedDataPath .build/dd \
  -only-testing:MarkoutTests/RecentDocumentsTests 2>&1 | tail -20
```

Expected: FAIL — `cannot find 'RecentDocumentDisplay' in scope`.

- [ ] **Step 3: Write the implementation**

Append to `Sources/Markout/Document/RecentDocuments.swift`:

```swift
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
```

- [ ] **Step 4: Run the tests to verify they pass**

```sh
xcodebuild test -project Markout.xcodeproj -scheme Markout \
  -destination 'platform=macOS' -derivedDataPath .build/dd \
  -only-testing:MarkoutTests/RecentDocumentsTests 2>&1 | tail -20
```

Expected: PASS, 13 tests.

- [ ] **Step 5: Commit**

```sh
git add Sources/Markout/Document/RecentDocuments.swift Tests/MarkoutTests/RecentDocumentsTests.swift
git commit -m "feat: add recent document row formatting"
```

---

### Task 3: Recents store on disk

**Files:**
- Modify: `Sources/Markout/Document/RecentDocuments.swift` (append)
- Test: `Tests/MarkoutTests/RecentDocumentsTests.swift` (append)

**Interfaces:**
- Consumes: `RecentDocumentsList` from Task 1.
- Produces: `final class RecentDocumentsStore: ObservableObject` with
  - `static let shared: RecentDocumentsStore`
  - `init(fileURL: URL)`
  - `@Published private(set) var entries: [RecentDocument]`
  - `func record(_ url: URL, at date: Date = Date())`
  - `func reload()`

- [ ] **Step 1: Write the failing tests**

Append to the end of `Tests/MarkoutTests/RecentDocumentsTests.swift` as a second extension:

```swift
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
```

- [ ] **Step 2: Run the tests to verify they fail**

```sh
xcodebuild test -project Markout.xcodeproj -scheme Markout \
  -destination 'platform=macOS' -derivedDataPath .build/dd \
  -only-testing:MarkoutTests/RecentDocumentsTests 2>&1 | tail -20
```

Expected: FAIL — `cannot find 'RecentDocumentsStore' in scope`.

- [ ] **Step 3: Write the implementation**

Append to `Sources/Markout/Document/RecentDocuments.swift`:

```swift
/// Reads and writes the recents list. The thin I/O edge over `RecentDocumentsList`.
final class RecentDocumentsStore: ObservableObject {
    static let shared = RecentDocumentsStore(fileURL: RecentDocumentsStore.defaultFileURL)

    @Published private(set) var entries: [RecentDocument] = []

    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
        reload()
    }

    /// `~/Library/Application Support/Markout/recents.json`.
    static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("Markout", isDirectory: true)
            .appendingPathComponent("recents.json")
    }

    func reload() {
        entries = RecentDocumentsList.decode(try? Data(contentsOf: fileURL))
    }

    /// Records `url` as most recently opened and persists the list. Write failures are ignored —
    /// recents must never interrupt opening or saving a document.
    func record(_ url: URL, at date: Date = Date()) {
        entries = RecentDocumentsList.record(url, at: date, into: entries)
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? RecentDocumentsList.encode(entries).write(to: fileURL, options: .atomic)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```sh
xcodebuild test -project Markout.xcodeproj -scheme Markout \
  -destination 'platform=macOS' -derivedDataPath .build/dd \
  -only-testing:MarkoutTests/RecentDocumentsTests 2>&1 | tail -20
```

Expected: PASS, 16 tests.

- [ ] **Step 5: Run the whole suite to confirm nothing regressed**

```sh
xcodebuild test -project Markout.xcodeproj -scheme Markout \
  -destination 'platform=macOS' -derivedDataPath .build/dd 2>&1 | tail -20
```

Expected: `TEST SUCCEEDED`.

- [ ] **Step 6: Commit**

```sh
git add Sources/Markout/Document/RecentDocuments.swift Tests/MarkoutTests/RecentDocumentsTests.swift
git commit -m "feat: persist recent documents to application support"
```

---

### Task 4: Document windows open as tabs

**Files:**
- Create: `Sources/Markout/App/WindowTabbing.swift`
- Modify: `Sources/Markout/App/ContentView.swift` (the `.frame(minWidth: 800, minHeight: 500)` line in `body`, around line 105)

**Interfaces:**
- Consumes: `RecentDocumentsStore.shared` from Task 3.
- Produces: `struct WindowTabbingAccessor: NSViewRepresentable`, and the constant `let markoutDocumentTabbingIdentifier = NSWindow.TabbingIdentifier("tech.ankey.Markout.document")` (`TabbingIdentifier` is a typealias for `String`).

Spike note: setting `tabbingMode` alone is **not** enough — a window that already exists will not retroactively join a group. The new window must actively call `addTabbedWindow` on an existing one.

- [ ] **Step 1: Create the accessor**

Create `Sources/Markout/App/WindowTabbing.swift`:

```swift
import AppKit
import SwiftUI

let markoutDocumentTabbingIdentifier = NSWindow.TabbingIdentifier("tech.ankey.Markout.document")

/// Joins each new document window into Markout's single tab group.
///
/// `DocumentGroup` gives every document its own window. Setting `tabbingMode` on a window that
/// already exists is too late to group it, so the new window explicitly adds itself as a tab of an
/// existing document window. Everything else — the tab bar, ⌘⇧[ / ⌘⇧], drag-out, Merge All
/// Windows — is then handled by AppKit.
struct WindowTabbingAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    /// The view has no window during `makeNSView`, and there is no callback for gaining one, so the
    /// attempt is repeated from `updateNSView`. Joining is idempotent: once the window is in a
    /// group, every later attempt finds no host outside it and does nothing.
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { joinTabGroup(from: nsView) }
    }

    private func joinTabGroup(from view: NSView) {
        guard let window = view.window else { return }
        window.tabbingMode = .preferred
        window.tabbingIdentifier = markoutDocumentTabbingIdentifier

        guard let host = tabHost(for: window) else { return }
        host.addTabbedWindow(window, ordered: .above)
        window.makeKeyAndOrderFront(nil)
    }

    /// The window whose tab group the new document should join.
    ///
    /// Preferring the key (then main) window keeps a new document in the group the user is working
    /// in, and on that group's screen. Falling back to any document window would drop it into an
    /// arbitrary group — including one the user just deliberately dragged out.
    private func tabHost(for window: NSWindow) -> NSWindow? {
        func isCandidate(_ candidate: NSWindow) -> Bool {
            candidate !== window
                && candidate.tabbingIdentifier == markoutDocumentTabbingIdentifier
                && candidate.isVisible
                && (window.tabGroup == nil || candidate.tabGroup !== window.tabGroup)
        }

        if let key = NSApp.keyWindow, isCandidate(key) { return key }
        if let main = NSApp.mainWindow, isCandidate(main) { return main }
        return NSApp.windows.first(where: isCandidate)
    }
}
```

- [ ] **Step 2: Wire it into ContentView**

In `Sources/Markout/App/ContentView.swift`, find in `body`:

```swift
        .frame(minWidth: 800, minHeight: 500)
        .toolbar {
```

Replace with:

```swift
        .frame(minWidth: 800, minHeight: 500)
        .background(WindowTabbingAccessor())
        .task(id: documentURL) {
            guard let documentURL else { return }
            RecentDocumentsStore.shared.record(documentURL)
        }
        .toolbar {
```

- [ ] **Step 3: Build**

```sh
xcodegen generate
xcodebuild build -project Markout.xcodeproj -scheme Markout \
  -destination 'platform=macOS' -derivedDataPath .build/dd 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Verify tabbing by hand**

```sh
mkdir -p /tmp/markout-check
printf '# A\n\nfirst\n'  > /tmp/markout-check/a.md
printf '# B\n\nsecond\n' > /tmp/markout-check/b.md
open -a .build/dd/Build/Products/Debug/Markout.app /tmp/markout-check/a.md /tmp/markout-check/b.md
```

Confirm, in the running app:
- One window with a tab bar showing `a.md` and `b.md`.
- ⌘⇧] and ⌘⇧[ switch tabs.
- Dragging a tab out makes a separate window; `Window ▸ Merge All Windows` puts it back.
- After dragging a tab out, ⌘N adds its tab to whichever window is frontmost — not always the original one.
- ⌘N adds a new `Untitled` tab rather than a separate window.
- Editing and ⌘S still save the correct file.

- [ ] **Step 5: Verify recents are being recorded**

```sh
cat ~/Library/Application\ Support/Markout/recents.json
```

Expected: a `version: 1` object whose `entries` contain `/tmp/markout-check/a.md` and `/tmp/markout-check/b.md`, newest first.

- [ ] **Step 6: Commit**

```sh
git add Sources/Markout/App/WindowTabbing.swift Sources/Markout/App/ContentView.swift
git commit -m "feat: open documents as native window tabs"
```

---

### Task 5: Welcome window

**Files:**
- Create: `Sources/Markout/App/WelcomeView.swift`
- Create: `Sources/Markout/App/WelcomeWindowController.swift`

Rows open through `NSDocumentController.shared.openDocument(withContentsOf:display:)`, not the SwiftUI `openDocument` environment action: this window is hosted outside the `DocumentGroup` scene, where that environment value has no scene to route into. The spec says the same; the Fallback Notes at the end cover what to try if the document controller path misbehaves.

**Interfaces:**
- Consumes: `RecentDocumentsStore`, `RecentDocumentDisplay`, `RecentDocument` from Tasks 1–3.
- Produces:
  - `struct WelcomeView: View` — `init(store: RecentDocumentsStore, onOpen: @escaping (URL) -> Void, onNewDocument: @escaping () -> Void, onOpenPanel: @escaping () -> Void)`
  - `final class WelcomeWindowController` — `static let shared`, `func show()`, `func close()`

- [ ] **Step 1: Write the welcome view**

Create `Sources/Markout/App/WelcomeView.swift`:

```swift
import SwiftUI

/// The welcome window's content: what you can start from, and what you had open recently.
struct WelcomeView: View {
    @ObservedObject var store: RecentDocumentsStore
    var onOpen: (URL) -> Void
    var onNewDocument: () -> Void
    var onOpenPanel: () -> Void

    private var homeDirectory: String { NSHomeDirectory() }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Markout").font(.system(size: 22, weight: .semibold))
                Text("Markdown editor").foregroundStyle(.secondary).font(.callout)
            }

            HStack(spacing: 8) {
                Button("New Document", action: onNewDocument)
                    .keyboardShortcut(.defaultAction)
                Button("Open…", action: onOpenPanel)
            }

            Divider()

            if store.entries.isEmpty {
                Text("No recent documents")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.entries, id: \.path) { entry in
                            row(for: entry)
                            Divider()
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 340)
    }

    @ViewBuilder
    private func row(for entry: RecentDocument) -> some View {
        let exists = FileManager.default.fileExists(atPath: entry.path)
        Button {
            onOpen(URL(fileURLWithPath: entry.path))
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(RecentDocumentDisplay.name(for: entry.path))
                        .fontWeight(.medium)
                    Spacer()
                    Text(RecentDocumentDisplay.timestamp(
                        entry.openedAt, now: Date(),
                        calendar: Calendar.current, locale: Locale.current))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(RecentDocumentDisplay.directory(
                    for: entry.path, homeDirectory: homeDirectory))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
            // The tooltip sits on the content, not the Button: a disabled control is not
            // guaranteed to show its own help text.
            .help(exists ? entry.path : "File not found: \(entry.path)")
        }
        .buttonStyle(.plain)
        .disabled(!exists)
        .opacity(exists ? 1 : 0.4)
    }
}
```

- [ ] **Step 2: Write the window controller**

Create `Sources/Markout/App/WelcomeWindowController.swift`:

```swift
import AppKit
import SwiftUI

/// Owns the welcome window.
///
/// It is an AppKit window rather than a SwiftUI `Window` scene because the app delegate has to open
/// it at launch, and macOS 14 has no supported way to open a scene from there.
@MainActor
final class WelcomeWindowController {
    static let shared = WelcomeWindowController()

    private var window: NSWindow?

    func show() {
        // Re-read the list on every show. Whether a row is dimmed, and the relative time it
        // displays, are computed while drawing — and nothing tells the app when a recorded file is
        // renamed or deleted behind its back. Reassigning `entries` republishes even when the
        // contents are unchanged, which is what forces the redraw.
        RecentDocumentsStore.shared.reload()

        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = WelcomeView(
            store: RecentDocumentsStore.shared,
            onOpen: { [weak self] url in
                // Open first, close second: if the file vanished between drawing the list and the
                // click, the welcome window must stay where it is rather than flicker away and back.
                NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
                    guard error == nil else {
                        RecentDocumentsStore.shared.reload()
                        return
                    }
                    self?.close()
                }
            },
            onNewDocument: { [weak self] in
                self?.close()
                NSDocumentController.shared.newDocument(nil)
            },
            onOpenPanel: {
                NSDocumentController.shared.openDocument(nil)
            })

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 380),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = "Welcome to Markout"
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: view)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func close() {
        window?.close()
    }
}
```

- [ ] **Step 3: Build**

```sh
xcodegen generate
xcodebuild build -project Markout.xcodeproj -scheme Markout \
  -destination 'platform=macOS' -derivedDataPath .build/dd 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`. Nothing shows the window yet — Task 6 wires it up.

- [ ] **Step 4: Commit**

```sh
git add Sources/Markout/App/WelcomeView.swift Sources/Markout/App/WelcomeWindowController.swift
git commit -m "feat: add welcome window listing recent documents"
```

---

### Task 6: Launch behavior and menu command

**Files:**
- Create: `Sources/Markout/App/AppDelegate.swift`
- Modify: `Sources/Markout/App/MarkoutApp.swift` (the `struct MarkoutApp: App {` line and the `.commands { }` block)

**Interfaces:**
- Consumes: `WelcomeWindowController.shared` from Task 5.
- Produces: `final class AppDelegate: NSObject, NSApplicationDelegate`.

Spike notes, all measured on macOS 26.6.2 — do not "simplify" these away:
- `applicationShouldOpenUntitledFile` is **never called**; `DocumentGroup` creates the launch document itself.
- Without `NSShowAppCentricOpenPanelInsteadOfUntitledFile = false`, macOS shows an Open panel at launch instead.
- The blank document exists shortly *after* `applicationDidFinishLaunching`, so it is closed on a short delay; 0.3 s was measured as sufficient, and files passed on the command line are already present by then, so they are correctly left alone.

- [ ] **Step 1: Write the app delegate**

Create `Sources/Markout/App/AppDelegate.swift`:

```swift
import AppKit
import SwiftUI

/// Turns "launched with nothing to open" into the welcome window.
///
/// SwiftUI's `DocumentGroup` insists on starting a document at launch and does not consult
/// `applicationShouldOpenUntitledFile`, so the blank document is closed right after it appears.
/// Documents opened from Finder, the CLI, or state restoration are present by then and are left
/// alone — the welcome window only appears when no document survives this check.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// How long to wait for `DocumentGroup` to create its launch document. Measured at ~0.3 s.
    private let launchSettleDelay: TimeInterval = 0.3

    override init() {
        super.init()
        UserDefaults.standard.register(
            defaults: ["NSShowAppCentricOpenPanelInsteadOfUntitledFile": false])
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The unit tests are hosted by this app, so launching them runs this delegate. Without
        // this guard a welcome window pops up mid-test and steals focus.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + launchSettleDelay) {
            let controller = NSDocumentController.shared
            for document in controller.documents
            where document.fileURL == nil
                && !document.isDocumentEdited
                // An unsaved document restored from autosave also has no file URL and a clean
                // change count. It holds the user's work and must survive.
                && document.autosavedContentsFileURL == nil {
                document.close()
            }
            if controller.documents.isEmpty {
                WelcomeWindowController.shared.show()
            }
        }
    }

    /// Clicking the Dock icon with no windows open lands on the welcome window rather than nothing.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        guard !hasVisibleWindows, NSDocumentController.shared.documents.isEmpty else { return true }
        WelcomeWindowController.shared.show()
        return false
    }
}
```

- [ ] **Step 2: Wire the delegate and the menu command into MarkoutApp**

In `Sources/Markout/App/MarkoutApp.swift`, replace:

```swift
struct MarkoutApp: App {
    @FocusedValue(\.documentActions) private var documentActions
```

with:

```swift
struct MarkoutApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @FocusedValue(\.documentActions) private var documentActions
```

Then, inside `.commands { }`, add after the `CommandMenu("Format") { … }` block:

```swift
            CommandGroup(before: .windowList) {
                Button("Welcome to Markout") {
                    WelcomeWindowController.shared.show()
                }
                Divider()
            }
```

- [ ] **Step 3: Build**

```sh
xcodegen generate
xcodebuild build -project Markout.xcodeproj -scheme Markout \
  -destination 'platform=macOS' -derivedDataPath .build/dd 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Verify each launch situation by hand**

Quit any running Markout first (`osascript -e 'tell application "Markout" to quit'`), and close all document windows before quitting so state restoration has nothing to restore.

The launch behaviors below were measured on macOS 26.6.2 and are OS-version sensitive; the deployment floor is macOS 14, where `DocumentGroup` may open a panel, an untitled document, or nothing. The delegate is written to be indifferent to which happens — close a blank, unedited, un-restored document if one appeared, then show the welcome window if nothing remains — so verify the *outcomes* in this table rather than the intermediate state.

| Do this | Expect |
|---|---|
| `open -a .build/dd/Build/Products/Debug/Markout.app` with no documents open at last quit | Welcome window appears; no blank document window, no Open panel |
| Click a recents row | That document opens as a document window; the welcome window closes |
| `open -a … /tmp/markout-check/a.md /tmp/markout-check/b.md` | Both open as tabs; no welcome window |
| Quit with documents open, then relaunch | Documents are restored; no welcome window |
| `Window ▸ Welcome to Markout` while editing | Welcome window appears alongside, not as a tab |
| `mv /tmp/markout-check/a.md /tmp/markout-check/renamed.md`, then reopen the welcome window | The `a.md` row is dimmed, unclickable, tooltip reads `File not found: …` |
| Quit and relaunch | The recents list still lists the same files |
| Close every window, then click the Dock icon | The welcome window appears |
| Open a document already open in a tab, from the welcome window | Its existing tab comes forward; no duplicate; welcome window closes |
| Set *System Settings ▸ Desktop & Dock ▸ Prefer tabs* to *Always*, relaunch | The welcome window and Settings (⌘,) stay separate windows, never tabs |
| With the welcome window frontmost, open the Format menu | Every item is disabled; `⌘R` and the Export commands are disabled too |
| Switch to another tab, then `⌘R` and Export | Both act on the newly selected tab's file |

- [ ] **Step 5: Run the full test suite**

```sh
xcodebuild test -project Markout.xcodeproj -scheme Markout \
  -destination 'platform=macOS' -derivedDataPath .build/dd 2>&1 | tail -20
```

Expected: `TEST SUCCEEDED`.

- [ ] **Step 6: Commit**

```sh
git add Sources/Markout/App/AppDelegate.swift Sources/Markout/App/MarkoutApp.swift
git commit -m "feat: show the welcome window when launching with no document"
```

- [ ] **Step 7: Clean up the scratch files**

```sh
rm -rf /tmp/markout-check
```

---

## Fallback Notes

`NSDocumentController.shared.openDocument(withContentsOf:display:)` is the intended path, but it was not exercised during the spike — the welcome window was drawn, never clicked. If Step 4 of Task 6 shows it failing to open the file, swap that call for the SwiftUI environment action inside `WelcomeView`:

```swift
@Environment(\.openDocument) private var openDocument
// …
Task { try? await openDocument(at: URL(fileURLWithPath: entry.path)) }
```

If *that* also fails because the view is hosted outside the `DocumentGroup` scene, fall back to `NSWorkspace.shared.open(url)`, which routes back through the app's own document handling.
