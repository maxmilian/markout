# Markout — P1 Core MVP Design

**Date:** 2026-07-08
**Status:** Approved (design phase)
**Scope:** Phase 1 of a phased effort to build a modern, native macOS Markdown editor as the spiritual successor to the unmaintained MacDown. MIT licensed, Apple Silicon first.

---

## 1. Goal

Deliver a Markdown editor that is usable every day: a split window with a live-highlighted editor on the left and a live HTML preview on the right, backed by GitHub Flavored Markdown, with native open/save and dark mode. P1 establishes the architecture that later phases build on.

**Out of scope for P1** (deferred to later phases, tracked in the roadmap):
- P2: code-block syntax highlighting, TeX math (KaTeX), Mermaid diagrams, scroll sync, custom/switchable preview CSS themes.
- P3: export HTML/PDF, TOC, YAML front matter, image paste/drag, find & replace, list continuation.
- P4: preferences window, editor themes, word count, formatting toolbar.

## 2. Technology Choices

| Concern | Choice | Rationale |
|---------|--------|-----------|
| App shell | SwiftUI `DocumentGroup` + `FileDocument` | Native document app: free multi-window, open/save, recent files, `.md` association |
| Editor | `NSTextView` (TextKit 2) via `NSViewRepresentable` | SwiftUI `TextEditor` cannot do syntax highlighting; a real editor requires NSTextView |
| Markdown engine | **cmark-gfm** (C library via SwiftPM wrapper) | Reference GFM implementation, emits HTML directly, built-in table/strikethrough/tasklist/autolink extensions. BSD/MIT-compatible |
| Preview | `WKWebView` | HTML template + default CSS, matches the proven MacDown rendering path |
| Min OS | macOS 14 (Sonoma) | Modern APIs (TextKit 2, Swift Testing), Apple Silicon friendly; still runs on Intel |
| Language / test | Swift 5.9+, Swift Testing | Modern toolchain |

## 3. Architecture

```
Markout (SwiftUI DocumentGroup App)
│
├─ MarkdownDocument            FileDocument holding plain-text .md content
│                              Responsibility: read/write file, UTType(.md), serialization
│
├─ EditorView (NSViewRepresentable)
│   └─ MarkdownTextView        NSTextView + TextKit 2
│      └─ SyntaxHighlighter    text → attributes (heading/bold/italic/link/code…)
│
├─ MarkdownRenderer            cmark-gfm wrapper: String(md) → String(html body)
│                              Pure function, no UI, unit-test target
│
├─ PreviewView (NSViewRepresentable)
│   └─ WKWebView               Loads HTML template, injects body, toggles dark mode
│      └─ HTMLTemplate         Default CSS theme + <body> placeholder
│
└─ ContentView                HSplitView(Editor | Preview); binds document.text,
                              debounces re-render
```

### Data flow (unidirectional)

```
User types → MarkdownTextView updates document.text
          → SyntaxHighlighter applies attributes in-editor (immediate)
          → debounce (~150ms) → MarkdownRenderer produces HTML body
          → PreviewView updates WKWebView by replacing innerHTML via JS
            (not a full reload — avoids flicker and scroll jump)
```

## 4. Component Specifications

### 4.1 MarkdownDocument
- Conforms to `FileDocument`.
- `readableContentTypes` / `writableContentTypes`: `[.markdown]` (UTType, plus `public.plain-text` on read for flexibility).
- Stores a single `String` (`text`). UTF-8 on write. On read, decode UTF-8; if that fails, attempt a lenient decode and, failing that, throw a read error (surfaced by the system sheet).
- No app-specific error UI; rely on `DocumentGroup`'s built-in error handling.

### 4.2 MarkdownRenderer
- Signature: `func renderHTMLBody(_ markdown: String) -> String` — pure, never throws, always returns a String (worst case empty).
- Wraps cmark-gfm with GFM extensions enabled: `table`, `strikethrough`, `autolink`, `tasklist`, `tagfilter`.
- Options: `CMARK_OPT_UNSAFE` **disabled** by default (P1 keeps raw HTML filtered for safety); `CMARK_OPT_SMART` optional.
- Returns only the inner HTML body (no `<html>`/`<head>`), which HTMLTemplate wraps.

