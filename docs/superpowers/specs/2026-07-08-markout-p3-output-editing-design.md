# Markout — P3 Output & Editing Design

**Date:** 2026-07-08
**Status:** Approved (design phase)
**Scope:** Phase 3 of the phased effort to build a modern, native macOS Markdown editor (successor to MacDown). Builds on the shipped P1 Core MVP and P2 Rich Content.

---

## 1. Goal

Turn Markout from a viewer into a productive authoring tool. P3 adds **output** (export the rendered document to standalone HTML and to PDF), **navigation** (a table of contents), **metadata** (YAML front matter that is parsed and hidden from the render), and **editing quality-of-life** (paste/drag images into the document, find & replace, and automatic list continuation).

**Builds on P1 + P2 (already shipped):**
- Render pipeline: `MathExtractor.extract` → `MarkdownRenderer.renderHTMLBody(_, options:)` → `MathExtractor.reinsert` → `PreviewInjection.setContent` in `WKWebView`.
- `HTMLTemplate.page(theme:previewCSS:)` with bundled highlight.js / KaTeX / Mermaid and an `afterRender()` hook.
- `PreviewTheme` / `PreviewThemeStore`; editor↔preview `ScrollSync`.
- `EditorView` / `MarkdownTextView` (`NSTextView`, TextKit 2); `MarkdownDocument` (`FileDocument`).

**Out of scope for P3** (deferred to P4):
- Preferences window, editor color themes, live word count, formatting toolbar.

## 2. Technology Choices

| Concern | Choice | Rationale |
|---------|--------|-----------|
| HTML export | Reuse `HTMLTemplate` + render pipeline, inline CSS/assets | A self-contained `.html` file that renders identically offline. Pure `String` builder, fully testable |
| PDF export | `WKWebView.createPDF(configuration:)` (macOS 11+) | Renders the *actual* preview (code/math/diagrams included) to PDF — no second rendering path to keep in sync |
| TOC | Pure heading extractor → Markdown/HTML list with slug anchors | Deterministic, testable; anchors match cmark's heading id scheme so links work in preview and exports |
| Front matter | Hand-rolled leading-`---` block splitter (no YAML lib for P3) | Only need to *strip* front matter from the render and expose raw key/values; a full YAML dependency is unwarranted. Pure, testable |
| Image paste/drag | `NSTextView` paste/drop → copy into a sidecar assets folder → insert `![](relpath)` | Native macOS gesture; keeps images with the document; requires the document's URL |
| Find & replace | `NSTextView` built-in find bar (`usesFindBar`, `performTextFinderAction:`) | System-standard UX, ⌘F/⌘⌥F, near-free, matches every other macOS text app |
| List continuation | Pure "given the current line + Return, compute the edit" function | Testable core; the `NSTextView` `insertNewline` override is a thin call into it |

## 3. Architecture

```
Editing side (NSTextView / document):
  document.text
    ├─ FrontMatter.split(text) → (frontMatter?, body)   [NEW, pure]
    │     body feeds the P2 render pipeline; frontMatter hidden from preview
    ├─ ListContinuation.edit(forLine:, at:) [NEW, pure] ← insertNewline override
    ├─ ImagePasteHandler [NEW] ← paste/drop → AssetStore.save(image, nearDocumentURL)
    │     → inserts "![alt](assets/name.png)"
    └─ NSTextView find bar (config only)

Output side (pure builders + one WebView call):
  body → [P2 pipeline] → htmlBody
    ├─ HTMLExporter.standaloneHTML(body:, css:, title:) [NEW, pure]
    │     → full self-contained .html string
    ├─ PDFExporter.export(webView:, to:) [NEW, thin] uses WKWebView.createPDF
    └─ TableOfContents.headings(in: body-markdown) [NEW, pure]
          → [Heading(level,text,slug)] → markdown/html list; slugs match cmark ids

Navigation:
  TableOfContents → sidebar list (click → preview.scrollToSourceLine / anchor)
                  → or "Insert TOC" command writing a Markdown list into the document
```

### Where each piece plugs into the existing flow

- **Front matter** runs first, before `MathExtractor.extract`, so the rest of the P2 pipeline never sees the `---` block. The parsed metadata is available to exports (e.g. `title`).
- **Exports** consume the *same* rendered `htmlBody` the preview already computes, guaranteeing WYSIWYG output.
- **Editing helpers** live on the `NSTextView` side and never touch the render pipeline except by mutating `document.text` (which already triggers a debounced re-render from P1).

