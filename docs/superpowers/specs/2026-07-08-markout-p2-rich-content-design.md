# Markout — P2 Rich Content Design

**Date:** 2026-07-08
**Status:** Approved (design phase)
**Scope:** Phase 2 of the phased effort to build a modern, native macOS Markdown editor (successor to MacDown). Builds directly on the shipped P1 Core MVP.

---

## 1. Goal

Take the P1 split editor + live preview from "renders GFM" to "renders rich technical documents." P2 adds, in the preview: syntax-highlighted code blocks, TeX math via KaTeX, Mermaid diagrams, and switchable/custom CSS themes; and across both panes: scroll synchronization so the preview tracks what the author is editing. Everything stays offline and native — no network fetches — by bundling the third-party JS/CSS assets in the app.

**Builds on P1 (already shipped):**
- `MarkdownRenderer.renderHTMLBody(_:)` — cmark-gfm wrapper (pure `String -> String`).
- `HTMLTemplate.page(theme:)` — full HTML doc with `#content`, `setContent(html)`, `setTheme(dark)`.
- `PreviewView` (`WKWebView`) + `PreviewInjection` — injects body via `setContent`, no full reload.
- `EditorView` / `MarkdownTextView` (`NSTextView`, TextKit 2) + `SyntaxHighlighter`.
- `ContentView` — `HSplitView`, 150 ms debounce, `colorScheme`-driven dark mode.

**Out of scope for P2** (deferred, tracked in roadmap):
- P3: export HTML/PDF, TOC, YAML front matter, image paste/drag, find & replace, list continuation.
- P4: preferences window, editor color themes, word count, formatting toolbar.

## 2. Technology Choices

| Concern | Choice | Rationale |
|---------|--------|-----------|
| Code highlighting | **highlight.js** (bundled, client-side) | cmark-gfm already emits `<pre><code class="language-…">`; highlight.js styles it in the WebView with zero server work. Large language coverage, MIT |
| Math | **KaTeX** + `auto-render` (bundled) | Faster and more self-contained than MathJax; ships its own fonts; MIT. Renders in the WebView |
| Diagrams | **Mermaid** (bundled) | De-facto Markdown diagram standard; renders `mermaid` code fences to SVG client-side, MIT |
| Math extraction | Pre-tokenize `$…$` / `$$…$$` **before** cmark | cmark would mangle `_`, `*`, `\` inside math as Markdown. Extract to placeholders, render, re-insert raw for KaTeX. Keeps the math pipeline a pure, testable Swift function |
| Asset loading | `WKWebView.loadHTMLString(_, baseURL: Bundle.main.resourceURL)` | Lets `<script src="katex.min.js">` and KaTeX's font files resolve from the app bundle offline; keeps the P1 no-reload injection path |
| Scroll sync | cmark `CMARK_OPT_SOURCEPOS` → `data-sourcepos` on blocks | Maps editor line ↔ preview element without heuristics; proportional fallback when a line has no block |
| CSS themes | Bundled `.css` theme files + user-supplied file | Template CSS becomes a parameter, not a constant; a `PreviewTheme` model selects which stylesheet the template embeds |

**Asset vendoring:** highlight.js, KaTeX (JS + CSS + `fonts/`), and Mermaid are checked into `Resources/PreviewAssets/` (pinned versions, with a `VERSIONS.md` recording upstream tags and licenses) and added to the app target's `resources` build phase. No CDN, no runtime download — the preview works fully offline, matching a native app's expectations.

## 3. Architecture

```
P1 pipeline (unchanged core):
  text → MarkdownRenderer.renderHTMLBody → PreviewInjection.setContent → WKWebView