### 4.3 HTMLTemplate
- Produces a full HTML document: `<head>` with an embedded default CSS stylesheet (GitHub-like, readable defaults) and a `<body>` containing the rendered body plus a stable container element (e.g. `<div id="content">`).
- Exposes a JS hook so the preview can replace `#content`'s innerHTML without reloading.
- CSS includes a dark-mode variant switched via a `data-theme` attribute or `prefers-color-scheme`, driven by the app's effective appearance.

### 4.4 SyntaxHighlighter
- Input: full text (or changed range). Applies `NSAttributedString` attributes for common Markdown constructs: ATX headings, bold, italic, inline code, fenced code blocks, links, blockquotes, list markers.
- P1 uses lightweight scanning/regex, **not** the cmark AST. Correctness bar: visually helpful, not semantically perfect. (P2 may upgrade to AST-based highlighting.)
- Must be resilient to large documents (highlight visible/changed ranges; avoid re-scanning the whole document on every keystroke where feasible).

### 4.5 EditorView / MarkdownTextView
- `NSViewRepresentable` wrapping `NSTextView` in a scroll view, TextKit 2.
- Two-way binds `document.text`. On edit: update binding, run SyntaxHighlighter, and notify ContentView to schedule a re-render.
- P1 editor behaviors kept minimal: standard typing, monospaced editor font, undo/redo (free from NSTextView). Auto-list-continuation and smart indent are P3.

### 4.6 PreviewView
- `NSViewRepresentable` wrapping `WKWebView`.
- On first load: load HTMLTemplate via `loadHTMLString`.
- On update: JSON-encode the HTML body and call a JS function to set `#content.innerHTML` — no full reload, preserving scroll position.
- Dark mode: observe effective appearance, toggle template `data-theme`.

### 4.7 ContentView
- `HSplitView { EditorView; PreviewView }`.
- Owns the debounce timer (~150ms) between editor changes and renderer invocation.
- Passes rendered HTML to PreviewView.

## 5. Error Handling
- **File I/O:** handled by `FileDocument`/`DocumentGroup` system flow; no custom UI. UTF-8 with lenient fallback on read.
- **Rendering:** `MarkdownRenderer` never throws; always returns a String. No error branch needed downstream.
- **WebView injection:** body is JSON-encoded before being passed to JS, preventing quote/backslash breakage and incidental injection.

## 6. Testing Strategy
- **Unit (primary):** `MarkdownRenderer` against a table of GFM cases — headings, lists, tables, strikethrough, task lists, fenced code, links, escaping. Assert HTML output.
- **HTMLTemplate:** body embeds correctly; special characters do not break the page.
- **SyntaxHighlighter:** for given text, assert expected attribute ranges for key constructs.
- **UI/integration:** no automated UI tests in P1 (NSTextView + WebView automation is low ROI). Covered by the manual acceptance checklist below.
- **Approach:** TDD — write failing `MarkdownRenderer` tests first, then implement to green.

### Manual acceptance checklist
1. Launch app → new document opens with empty editor + empty preview.
2. Type GFM (heading, bold, list, table, task list, code fence, link) → preview updates live and correctly.
3. Editor shows syntax highlighting for those constructs.
4. Preview does not flicker or lose scroll position on each keystroke.
5. Save to a `.md` file; reopen it → content restored.
6. Toggle system appearance (light/dark) → both editor and preview follow.
7. Open an existing `.md` file from Finder → renders correctly.

## 7. Project Layout (proposed)
```
markout/
├─ Markout.xcodeproj / Package.swift    (build setup decided in the plan)
├─ Sources/Markout/
│   ├─ App/                MarkoutApp.swift, ContentView.swift
│   ├─ Document/           MarkdownDocument.swift
│   ├─ Editor/             EditorView.swift, MarkdownTextView.swift, SyntaxHighlighter.swift
│   ├─ Render/             MarkdownRenderer.swift, HTMLTemplate.swift, default.css
│   └─ Preview/            PreviewView.swift
├─ Tests/MarkoutTests/     MarkdownRendererTests.swift, HTMLTemplateTests.swift, SyntaxHighlighterTests.swift
└─ docs/superpowers/specs/
```
(Xcode project vs SwiftPM executable, and how cmark-gfm is vendored, are settled in the implementation plan.)

## 8. Roadmap (context, not P1 work)
- **P1** Core MVP (this spec)
- **P2** Rich content rendering (code highlight, KaTeX, Mermaid, scroll sync, CSS themes)
- **P3** Output & editing (export HTML/PDF, TOC, front matter, image paste, find & replace)
- **P4** Preferences & polish (settings, editor themes, word count, toolbar)
