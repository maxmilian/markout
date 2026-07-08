# Markout P3 Output & Editing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add HTML/PDF export, a table of contents, YAML front-matter stripping, image paste/drag-drop, find & replace, and automatic list continuation on top of the P1/P2 editor.

**Architecture:** Pure builders for everything that can be pure — `FrontMatter.split`, `TableOfContents`, `HTMLExporter.standaloneHTML`, `AssetStore` naming, `ListContinuation.onReturn` — with thin AppKit/WebKit edges (`PDFExporter` via `WKWebView.createPDF`, `ImagePasteHandler`, the find bar, `insertNewline` override). Front matter is split off before the P2 render pipeline; exports reuse the already-rendered preview HTML so output is WYSIWYG.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit (`NSTextView`, `NSTextFinder`), WebKit (`createPDF`); P1/P2 render pipeline; XcodeGen; Swift Testing.

## Global Constraints

- Deployment target **macOS 14.0**; product **Markout**; bundle id **tech.ankey.Markout**.
- **Do not break P1/P2 signatures or tests.** New behavior is additive.
- Exports must be **offline and WYSIWYG**: reuse the live preview's rendered HTML and the active `PreviewTheme` CSS; inline assets so an exported file needs no network.
- Front matter is split **before** `MathExtractor.extract` so the render pipeline never sees it.
- Pure logic is unit-tested; AppKit/WebKit edges (PDF, paste/drop, find bar, menus) are verified by the manual checklist.
- Tests use **Swift Testing**. Commit after every task with Conventional Commits.

---

## File Structure (P3 delta)

```
Sources/Markout/
├─ Document/{FrontMatter.swift NEW, AssetStore.swift NEW}
├─ Render/{TableOfContents.swift NEW, HTMLExporter.swift NEW}
├─ Export/PDFExporter.swift NEW
├─ Editor/{ListContinuation.swift NEW, ImagePasteHandler.swift NEW,
│          MarkdownTextView.swift EDIT}
└─ App/{ContentView.swift EDIT, MarkoutApp.swift EDIT}
Tests/MarkoutTests/{FrontMatterTests, TableOfContentsTests, HTMLExporterTests,
                    AssetStoreTests, ListContinuationTests}.swift NEW
```

---

## Task 1: FrontMatter (parse + strip)

**Files:**
- Create: `Sources/Markout/Document/FrontMatter.swift`
- Test: `Tests/MarkoutTests/FrontMatterTests.swift`

**Interfaces:**
- Produces: `struct FrontMatter { let raw: String; let values: [String: String] }`
- Produces: `enum FrontMatterParser { static func split(_ text: String) -> (front: FrontMatter?, body: String) }`

- [ ] **Step 1: Write failing tests `Tests/MarkoutTests/FrontMatterTests.swift`**

```swift
import Testing
@testable import Markout

struct FrontMatterTests {
    @Test func splitsValidBlock() {
        let doc = "---\ntitle: Hello\nauthor: Max\n---\n# Body"
        let (front, body) = FrontMatterParser.split(doc)
        #expect(front?.values["title"] == "Hello")
        #expect(front?.values["author"] == "Max")
        #expect(body == "# Body")
    }

    @Test func closingWithDotsAlsoWorks() {
        let (front, body) = FrontMatterParser.split("---\nk: v\n...\nbody")
        #expect(front?.values["k"] == "v")
        #expect(body == "body")
    }

    @Test func noBlockWhenNotAtTop() {
        let doc = "intro\n---\nk: v\n---\n"
        let (front, body) = FrontMatterParser.split(doc)
        #expect(front == nil)
        #expect(body == doc)
    }

    @Test func unterminatedIsTreatedAsBody() {
        let doc = "---\nk: v\nno close"
        let (front, body) = FrontMatterParser.split(doc)
        #expect(front == nil)
        #expect(body == doc)
    }

    @Test func absentFrontMatterReturnsWholeBody() {
        let (front, body) = FrontMatterParser.split("# Just markdown")
        #expect(front == nil)
        #expect(body == "# Just markdown")
    }
}
```