## 4. Component Specifications

### 4.1 FrontMatter (new, pure)
- `struct FrontMatter { let raw: String; let values: [String: String] }`
- `enum FrontMatter { static func split(_ text: String) -> (front: FrontMatter?, body: String) }`
  - Recognizes a front-matter block **only** when the document begins with a line that is exactly `---`, terminated by a later line that is exactly `---` (or `...`). Otherwise `front` is `nil` and `body == text`.
  - Parses simple `key: value` lines into `values` (leaf scalars only; nested YAML is preserved in `raw` but not deep-parsed — documented limitation for P3).
  - `body` is everything after the closing delimiter (leading blank line trimmed). Pure, never throws.

### 4.2 TableOfContents (new, pure)
- `struct Heading { let level: Int; let text: String; let slug: String }`
- `enum TableOfContents`:
  - `static func headings(in markdown: String) -> [Heading]` — scans ATX headings `#…######` outside fenced code, strips inline Markdown from the display `text`, and computes `slug` with the **same** rules cmark/GitHub use (lowercase, spaces→`-`, drop non-word chars, de-duplicate with `-1`, `-2`). Matching cmark's ids is what makes anchor links resolve.
  - `static func markdownList(_ headings: [Heading]) -> String` — nested bullet list of `[text](#slug)` indented by level.
- Enables both a clickable sidebar and an "Insert Table of Contents" document command.

### 4.3 HTMLExporter (new, pure)
- `enum HTMLExporter { static func standaloneHTML(body: String, css: String, title: String) -> String }`
  - Produces a complete, self-contained `.html`: `<head>` with `<title>`, inlined `css` (the active `PreviewTheme` CSS) in a `<style>`, and the rendered `body` inside `#content`.
  - For P3, KaTeX/Mermaid/highlight output is exported **as already-rendered HTML/SVG** where possible; where client-side rendering is required, the exporter inlines the bundled JS/CSS so the file still works offline. (Simplest correct default: inline the theme CSS + highlight CSS and the KaTeX CSS, and inline the SVG Mermaid already produced.)
  - Pure `String` → fully unit-testable.

### 4.4 PDFExporter (new, thin)
- `enum PDFExporter { static func export(from webView: WKWebView, to url: URL) async throws }`
  - Calls `webView.createPDF(configuration:)` on the live preview WebView (so the PDF matches what the user sees, including math and diagrams) and writes the data to `url`.
  - Thin AppKit/WebKit wrapper; not unit-tested. Errors surface via a standard save-panel/alert flow.

### 4.5 AssetStore + ImagePasteHandler (new)
- `enum AssetStore { static func save(_ image: NSImage, forDocumentAt docURL: URL?, preferredName: String?) throws -> String }`
  - Writes the image (PNG) into an `assets/` folder beside the document, returns the **relative** path to embed. If the document is unsaved (`docURL == nil`), falls back to a temporary location and returns an absolute `file:` path, prompting the user to save (documented behavior).
  - Filename de-duplication (`image.png`, `image-1.png`) is the testable core (given an existing-names set).
- `ImagePasteHandler` — hooks `NSTextView` paste (`readSelection(from:)`/`performDragOperation`) and drag-drop of image files/data: calls `AssetStore`, then inserts `![](relpath)` at the caret via the text view. Thin AppKit edge.

### 4.6 ListContinuation (new, pure)
- `struct ListEdit { let insert: String; let replaceRange: NSRange? }`
- `enum ListContinuation { static func onReturn(line: String, indentUnit: String) -> ListEdit? }`
  - Given the text of the line the caret is on when Return is pressed:
    - Unordered (`- `, `* `, `+ `, incl. task `- [ ] `): if the item has content, return `insert = "\n" + marker`; if the item is empty (just the marker), return an edit that **removes** the marker (terminates the list) — `replaceRange` covers the marker.
    - Ordered (`1.`, `2.` …): continue with the next number; empty item terminates.
    - Preserves leading indentation.
  - Returns `nil` when the line is not a list item (normal newline). Pure, testable.
- `MarkdownTextView` overrides `insertNewline(_:)` to consult `ListContinuation` and apply the `ListEdit` (registering undo), else `super`.

### 4.7 Find & Replace (config only)
- Enable the `NSTextView` find bar: `usesFindBar = true`, `isIncrementalSearchingEnabled = true`. Standard `⌘F` (find), `⌘⌥F` (find & replace), `⌘G`/`⌘⇧G` (next/prev) come free from `NSTextFinder`.
- Add matching `Find` menu items in the app's command menus so they're discoverable.