P2 inserts a preprocessing stage and enriches the template/WebView:

  document.text
    │
    ├─ MathExtractor.extract(text)               [NEW, pure]
    │     → (protectedText, [MathSpan])          $…$/$$…$$ replaced by placeholders
    │
    ├─ MarkdownRenderer.renderHTMLBody(_,        [P1, extended: sourcepos opt]
    │       options: .init(sourcePositions:true))
    │
    ├─ MathExtractor.reinsert(html, spans)       [NEW, pure]
    │     → html with <span class="math"> / <div class="math"> raw TeX
    │
    └─ PreviewInjection.script(forBody:)         [P1, unchanged]
          → setContent(html)  in WKWebView
             └─ afterRender() JS hook [NEW]:
                  hljs.highlightAll()
                  renderMathInElement(#content)   (KaTeX auto-render)
                  mermaid.run({ nodes: .language-mermaid })

  PreviewTheme (model) → HTMLTemplate.page(theme:previewCSS:)   [template extended]
                          selects which bundled/user CSS is embedded

  Scroll sync:
    EditorView reports top visible line  ──┐
                                            ├─ ScrollSync (pure mapping) ─→ preview.scrollToSourceLine(n)
    Preview reports scroll (reverse)  ─────┘   via data-sourcepos lookup + proportional fallback
```

### Data flow additions (still unidirectional)

```
User types
  → MathExtractor.extract           (protect math from Markdown)
  → MarkdownRenderer (sourcepos on) (HTML with data-sourcepos)
  → MathExtractor.reinsert          (raw TeX back in)
  → setContent(html)
  → afterRender(): highlight code, render math, render mermaid   [in WebView]

User scrolls editor
  → visible top line → ScrollSync.previewOffset(line, map) → JS scroll   [no re-render]
```

## 4. Component Specifications

### 4.1 MathExtractor (new, pure)
- `static func extract(_ text: String) -> (protected: String, spans: [MathSpan])`
  - Finds display math `$$…$$` (may span lines) and inline math `$…$` (single line, not `$$`), **skipping** fenced code blocks and inline code spans (math inside code is literal).
  - Replaces each with an unambiguous placeholder token unlikely to appear in prose and inert to Markdown (e.g. `\u{FFFC}MATH0\u{FFFC}`).
  - `MathSpan` records `display: Bool` and the raw TeX (without `$` delimiters).
- `static func reinsert(_ html: String, spans: [MathSpan]) -> String`
  - Replaces each placeholder with `<span class="math-inline">…</span>` or `<div class="math-display">…</div>` containing HTML-escaped raw TeX for KaTeX to render.
- Escaping rules and placeholder uniqueness are the testable core. Never throws; if counts mismatch (shouldn't happen), leaves placeholders untouched rather than corrupting output.

### 4.2 MarkdownRenderer (P1, extended)
- Add an options parameter without breaking the P1 signature:
  `static func renderHTMLBody(_ markdown: String, options: RenderOptions = .default) -> String`.
- `RenderOptions { var sourcePositions: Bool }`. When `true`, pass `CMARK_OPT_SOURCEPOS` so block elements carry `data-sourcepos="startLine:col-endLine:col"`.
- Existing P1 callers and tests keep working via the default argument.

### 4.3 HTMLTemplate (P1, extended)
- `static func page(theme: Theme, previewCSS: String) -> String` — the embedded stylesheet becomes a parameter (the selected `PreviewTheme`'s CSS) instead of the hardcoded `default.css`. A P1-compatible overload keeps `page(theme:)` using the default theme's CSS.
- `<head>` additionally links the bundled assets (relative to `baseURL`): `highlight.js` + a highlight theme CSS, `katex.min.css` + `katex.min.js` + `auto-render.min.js`, `mermaid.min.js`.
- Adds a JS `afterRender()` invoked by `setContent`: runs `hljs.highlightAll()` over new nodes, KaTeX `renderMathInElement(#content)` (delimiters `$$…$$`, `$…$`, plus `\[ \]`, `\( \)`), and Mermaid on `code.language-mermaid` (rewriting those to `<div class="mermaid">` first).
- Adds `scrollToSourceLine(line)`: finds the element whose `data-sourcepos` best matches `line` and scrolls it into view; used by scroll sync.
- Highlight/KaTeX theme swap on `setTheme(dark)` (light vs dark highlight.js stylesheet toggled by `data-theme`, handled in CSS).

### 4.4 PreviewTheme (new, model)
- `struct PreviewTheme { let id: String; let name: String; let css: String }`.
- `enum PreviewThemeStore`: loads bundled themes from `Resources/PreviewAssets/themes/*.css` (e.g. `github`, `github-dark-dimmed`, `solarized`) plus the P1 `default`. Provides `all: [PreviewTheme]`, `theme(id:)`, and `custom(fromFileURL:)` for a user-supplied stylesheet (P2 exposes selection via a simple menu; a full preferences UI is P4).
- Pure loader logic (given a directory of CSS) is unit-testable; the concrete bundle lookup is the thin runtime edge.

### 4.5 ScrollSync (new, pure)
- Input: the list of `(sourceLine, verticalFraction)` anchors reported from the preview (each `data-sourcepos` block's top offset as a fraction of scroll height), the editor's current top visible source line, and total line count.
- `static func previewFraction(forEditorLine line: Int, anchors: [ScrollAnchor]) -> Double` — returns the target scroll fraction by locating the bracketing anchors and interpolating; falls back to `line / totalLines` when anchors are absent.
- Deliberately pure so the mapping is tested without a WebView; the AppKit/JS plumbing (observing `NSScrollView` bounds, calling `scrollToSourceLine`) is the untested edge.

### 4.6 EditorView / PreviewView (P1, extended)
- **EditorView:** observe the enclosing `NSScrollView`'s `contentView` bounds-change notifications; compute the top visible character index → source line; publish it (via a binding/closure) with light throttling. A guard flag suppresses the feedback loop when a scroll originates from the preview side.
- **PreviewView:** gains `scrollLine: Int?` input; on change (and after `afterRender`) calls `scrollToSourceLine`. Reports its own scroll back for the reverse direction. Keeps the P1 no-reload injection; template/base-URL change is the only structural edit.

### 4.7 ContentView (P1, extended)
- Owns the selected `PreviewTheme` (`@State`, default `github`) and passes its CSS into `PreviewView`/template. A `View` menu / picker switches themes (persisted lightly via `@AppStorage`; formal preferences are P4).
- Runs the P2 render pipeline in the debounce: `extract → renderHTMLBody(sourcePositions:true) → reinsert → setContent`.
- Holds the shared top-visible-line state and wires editor↔preview scroll sync with the anti-feedback guard.

## 5. Error Handling
- **Math:** `MathExtractor` never throws; malformed/mismatched delimiters degrade to literal text (leftover `$` shown as-is), never corrupting surrounding HTML. KaTeX `throwOnError:false` renders parse errors inline in red rather than breaking the page.
- **Diagrams:** Mermaid parse failures are caught in JS and rendered as an inline error box in place of the diagram; the rest of the preview is unaffected.
- **Assets missing:** if a bundled asset fails to load, `afterRender` guards each feature (`typeof hljs !== 'undefined'` etc.) so a missing library degrades to plain (already-readable) output instead of a JS exception halting `setContent`.
- **Scroll sync:** purely best-effort; any mapping gap falls back to proportional scroll. Never blocks editing or rendering.

## 6. Testing Strategy
- **Unit (primary, pure Swift):**
  - `MathExtractor`: inline vs display extraction; ignores math inside fenced/inline code; round-trips placeholders; handles unbalanced `$`; escapes TeX on reinsert.
  - `MarkdownRenderer` sourcepos: `data-sourcepos` present when enabled, absent by default (P1 tests unchanged).
  - `HTMLTemplate`: asset `<script>`/`<link>` tags present; `afterRender` defined; `page(theme:previewCSS:)` embeds the passed CSS; mermaid rewrite hook present.
  - `PreviewThemeStore`: loads themes from a fixture directory; `theme(id:)` and custom-file path.
  - `ScrollSync`: interpolation between anchors; proportional fallback; clamps at ends.
- **Integration:** none automated for the WebView (highlight/KaTeX/Mermaid are third-party, exercised manually).
- **Approach:** TDD — failing pure-Swift tests first (math, sourcepos, template strings, theme store, scroll math), then implement to green. WebView-rendered output is covered by the manual checklist.

### Manual acceptance checklist
1. A fenced ```` ```swift ```` block renders with syntax colors; an unknown language degrades to plain monospace.
2. `$E=mc^2$` renders inline; a `$$…$$` block renders centered; `_` and `\frac` inside math are **not** eaten by Markdown.
3. A ```` ```mermaid ```` flowchart renders as an SVG diagram; a broken diagram shows an inline error, page still usable.
4. Switching the preview theme (View menu) restyles the preview live; selection persists across relaunch.
5. Scrolling the editor moves the preview to the corresponding section; scrolling the preview does not fight back (no jitter loop).
6. Toggling dark mode switches code/math/diagram styling coherently with the rest of the preview.
7. With networking disabled, all of the above still work (assets are local).

## 7. Project Layout (additions)
```
Sources/Markout/
├─ Render/
│   ├─ MathExtractor.swift          NEW  extract/reinsert math spans (pure)
│   ├─ MarkdownRenderer.swift       EDIT sourcepos option
│   ├─ HTMLTemplate.swift           EDIT asset links, afterRender, CSS param
│   └─ PreviewTheme.swift           NEW  PreviewTheme + PreviewThemeStore
├─ Preview/
│   ├─ PreviewView.swift            EDIT baseURL=resourceURL, scrollLine, reverse report
│   └─ ScrollSync.swift             NEW  pure editor↔preview line mapping
├─ Editor/
│   └─ EditorView.swift             EDIT report top visible source line
└─ App/
    └─ ContentView.swift            EDIT P2 pipeline, theme picker, scroll wiring
Resources/PreviewAssets/            NEW  highlight.js, katex/, mermaid.min.js, themes/*.css, VERSIONS.md
Tests/MarkoutTests/
├─ MathExtractorTests.swift         NEW
├─ RenderOptionsTests.swift         NEW  (sourcepos)
├─ HTMLTemplateP2Tests.swift        NEW  (asset tags, afterRender, CSS param)
├─ PreviewThemeStoreTests.swift     NEW
└─ ScrollSyncTests.swift            NEW
```

## 8. Roadmap (context, not P2 work)
- **P1** Core MVP — shipped.
- **P2** Rich content rendering (this spec).
- **P3** Output & editing (export HTML/PDF, TOC, front matter, image paste, find & replace, list continuation).
- **P4** Preferences & polish (settings, editor themes, word count, toolbar).