- [ ] **Step 2: Run to verify failure.**

```bash
cd /Users/maxmilian/side/markout && xcodegen generate
xcodebuild test -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' \
  -only-testing:MarkoutTests/FrontMatterTests 2>&1 | tail -20
```

- [ ] **Step 3: Implement.** Require the first line to be exactly `---`. Scan subsequent lines for a closing `---` or `...`; if none, return `(nil, text)`. Between them, parse `key: value` (split on first `:`, trim) into `values`; keep the whole inner text as `raw`. `body` = text after the closing line with one leading newline trimmed. Pure, no throws.

- [ ] **Step 4: Run tests to verify pass** (5 tests).

- [ ] **Step 5: Commit** — `feat: add YAML front matter parser`

---

## Task 2: TableOfContents (headings + slugs)

**Files:**
- Create: `Sources/Markout/Render/TableOfContents.swift`
- Test: `Tests/MarkoutTests/TableOfContentsTests.swift`

**Interfaces:**
- Produces: `struct Heading: Equatable { let level: Int; let text: String; let slug: String }`
- Produces: `enum TableOfContents { static func headings(in markdown: String) -> [Heading]; static func markdownList(_ headings: [Heading]) -> String }`

- [ ] **Step 1: Write failing tests `Tests/MarkoutTests/TableOfContentsTests.swift`**