### 4.8 Commands / UI surface
- `File → Export → HTML…` and `File → Export → PDF…` (save panels) — invoke `HTMLExporter` / `PDFExporter`.
- `Edit → Insert Table of Contents` — inserts `TableOfContents.markdownList(...)` at the caret.
- Optional TOC sidebar toggle (`View → Show Contents`) listing headings; clicking scrolls the preview.
- `Find` menu items wired to the text view's finder.

## 5. Error Handling
- **Front matter:** malformed/unterminated block → treated as ordinary content (`front == nil`); never corrupts the body. Non-scalar YAML preserved in `raw`, not deep-parsed (documented).
- **HTML export:** pure string build; cannot fail. Write errors handled by the save flow.
- **PDF export:** `createPDF` is async and may throw; surfaced via an alert. No partial file left on failure.
- **Image paste:** `AssetStore.save` throws on write failure (surfaced by alert); unsaved-document case degrades to a temp path with a "save your document to keep images" notice rather than silently losing the image.
- **List continuation:** any unrecognized line yields `nil` → default newline; never blocks typing.

## 6. Testing Strategy
- **Unit (primary, pure Swift):**
  - `FrontMatter`: detects/strips a valid block; ignores `---` that isn't at the very top; parses `key: value`; leaves body intact when absent.
  - `TableOfContents`: heading extraction (levels, skips code fences), slug rules incl. de-duplication, nested markdown list output; slugs match cmark ids for sample docs.
  - `HTMLExporter`: standalone doc contains `<title>`, inlined CSS, and body in `#content`; special characters don't break it.
  - `AssetStore`: filename de-duplication given an existing-names set; relative-path computation.
  - `ListContinuation`: unordered/ordered/task continuation, empty-item termination, indentation preservation, non-list → `nil`.
- **Integration/thin edges (manual):** PDF export, actual paste/drop, find bar, menu commands — covered by the acceptance checklist.
- **Approach:** TDD — failing pure tests first (front matter, TOC, exporter, asset naming, list continuation), then implement to green; wire the thin AppKit/WebKit edges last.

### Manual acceptance checklist
1. `File → Export → HTML…` produces a file that opens in a browser and renders identically (code colored, math/diagrams present) with no network.
2. `File → Export → PDF…` produces a PDF matching the on-screen preview, including math and a Mermaid diagram.
3. A document beginning with a `---` YAML block does **not** show the block in the preview; body renders normally.
4. `Edit → Insert Table of Contents` inserts a nested list of links; clicking a link in the preview jumps to that heading.
5. Paste an image from the clipboard → it's saved beside the document and an `![](assets/…)` link appears and renders.
6. Drag an image file into the editor → same result.
7. `⌘F` opens the find bar; `⌘⌥F` reveals replace; find/replace works.
8. In a `- ` list, pressing Return continues the list; pressing Return on an empty item ends it. Same for `1.` ordered and `- [ ]` tasks.

## 7. Project Layout (additions)
```
Sources/Markout/
├─ Document/
│   ├─ FrontMatter.swift            NEW  parse/strip YAML front matter (pure)
│   └─ AssetStore.swift             NEW  save pasted/dropped images beside doc
├─ Render/
│   ├─ TableOfContents.swift        NEW  headings + slug + markdown list (pure)
│   └─ HTMLExporter.swift           NEW  standalone HTML (pure)
├─ Export/
│   └─ PDFExporter.swift            NEW  WKWebView.createPDF (thin)
├─ Editor/
│   ├─ ListContinuation.swift       NEW  return-key list logic (pure)
│   ├─ MarkdownTextView.swift       EDIT insertNewline override, find bar, image drop
│   └─ ImagePasteHandler.swift      NEW  paste/drop → AssetStore → insert link
└─ App/
    ├─ ContentView.swift            EDIT front-matter split before render, TOC sidebar
    └─ MarkoutApp.swift             EDIT export/TOC/find menu commands
Tests/MarkoutTests/
├─ FrontMatterTests.swift           NEW
├─ TableOfContentsTests.swift       NEW
├─ HTMLExporterTests.swift          NEW
├─ AssetStoreTests.swift            NEW
└─ ListContinuationTests.swift      NEW
```

## 8. Roadmap (context, not P3 work)
- **P1** Core MVP — shipped.
- **P2** Rich content — shipped.
- **P3** Output & editing (this spec).
- **P4** Preferences & polish (settings, editor themes, word count, toolbar).
