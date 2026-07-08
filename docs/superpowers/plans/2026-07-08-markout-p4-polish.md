# Markout P4 Preferences & Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Preferences window, editor color themes, a live word-count status bar, and a Markdown formatting toolbar on top of the P1–P3 editor.

**Architecture:** Settings persist via `@AppStorage`/`UserDefaults` and flow into the editor/preview by SwiftUI observation — no notification plumbing. Pure, testable cores (`DocumentStats`, `MarkdownFormatter`, `EditorThemeStore`, themed `SyntaxHighlighter.apply`) with thin UI edges (`SettingsView`, `.toolbar`, status-bar footer).

**Tech Stack:** Swift 5.9+, SwiftUI (`Settings` scene, `@AppStorage`), AppKit (`NSTextView`); P1–P3 code; XcodeGen; Swift Testing.

## Global Constraints

- Deployment target **macOS 14.0**; product **Markout**; bundle id **tech.ankey.Markout**.
- **Do not break P1–P3 signatures or tests.** New behavior is additive; the P1 `SyntaxHighlighter.apply(to:baseFont:textColor:)` stays as a shim.
- Settings live in one place (`SettingsKeys`); `@AppStorage` is the interface. Unknown persisted theme ids fall back to defaults.
- Pure logic is unit-tested; Settings window / toolbar / status bar are verified by the manual checklist.
- Tests use **Swift Testing**. Commit after every task with Conventional Commits.

---

## File Structure (P4 delta)

```
Sources/Markout/
├─ Settings/{SettingsKeys.swift NEW, SettingsView.swift NEW,
│            EditorTheme.swift NEW, DocumentStats.swift NEW}
├─ Editor/{SyntaxHighlighter.swift EDIT, MarkdownFormatter.swift NEW,
│          MarkdownTextView.swift EDIT, EditorView.swift EDIT}
└─ App/{MarkoutApp.swift EDIT, ContentView.swift EDIT}
Tests/MarkoutTests/{DocumentStatsTests, MarkdownFormatterTests,
                    EditorThemeStoreTests, ThemedHighlighterTests}.swift NEW
```

---

## Task 1: DocumentStats (pure)

**Files:**
- Create: `Sources/Markout/Settings/DocumentStats.swift`
- Test: `Tests/MarkoutTests/DocumentStatsTests.swift`

**Interfaces:**
- Produces: `struct DocumentStats: Equatable { let words, characters, lines, readingMinutes: Int }`
- Produces: `extension DocumentStats { static func compute(_ text: String) -> DocumentStats }`

- [ ] **Step 1: Write failing tests `Tests/MarkoutTests/DocumentStatsTests.swift`**

```swift
import Testing
@testable import Markout

struct DocumentStatsTests {
    @Test func countsWordsAndChars() {
        let s = DocumentStats.compute("hello world")
        #expect(s.words == 2)
        #expect(s.characters == 11)
    }

    @Test func countsLines() {
        #expect(DocumentStats.compute("a\nb\nc").lines == 3)
    }

    @Test func emptyIsAllZero() {
        #expect(DocumentStats.compute("") == DocumentStats(words: 0, characters: 0, lines: 0, readingMinutes: 0))
    }

    @Test func whitespaceOnlyHasNoWords() {
        #expect(DocumentStats.compute("   \n  ").words == 0)
    }

    @Test func readingTimeRoundsUp() {
        let text = Array(repeating: "word", count: 250).joined(separator: " ")
        #expect(DocumentStats.compute(text).readingMinutes == 2) // ceil(250/200)
    }

    @Test func unicodeWordsCounted() {
        #expect(DocumentStats.compute("héllo 世界 🌍").words == 3)
    }
}
```

- [ ] **Step 2: Run to verify failure.**

```bash
cd /Users/maxmilian/side/markout && xcodegen generate
xcodebuild test -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' \
  -only-testing:MarkoutTests/DocumentStatsTests 2>&1 | tail -20
```