```swift
import Testing
@testable import Markout

struct TableOfContentsTests {
    @Test func extractsHeadingsWithLevels() {
        let h = TableOfContents.headings(in: "# A\n## B\n### C")
        #expect(h.map(\.level) == [1, 2, 3])
        #expect(h.map(\.text) == ["A", "B", "C"])
    }

    @Test func skipsHeadingsInsideCodeFence() {
        let h = TableOfContents.headings(in: "# Real\n```\n# Fake\n```")
        #expect(h.map(\.text) == ["Real"])
    }

    @Test func slugsMatchGitHubRules() {
        let h = TableOfContents.headings(in: "# Hello, World!")
        #expect(h[0].slug == "hello-world")
    }

    @Test func deduplicatesSlugs() {
        let h = TableOfContents.headings(in: "# Dup\n# Dup")
        #expect(h[0].slug == "dup")
        #expect(h[1].slug == "dup-1")
    }

    @Test func buildsNestedMarkdownList() {
        let list = TableOfContents.markdownList([
            Heading(level: 1, text: "A", slug: "a"),
            Heading(level: 2, text: "B", slug: "b"),
        ])
        #expect(list.contains("- [A](#a)"))
        #expect(list.contains("  - [B](#b)"))
    }
}
```

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement.** Scan lines, track fenced-code state, match `^(#{1,6})\s+(.*)$`. Strip trailing `#` and inline markup from display text. Slug: lowercase, remove chars that aren't word/space/hyphen, spaces→`-`, collapse repeats; keep a seen-count map appending `-N` for duplicates (GitHub scheme). `markdownList` indents two spaces per level above the minimum present.

- [ ] **Step 4: Run tests to verify pass** (5 tests). If a slug edge case differs from cmark, align the slug rule to cmark's output (not the reverse) for real anchor resolution.

- [ ] **Step 5: Commit** — `feat: add table-of-contents heading extraction with GitHub slugs`

---

## Task 3: HTMLExporter (standalone HTML)

**Files:**
- Create: `Sources/Markout/Render/HTMLExporter.swift`
- Test: `Tests/MarkoutTests/HTMLExporterTests.swift`

**Interfaces:**
- Produces: `enum HTMLExporter { static func standaloneHTML(body: String, css: String, title: String) -> String }`

- [ ] **Step 1: Write failing tests `Tests/MarkoutTests/HTMLExporterTests.swift`**

```swift
import Testing
@testable import Markout

struct HTMLExporterTests {
    @Test func includesTitleCSSAndBody() {
        let out = HTMLExporter.standaloneHTML(
            body: "<h1>Hi</h1>", css: "body{color:red}", title: "My Doc")
        #expect(out.contains("<title>My Doc</title>"))
        #expect(out.contains("body{color:red}"))
        #expect(out.contains("<h1>Hi</h1>"))
        #expect(out.contains("id=\"content\""))
        #expect(out.hasPrefix("<!DOCTYPE html>"))
    }

    @Test func escapesTitle() {
        let out = HTMLExporter.standaloneHTML(body: "", css: "", title: "a<b>&c")
        #expect(!out.contains("<title>a<b>&c</title>"))
        #expect(out.contains("a&lt;b&gt;&amp;c"))
    }
}
```

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement.** Return a full document: doctype, `<head>` with `<meta charset>`, escaped `<title>`, `<style>\(css)</style>`, and `<body><div id="content">\(body)</div></body>`. Pure. (Task 8 supplies `css` = active `PreviewTheme.css` + highlight/KaTeX CSS, and `body` = the already-rendered preview HTML with math/diagrams inlined.)

- [ ] **Step 4: Run tests to verify pass** (2 tests).

- [ ] **Step 5: Commit** — `feat: add standalone HTML exporter`

---

## Task 4: AssetStore (image naming/save)

**Files:**
- Create: `Sources/Markout/Document/AssetStore.swift`
- Test: `Tests/MarkoutTests/AssetStoreTests.swift`

**Interfaces:**
- Produces (pure, testable): `static func uniqueName(base: String, ext: String, existing: Set<String>) -> String`
- Produces (thin): `static func save(_ image: NSImage, forDocumentAt docURL: URL?, preferredName: String?) throws -> String`

- [ ] **Step 1: Write failing tests `Tests/MarkoutTests/AssetStoreTests.swift`**

```swift
import Testing
@testable import Markout

struct AssetStoreTests {
    @Test func firstNameIsUnchanged() {
        #expect(AssetStore.uniqueName(base: "image", ext: "png", existing: []) == "image.png")
    }

    @Test func appendsCounterOnCollision() {
        let taken: Set<String> = ["image.png", "image-1.png"]
        #expect(AssetStore.uniqueName(base: "image", ext: "png", existing: taken) == "image-2.png")
    }

    @Test func sanitizesBaseName() {
        let name = AssetStore.uniqueName(base: "My Photo!", ext: "png", existing: [])
        #expect(!name.contains(" "))
        #expect(!name.contains("!"))
    }
}
```

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement.** `uniqueName`: sanitize base (lowercase, non-word→`-`), try `base.ext`, then `base-1.ext`, `base-2.ext`… until not in `existing`. `save`: resolve the `assets/` dir beside `docURL` (create if needed), enumerate existing names, PNG-encode the `NSImage`, write, and return the relative path `assets/<name>`. If `docURL == nil`, write to a temp dir and return an absolute `file:` path (Task 5/8 shows the "save to keep images" notice). Only `uniqueName` is unit-tested.

- [ ] **Step 4: Run tests to verify pass** (3 tests).

- [ ] **Step 5: Commit** — `feat: add AssetStore with collision-safe image naming`

---

## Task 5: ListContinuation (return-key logic)

**Files:**
- Create: `Sources/Markout/Editor/ListContinuation.swift`
- Test: `Tests/MarkoutTests/ListContinuationTests.swift`

**Interfaces:**
- Produces: `struct ListEdit: Equatable { let insert: String; let removeCurrentMarker: Bool }`
- Produces: `enum ListContinuation { static func onReturn(line: String) -> ListEdit? }`

- [ ] **Step 1: Write failing tests `Tests/MarkoutTests/ListContinuationTests.swift`**

```swift
import Testing
@testable import Markout

struct ListContinuationTests {
    @Test func continuesUnordered() {
        #expect(ListContinuation.onReturn(line: "- item")
            == ListEdit(insert: "\n- ", removeCurrentMarker: false))
    }

    @Test func continuesOrderedIncrementing() {
        #expect(ListContinuation.onReturn(line: "2. item")
            == ListEdit(insert: "\n3. ", removeCurrentMarker: false))
    }

    @Test func continuesTaskListUnchecked() {
        #expect(ListContinuation.onReturn(line: "- [x] done")
            == ListEdit(insert: "\n- [ ] ", removeCurrentMarker: false))
    }

    @Test func emptyItemTerminates() {
        #expect(ListContinuation.onReturn(line: "- ")
            == ListEdit(insert: "", removeCurrentMarker: true))
    }

    @Test func preservesIndentation() {
        #expect(ListContinuation.onReturn(line: "  - item")
            == ListEdit(insert: "\n  - ", removeCurrentMarker: false))
    }

    @Test func nonListReturnsNil() {
        #expect(ListContinuation.onReturn(line: "plain text") == nil)
    }
}
```

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement.** Regex the leading indent + marker (`[-*+]`, optional `[ ]`/`[x]` task box, or `\d+\.`). If the content after the marker is empty → `ListEdit(insert:"", removeCurrentMarker:true)`. Else build the next marker (ordered increments the number; task resets to `[ ]`) and return `"\n" + indent + marker`. Non-list → `nil`. Pure.

- [ ] **Step 4: Run tests to verify pass** (6 tests).

- [ ] **Step 5: Commit** — `feat: add list continuation logic for the return key`

---

## Task 6: PDFExporter + MarkdownTextView editing edges

**Files:**
- Create: `Sources/Markout/Export/PDFExporter.swift`
- Create: `Sources/Markout/Editor/ImagePasteHandler.swift`
- Modify: `Sources/Markout/Editor/MarkdownTextView.swift`

- [ ] **Step 1: PDFExporter.** `static func export(from webView: WKWebView, to url: URL) async throws` → `let data = try await webView.pdf(configuration: .init()); try data.write(to: url)`. (Use the `createPDF` completion API wrapped in `withCheckedThrowingContinuation` if the async variant is unavailable on the SDK.)

- [ ] **Step 2: MarkdownTextView find bar + return override.** In the factory, set `textView.usesFindBar = true`, `isIncrementalSearchingEnabled = true`. Subclass (or delegate) to override `insertNewline(_:)`: read the caret's current line, call `ListContinuation.onReturn`; if non-nil, apply the `ListEdit` via `insertText`/`shouldChangeText` with undo registration; else `super.insertNewline`.

- [ ] **Step 3: ImagePasteHandler.** Override paste (`readSelection(from pboard:)`) and drag (`performDragOperation`) to detect `NSImage`/image file URLs: call `AssetStore.save(...)`, then insert `![](relpath)` at the caret. Register the handler from the factory. Pass the current document URL down (via a closure the `EditorView`/`ContentView` supplies).

- [ ] **Step 4: Build to verify it compiles.**

```bash
cd /Users/maxmilian/side/markout && xcodegen generate
xcodebuild build -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' 2>&1 | tail -15
```

- [ ] **Step 5: Commit** — `feat: add PDF export, find bar, list continuation, and image paste to the editor`

---

## Task 7: MarkoutApp menu commands

**Files:**
- Modify: `Sources/Markout/App/MarkoutApp.swift`

- [ ] **Step 1: Add `.commands { ... }`** to the `DocumentGroup`:
  - `CommandGroup(after: .saveItem)` → **Export → HTML…**, **Export → PDF…** (open `NSSavePanel`, hand off to the exporters — the active document/preview is reached via the focused-scene value or a shared controller).
  - `CommandGroup(after: .textEditing)` → **Insert Table of Contents** (inserts `TableOfContents.markdownList` into `document.text` at the caret).
  - Standard **Find** items come from the text view's finder; add a `View → Show Contents` toggle for the TOC sidebar.
- [ ] **Step 2: Build to verify menus appear.**

```bash
cd /Users/maxmilian/side/markout && xcodegen generate
xcodebuild build -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' 2>&1 | tail -15
```

- [ ] **Step 3: Commit** — `feat: add export, TOC, and find menu commands`

---

## Task 8: ContentView wiring (front matter, TOC, exports) + acceptance

**Files:**
- Modify: `Sources/Markout/App/ContentView.swift`

- [ ] **Step 1: Front-matter split before render.** In the debounce pipeline, run `FrontMatterParser.split(document.text)` first and feed `body` (not the raw text) into `MathExtractor.extract → renderHTMLBody(options:) → reinsert`. Keep the front matter available for export titles.

- [ ] **Step 2: TOC sidebar (optional pane).** Compute `TableOfContents.headings(in: body)`; behind the `View → Show Contents` toggle, show a clickable list; clicking sets `previewScrollLine`/calls `scrollToSourceLine` to the heading.

- [ ] **Step 3: Export wiring.** Provide the export actions the menu commands invoke:
  - HTML: `HTMLExporter.standaloneHTML(body: renderedHTML, css: activeThemeCSS + assetCSS, title: front?.values["title"] ?? filename)` → write to the chosen URL.
  - PDF: `PDFExporter.export(from: previewWebView, to: url)` — expose the preview's `WKWebView` to the export action (e.g. via a coordinator reference held by `ContentView`).

- [ ] **Step 4: Image URL plumbing.** Pass the document's file URL into `EditorView`/`ImagePasteHandler` so pasted images land in `assets/` beside it; show the "save to keep images" notice when the document is untitled.

- [ ] **Step 5: Build, generate, launch.**

```bash
cd /Users/maxmilian/side/markout && xcodegen generate
xcodebuild build -project Markout.xcodeproj -scheme Markout \
  -destination 'platform=macOS' -derivedDataPath .build/dd 2>&1 | tail -15
open .build/dd/Build/Products/Debug/Markout.app
```

- [ ] **Step 6: Run the full test suite** — all P1 + P2 + P3 tests pass.

```bash
xcodebuild test -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' 2>&1 | tail -25
```

- [ ] **Step 7: Manual acceptance checklist (in the launched app)**

1. Export → HTML opens in a browser and renders identically offline (code colored, math + Mermaid present).
2. Export → PDF matches the on-screen preview, including math and a diagram.
3. A leading `---` YAML block is hidden from the preview; body renders normally.
4. Insert Table of Contents adds a nested link list; clicking a preview link jumps to the heading.
5. Paste an image → saved beside the document, `![](assets/…)` inserted and rendered.
6. Drag an image file into the editor → same result.
7. `⌘F` find bar; `⌘⌥F` replace; both work.
8. `- ` list continues on Return; empty item terminates; ordered `1.` and task `- [ ]` behave correctly.

- [ ] **Step 8: Commit** — `feat: wire front matter, TOC sidebar, and HTML/PDF export into the app`

---

## Self-Review Notes

- **Spec coverage:** FrontMatter (§4.1) → Task 1; TableOfContents (§4.2) → Task 2; HTMLExporter (§4.3) → Task 3; AssetStore (§4.5) → Task 4; ListContinuation (§4.6) → Task 5; PDFExporter (§4.4) + find bar (§4.7) + image paste (§4.5) → Task 6; commands (§4.8) → Task 7; ContentView wiring → Task 8. Error handling (§5): front-matter fallback (Task 1), export write flow (Tasks 3/6/8), asset failure/unsaved-doc (Tasks 4/8), list-continuation nil (Task 5). Testing (§6): pure unit tests Tasks 1–5; manual checklist Task 8. All covered.
- **Backward compatibility:** additive only; P1/P2 signatures and tests untouched. Front-matter split changes *what* is fed to the render pipeline, not the pipeline's API.
- **Known risks:** (a) cmark heading-id/slug scheme must match `TableOfContents` slugs for anchors — verified by Task 2 tests against cmark output. (b) `WKWebView.pdf(configuration:)` availability/async shape varies by SDK — Task 6 wraps the completion API if needed. (c) reaching the focused document/preview from menu commands (`FocusedValue`/shared controller) is verified in Tasks 7–8. (d) exported offline HTML must inline highlight/KaTeX CSS and already-rendered SVG — handled in Task 8's `css`/`body` composition.