- [ ] **Step 3: Implement.** Words: `text.split(whereSeparator: {$0.isWhitespace})` count. Characters: `text.count`. Lines: `0` if empty else `text.split(separator:"\n", omittingEmptySubsequences:false).count`. Reading minutes: `words == 0 ? 0 : Int(ceil(Double(words)/200))`. Pure.

- [ ] **Step 4: Run tests to verify pass** (6 tests).

- [ ] **Step 5: Commit** — `feat: add pure DocumentStats word/char/line counter`

---

## Task 2: MarkdownFormatter (pure selection transforms)

**Files:**
- Create: `Sources/Markout/Editor/MarkdownFormatter.swift`
- Test: `Tests/MarkoutTests/MarkdownFormatterTests.swift`

**Interfaces:**
- Produces: `struct FormatResult: Equatable { let text: String; let selection: NSRange }`
- Produces: `enum MarkdownFormatter` with `toggleBold`, `toggleItalic`, `toggleInlineCode`, `setHeading(_:level:selection:)`, `toggleBlockquote`, `toggleList`, `makeLink(_:url:selection:)` — each `(text: String, selection: NSRange) -> FormatResult`.

- [ ] **Step 1: Write failing tests `Tests/MarkoutTests/MarkdownFormatterTests.swift`**

```swift
import Testing
import Foundation
@testable import Markout

struct MarkdownFormatterTests {
    private func sel(_ s: String, _ loc: Int, _ len: Int) -> NSRange { NSRange(location: loc, length: len) }

    @Test func boldWrapsSelection() {
        let r = MarkdownFormatter.toggleBold(text: "hello", selection: sel("hello", 0, 5))
        #expect(r.text == "**hello**")
    }

    @Test func boldUnwrapsWhenAlreadyBold() {
        let r = MarkdownFormatter.toggleBold(text: "**hello**", selection: sel("**hello**", 0, 9))
        #expect(r.text == "hello")
    }

    @Test func italicWraps() {
        let r = MarkdownFormatter.toggleItalic(text: "x", selection: sel("x", 0, 1))
        #expect(r.text == "*x*")
    }

    @Test func inlineCodeWraps() {
        let r = MarkdownFormatter.toggleInlineCode(text: "x", selection: sel("x", 0, 1))
        #expect(r.text == "`x`")
    }

    @Test func setHeadingAddsPrefix() {
        let r = MarkdownFormatter.setHeading(text: "Title", level: 2, selection: sel("Title", 0, 0))
        #expect(r.text == "## Title")
    }

    @Test func setHeadingReplacesExistingPrefix() {
        let r = MarkdownFormatter.setHeading(text: "# Title", level: 3, selection: sel("# Title", 0, 0))
        #expect(r.text == "### Title")
    }

    @Test func toggleListPrefixesLine() {
        let r = MarkdownFormatter.toggleList(text: "item", selection: sel("item", 0, 0))
        #expect(r.text == "- item")
    }

    @Test func toggleBlockquotePrefixesLine() {
        let r = MarkdownFormatter.toggleBlockquote(text: "quote", selection: sel("quote", 0, 0))
        #expect(r.text == "> quote")
    }

    @Test func makeLinkWrapsSelection() {
        let r = MarkdownFormatter.makeLink(text: "site", url: "https://x.com", selection: sel("site", 0, 4))
        #expect(r.text == "[site](https://x.com)")
    }

    @Test func makeLinkWithEmptySelectionInsertsTemplate() {
        let r = MarkdownFormatter.makeLink(text: "", url: "https://x.com", selection: sel("", 0, 0))
        #expect(r.text == "[](https://x.com)")
    }
}
```

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement.** For wrap toggles: extract the selected substring; if it (or the surrounding chars) already carries the marker, remove it; else wrap. Adjust the returned `selection` to keep the same visible text selected. For line-prefix ops (heading/quote/list): operate on the line(s) intersecting the selection; heading strips an existing `#+ ` before applying. `makeLink` wraps or inserts `[](url)`. Keep everything pure and total; document boundary/empty-selection behavior.

- [ ] **Step 4: Run tests to verify pass** (10 tests).

- [ ] **Step 5: Commit** — `feat: add pure MarkdownFormatter selection transforms`

---

## Task 3: EditorTheme + EditorThemeStore

**Files:**
- Create: `Sources/Markout/Settings/EditorTheme.swift`
- Test: `Tests/MarkoutTests/EditorThemeStoreTests.swift`

**Interfaces:**
- Produces: `struct EditorTheme: Identifiable, Hashable { id, name, background, foreground, caret, selection, colors: [MarkdownToken: NSColor] }`
- Produces: `enum EditorThemeStore { static var all: [EditorTheme]; static func theme(id: String) -> EditorTheme? }`

- [ ] **Step 1: Write failing tests `Tests/MarkoutTests/EditorThemeStoreTests.swift`**

```swift
import Testing
import AppKit
@testable import Markout

struct EditorThemeStoreTests {
    @Test func hasDefaultTheme() {
        #expect(EditorThemeStore.theme(id: "markout-light") != nil)
    }

    @Test func unknownIdIsNil() {
        #expect(EditorThemeStore.theme(id: "nope") == nil)
    }

    @Test func everyThemeCoversAllTokens() {
        let allTokens: [MarkdownToken] = [.heading, .emphasis, .strong, .inlineCode, .codeBlock, .link, .blockquote, .listMarker]
        for theme in EditorThemeStore.all {
            for token in allTokens {
                #expect(theme.colors[token] != nil, "\(theme.id) missing \(token)")
            }
        }
    }

    @Test func providesAtLeastLightAndDark() {
        let ids = Set(EditorThemeStore.all.map(\.id))
        #expect(ids.contains("markout-light"))
        #expect(ids.contains("markout-dark"))
    }
}
```

Note: `MarkdownToken` must be `Hashable` for `[MarkdownToken: NSColor]` — add `Hashable` conformance to the P1 enum (additive, non-breaking) in this task.

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement.** Make `MarkdownToken: Hashable`. Define `markout-light`, `markout-dark`, `solarized-light`, `dracula` as static `EditorTheme` data, each with a color for **every** token case plus background/foreground/caret/selection. `all` lists them; `theme(id:)` searches `all`.

- [ ] **Step 4: Run tests to verify pass** (4 tests).

- [ ] **Step 5: Commit** — `feat: add editor color themes and theme store`

---

## Task 4: Theme-aware SyntaxHighlighter

**Files:**
- Modify: `Sources/Markout/Editor/SyntaxHighlighter.swift`
- Test: `Tests/MarkoutTests/ThemedHighlighterTests.swift`

**Interfaces:**
- Produces: `static func apply(to textStorage: NSTextStorage, baseFont: NSFont, theme: EditorTheme)`; keep P1 `apply(to:baseFont:textColor:)` as a shim delegating with `markout-light`.

- [ ] **Step 1: Write failing tests `Tests/MarkoutTests/ThemedHighlighterTests.swift`**

```swift
import Testing
import AppKit
@testable import Markout

struct ThemedHighlighterTests {
    @Test func headingUsesThemeColor() {
        let theme = EditorThemeStore.theme(id: "markout-dark")!
        let storage = NSTextStorage(string: "# Title")
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        SyntaxHighlighter.apply(to: storage, baseFont: font, theme: theme)
        var found = false
        storage.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: storage.length)) { value, _, _ in
            if let c = value as? NSColor, c == theme.colors[.heading] { found = true }
        }
        #expect(found)
    }

    @Test func baseTextUsesThemeForeground() {
        let theme = EditorThemeStore.theme(id: "markout-light")!
        let storage = NSTextStorage(string: "plain")
        SyntaxHighlighter.apply(to: storage, baseFont: .monospacedSystemFont(ofSize: 13, weight: .regular), theme: theme)
        let c = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(c == theme.foreground)
    }
}
```

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement.** Add the themed `apply`: set the whole range to `[.font: baseFont, .foregroundColor: theme.foreground]`, then for each token apply `theme.colors[token]` (and the existing bold/italic font traits for strong/emphasis, larger bold font for headings). Reimplement P1 `apply(to:baseFont:textColor:)` to build a temporary theme from `textColor` (or delegate to `markout-light`) so P1 `SyntaxHighlighterTests` stay green.

- [ ] **Step 4: Run the highlighter suite** — P1 `SyntaxHighlighterTests` + `ThemedHighlighterTests` pass.

```bash
xcodebuild test -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' \
  -only-testing:MarkoutTests/SyntaxHighlighterTests -only-testing:MarkoutTests/ThemedHighlighterTests 2>&1 | tail -20
```

- [ ] **Step 5: Commit** — `feat: make SyntaxHighlighter theme-aware`

---

## Task 5: SettingsKeys + editor plumbing (font/theme/wrap)

**Files:**
- Create: `Sources/Markout/Settings/SettingsKeys.swift`
- Modify: `Sources/Markout/Editor/MarkdownTextView.swift`, `Sources/Markout/Editor/EditorView.swift`

- [ ] **Step 1: SettingsKeys.** Define an `enum SettingsKey { static let editorFontSize = "editorFontSize"; ... }` and default constants for `editorFontSize` (13), `editorThemeID` ("markout-light"), `previewThemeID` ("github", P2), `showWordCount` (true), `softWrap` (true), `showLineNumbers` (false).

- [ ] **Step 2: MarkdownTextView.** Accept font size and an `EditorTheme`; apply `theme.background` (`backgroundColor`/`drawsBackground`), `theme.caret` (`insertionPointColor`), and `theme.selection` (`selectedTextAttributes`). Honor `softWrap` (container width tracking vs horizontal scroll).

- [ ] **Step 3: EditorView.** Add `fontSize: Double`, `theme: EditorTheme`, `softWrap: Bool` inputs; pass into the factory; call the themed `SyntaxHighlighter.apply(to:baseFont:theme:)` on rehighlight. Expose the current selection (binding/closure) so the toolbar can format it.

- [ ] **Step 4: Build to verify it compiles.**

```bash
cd /Users/maxmilian/side/markout && xcodegen generate
xcodebuild build -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' 2>&1 | tail -15
```

- [ ] **Step 5: Commit** — `feat: drive editor font, theme, and wrap from settings`

---

## Task 6: SettingsView (Preferences scene)

**Files:**
- Create: `Sources/Markout/Settings/SettingsView.swift`
- Modify: `Sources/Markout/App/MarkoutApp.swift`

- [ ] **Step 1: SettingsView.** A `TabView` with three tabs bound to `@AppStorage`:
  - **Editor:** font-size `Slider`/`Stepper`, editor-theme `Picker` over `EditorThemeStore.all`, `softWrap` toggle, `showLineNumbers` toggle.
  - **Preview:** preview-theme `Picker` over `PreviewThemeStore.bundled` (P2), "Choose custom CSS…" button calling `PreviewThemeStore.custom(fromFileURL:)` via `NSOpenPanel`.
  - **General:** `showWordCount` toggle; app version/credits.

- [ ] **Step 2: MarkoutApp.** Add a `Settings { SettingsView() }` scene (gives ⌘,). Add a **Format** command menu (bold `⌘B`, italic `⌘I`, link `⌘K`, headings) delegating to `MarkdownFormatter` on the focused editor.

- [ ] **Step 3: Build to verify Preferences opens.**

```bash
cd /Users/maxmilian/side/markout && xcodegen generate
xcodebuild build -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' 2>&1 | tail -15
```

- [ ] **Step 4: Commit** — `feat: add Preferences window and Format command menu`

---

## Task 7: Toolbar + status bar wiring + acceptance

**Files:**
- Modify: `Sources/Markout/App/ContentView.swift`

- [ ] **Step 1: Settings-driven props.** Read `@AppStorage` for font size, editor theme id (→ `EditorThemeStore.theme(id:) ?? markout-light`), preview theme id, `showWordCount`, `softWrap`; pass to `EditorView`/`PreviewView`.

- [ ] **Step 2: Formatting toolbar.** Add a `.toolbar` with bold/italic/code/heading/quote/list/link buttons; each applies the matching `MarkdownFormatter` transform to the editor's current selection and writes back the `FormatResult` (undoable), updating `document.text` and selection.

- [ ] **Step 3: Status bar footer.** When `showWordCount`, show a slim footer under the editor with `DocumentStats.compute(document.text)` (e.g. "1,204 words · 6,530 chars · ~7 min"), updated on the existing debounce.

- [ ] **Step 4: Build, generate, launch.**

```bash
cd /Users/maxmilian/side/markout && xcodegen generate
xcodebuild build -project Markout.xcodeproj -scheme Markout \
  -destination 'platform=macOS' -derivedDataPath .build/dd 2>&1 | tail -15
open .build/dd/Build/Products/Debug/Markout.app
```

- [ ] **Step 5: Run the full test suite** — all P1–P4 tests pass.

```bash
xcodebuild test -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' 2>&1 | tail -25
```

- [ ] **Step 6: Manual acceptance checklist (in the launched app)**

1. `⌘,` opens Preferences with Editor / Preview / General tabs.
2. Editor font size changes live and persists across relaunch.
3. Editor theme recolors text, background, caret, selection; persists.
4. Preview theme picker restyles the preview (shared with P2).
5. Footer word/char count is accurate and live; hiding it via Preferences removes it.
6. Toolbar bold/italic/code wrap and unwrap; `⌘B`/`⌘I`/`⌘K` match; all undoable.
7. Heading/quote/list actions modify the current line(s) correctly.
8. Corrupt/unknown saved theme id falls back to default without crashing.

- [ ] **Step 7: Commit** — `feat: wire formatting toolbar and word-count status bar`

---

## Self-Review Notes

- **Spec coverage:** Settings keys (§4.1) → Task 5; EditorTheme/Store (§4.2) → Task 3; themed SyntaxHighlighter (§4.3) → Task 4; DocumentStats (§4.4) → Task 1; MarkdownFormatter (§4.5) → Task 2; FormattingToolbar (§4.6) → Task 7; status bar (§4.7) → Task 7; SettingsView (§4.8) → Task 6. Error handling (§5): `@AppStorage` defaults + theme fallback (Tasks 3/5/7), total formatter/stats functions (Tasks 1/2), custom-CSS nil (Task 6). Testing (§6): pure unit tests Tasks 1–4; manual checklist Task 7. All covered.
- **Backward compatibility:** additive. P1 `MarkdownToken` gains `Hashable`; P1 `SyntaxHighlighter.apply(to:baseFont:textColor:)` preserved as a shim so P1 tests stay green.
- **Known risks:** (a) formatter unwrap/idempotency edge cases (nested/partial selection) — covered by Task 2 tests; document boundary behavior. (b) reaching the focused editor's selection from menu/toolbar (`FocusedValue` / shared controller) verified in Tasks 6–7. (c) live `@AppStorage` propagation to `NSViewRepresentable` verified in Task 7 manual checks.

---

## Roadmap complete

With P4 shipped, the four-phase roadmap in `README.md` is fully specified and planned. Post-roadmap ideas (plugins, presentation mode, sync, custom keybindings) are noted in the P4 spec §8 and intentionally left unscheduled.
