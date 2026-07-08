# Markout P2 Rich Content Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enrich the P1 preview with syntax-highlighted code, KaTeX math, and Mermaid diagrams; add switchable/custom preview CSS themes and editor↔preview scroll sync — all offline, using bundled assets.

**Architecture:** Insert a pure `MathExtractor` stage before cmark (protect `$…$`/`$$…$$` from Markdown, reinsert raw TeX after), enable cmark source positions for scroll mapping, and load third-party JS/CSS from the app bundle so a new `afterRender()` JS hook highlights code, renders math, and draws diagrams after each `setContent`. The HTML template's stylesheet becomes a parameter driven by a `PreviewTheme` model. A pure `ScrollSync` maps editor lines to preview scroll offsets.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, WebKit; cmark-gfm (P1); bundled highlight.js, KaTeX (+auto-render, fonts), Mermaid; XcodeGen; Swift Testing.

## Global Constraints

- Deployment target **macOS 14.0**; product **Markout**; bundle id **tech.ankey.Markout**.
- **No network at runtime.** All of highlight.js, KaTeX, and Mermaid are vendored under `Resources/PreviewAssets/` and loaded via `baseURL: Bundle.main.resourceURL`. Never reference a CDN.
- Record vendored versions + upstream licenses in `Resources/PreviewAssets/VERSIONS.md`.
- **Backward compatibility:** do not break P1 public signatures. `MarkdownRenderer.renderHTMLBody(_:)` and `HTMLTemplate.page(theme:)` must keep working via default arguments / overloads. Existing P1 tests must stay green.
- Pure logic (`MathExtractor`, `ScrollSync`, `PreviewThemeStore` loader, template string builders) is unit-tested; AppKit/WebView plumbing is verified by the manual checklist.
- Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`).
- Commit after every task with Conventional Commit messages.

---

## File Structure (P2 delta)

```
Sources/Markout/
├─ Render/
│   ├─ MathExtractor.swift          NEW
│   ├─ MarkdownRenderer.swift       EDIT  RenderOptions / sourcepos
│   ├─ HTMLTemplate.swift           EDIT  assets, afterRender, previewCSS param
│   └─ PreviewTheme.swift           NEW   PreviewTheme + PreviewThemeStore
├─ Preview/
│   ├─ PreviewView.swift            EDIT  baseURL, scrollLine, reverse report
│   └─ ScrollSync.swift             NEW
├─ Editor/
│   └─ EditorView.swift             EDIT  publish top visible source line
└─ App/
    └─ ContentView.swift            EDIT  P2 pipeline + theme picker + scroll wiring
Resources/PreviewAssets/            NEW   highlight/, katex/, mermaid.min.js, themes/, VERSIONS.md
Tests/MarkoutTests/
├─ MathExtractorTests.swift         NEW
├─ RenderOptionsTests.swift         NEW
├─ HTMLTemplateP2Tests.swift        NEW
├─ PreviewThemeStoreTests.swift     NEW
└─ ScrollSyncTests.swift            NEW
```

---

## Task 1: MathExtractor (protect math from Markdown)

**Files:**
- Create: `Sources/Markout/Render/MathExtractor.swift`
- Test: `Tests/MarkoutTests/MathExtractorTests.swift`

**Interfaces:**
- Produces: `struct MathSpan { let display: Bool; let tex: String }`
- Produces: `enum MathExtractor { static func extract(_ text: String) -> (protected: String, spans: [MathSpan]); static func reinsert(_ html: String, spans: [MathSpan]) -> String }` — pure, never throws.

- [ ] **Step 1: Write failing tests `Tests/MarkoutTests/MathExtractorTests.swift`**

```swift
import Testing
@testable import Markout

struct MathExtractorTests {
    @Test func extractsInlineMath() {
        let (protected, spans) = MathExtractor.extract("energy is $E=mc^2$ ok")
        #expect(spans.count == 1)
        #expect(spans[0].display == false)
        #expect(spans[0].tex == "E=mc^2")
        #expect(!protected.contains("$"))
    }

    @Test func extractsDisplayMath() {
        let (_, spans) = MathExtractor.extract("$$\n\\frac{a}{b}\n$$")
        #expect(spans.count == 1)
        #expect(spans[0].display == true)
        #expect(spans[0].tex.contains("\\frac{a}{b}"))
    }

    @Test func ignoresMathInsideInlineCode() {
        let (_, spans) = MathExtractor.extract("use `$x$` literally")
        #expect(spans.isEmpty)
    }

    @Test func ignoresMathInsideFencedCode() {
        let md = "```\n$not math$\n```"
        let (_, spans) = MathExtractor.extract(md)
        #expect(spans.isEmpty)
    }

    @Test func unbalancedDollarIsLeftLiteral() {
        let (protected, spans) = MathExtractor.extract("price is $5 today")
        #expect(spans.isEmpty)
        #expect(protected.contains("$5"))
    }

    @Test func reinsertWrapsAndEscapes() {
        let (_, spans) = MathExtractor.extract("$a<b$")
        let html = MathExtractor.reinsert("<p>\u{FFFC}MATH0\u{FFFC}</p>", spans: spans)
        #expect(html.contains("math-inline"))
        #expect(html.contains("a&lt;b"))
        #expect(!html.contains("\u{FFFC}"))
    }

    @Test func plainTextUnchanged() {
        let (protected, spans) = MathExtractor.extract("no math here")
        #expect(spans.isEmpty)
        #expect(protected == "no math here")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail** (`MathExtractor` undefined).

```bash
cd /Users/maxmilian/side/markout && xcodegen generate
xcodebuild test -project Markout.xcodeproj -scheme Markout \
  -destination 'platform=macOS' -only-testing:MarkoutTests/MathExtractorTests 2>&1 | tail -20
```

- [ ] **Step 3: Implement `Sources/Markout/Render/MathExtractor.swift`**

Scan once, left to right. Track whether we are inside a fenced code block (```` ``` ```` / `~~~` line-delimited) or an inline code span (`` ` `` runs) and skip those regions. Outside code, match `$$…$$` (display, non-greedy, may span newlines) before single `$…$` (inline, no embedded newline, non-empty, not immediately doubled). Replace each match with placeholder `"\u{FFFC}MATH\(index)\u{FFFC}"`. `reinsert` maps each placeholder back to `<span class="math-inline">esc</span>` or `<div class="math-display">esc</div>` where `esc` is the TeX with `&`, `<`, `>` escaped. Both functions pure; on any ambiguity, prefer leaving text literal over corrupting it.

- [ ] **Step 4: Run tests to verify they pass** (7 tests). Adjust implementation, not expectations.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add MathExtractor to protect TeX from Markdown parsing"
```

---

## Task 2: MarkdownRenderer source positions (RenderOptions)

**Files:**
- Modify: `Sources/Markout/Render/MarkdownRenderer.swift`
- Test: `Tests/MarkoutTests/RenderOptionsTests.swift`

**Interfaces:**
- Produces: `struct RenderOptions { var sourcePositions: Bool; static let `default`: RenderOptions }`
- Produces: `static func renderHTMLBody(_ markdown: String, options: RenderOptions = .default) -> String` (P1 zero-arg call site keeps working).

- [ ] **Step 1: Write failing tests `Tests/MarkoutTests/RenderOptionsTests.swift`**

```swift
import Testing
@testable import Markout

struct RenderOptionsTests {
    @Test func defaultOmitsSourcePositions() {
        let html = MarkdownRenderer.renderHTMLBody("# Title")
        #expect(!html.contains("data-sourcepos"))
    }

    @Test func sourcePositionsAddDataAttribute() {
        let html = MarkdownRenderer.renderHTMLBody(
            "# Title\n\npara", options: .init(sourcePositions: true))
        #expect(html.contains("data-sourcepos"))
    }
}
```

- [ ] **Step 2: Run to verify failure** (compile error / no attribute).

- [ ] **Step 3: Implement**

Add `RenderOptions`. In `renderHTMLBody`, start from `CMARK_OPT_DEFAULT` and OR in `CMARK_OPT_SOURCEPOS` when `options.sourcePositions`. Keep everything else identical. Do not alter the existing P1 test file.

- [ ] **Step 4: Run the full renderer suite** — P1 `MarkdownRendererTests` **and** `RenderOptionsTests` must pass.

```bash
xcodebuild test -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' \
  -only-testing:MarkoutTests/MarkdownRendererTests -only-testing:MarkoutTests/RenderOptionsTests 2>&1 | tail -20
```

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add RenderOptions with cmark source positions for scroll sync"
```

---

## Task 3: Vendor preview assets + VERSIONS.md

**Files:**
- Create: `Resources/PreviewAssets/highlight/highlight.min.js`, `.../highlight-light.css`, `.../highlight-dark.css`
- Create: `Resources/PreviewAssets/katex/katex.min.js`, `katex.min.css`, `auto-render.min.js`, `fonts/…`
- Create: `Resources/PreviewAssets/mermaid/mermaid.min.js`
- Create: `Resources/PreviewAssets/themes/default.css`, `github.css`, `github-dark-dimmed.css`, `solarized.css`
- Create: `Resources/PreviewAssets/VERSIONS.md`
- Modify: `project.yml` (add `Resources/PreviewAssets` as a resources build-phase folder)

- [ ] **Step 1: Fetch pinned releases** of highlight.js, KaTeX (dist incl. `fonts/`), and Mermaid into the paths above. Pin exact versions. (If offline, note the required files and versions in `VERSIONS.md` and stage them when network is available — the rest of P2 is written against these paths.)

- [ ] **Step 2: Seed theme CSS.** Copy the P1 `Sources/Markout/Render/default.css` to `Resources/PreviewAssets/themes/default.css`; add `github.css` (light), `github-dark-dimmed.css`, and `solarized.css`. Each is a full preview stylesheet (same element scope as P1's default: `#content`, headings, `code`, `pre`, `table`, `blockquote`, `a`, `img`) including light/dark handling via `[data-theme="dark"]`.

- [ ] **Step 3: Write `VERSIONS.md`** listing each asset, its upstream tag/URL, and its license (highlight.js BSD-3, KaTeX MIT, Mermaid MIT).

- [ ] **Step 4: Register resources in `project.yml`.** Under target `Markout` `sources`, add:

```yaml
      - path: Resources/PreviewAssets
        buildPhase: resources
```

Keep the existing `Sources/Markout/Render/default.css` resource entry (still used by the P1 fallback). Regenerate:

```bash
cd /Users/maxmilian/side/markout && xcodegen generate
xcodebuild build -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' 2>&1 | tail -15
```

Expected: BUILD SUCCEEDED; `PreviewAssets` copied into `Markout.app/Contents/Resources`.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "chore: vendor highlight.js, KaTeX, Mermaid, and preview themes"
```

---

## Task 4: PreviewTheme + PreviewThemeStore

**Files:**
- Create: `Sources/Markout/Render/PreviewTheme.swift`
- Test: `Tests/MarkoutTests/PreviewThemeStoreTests.swift`

**Interfaces:**
- Produces: `struct PreviewTheme: Identifiable, Hashable { let id: String; let name: String; let css: String }`
- Produces: `enum PreviewThemeStore { static func themes(inDirectory url: URL) -> [PreviewTheme]; static var bundled: [PreviewTheme]; static func theme(id: String) -> PreviewTheme?; static func custom(fromFileURL url: URL) -> PreviewTheme? }`

- [ ] **Step 1: Write failing tests `Tests/MarkoutTests/PreviewThemeStoreTests.swift`**

Write a temp directory with two `.css` files, assert `themes(inDirectory:)` returns both with ids derived from filenames and CSS content loaded; assert an unknown id via a lookup over that list is `nil`; assert `custom(fromFileURL:)` reads a file's contents into a `PreviewTheme` whose id is stable. (Use `FileManager.default.temporaryDirectory`; `Bundle.main`-based `bundled` is exercised at runtime, not here.)

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement.** `themes(inDirectory:)` enumerates `*.css`, sorts by name, maps filename→`id`, prettifies →`name`, loads contents. `bundled` resolves `Resources/PreviewAssets/themes` via `Bundle.main.url(forResource:withExtension:subdirectory:)` / `urls(forResourcesWithExtension:subdirectory:)` and reuses `themes(inDirectory:)`. `theme(id:)` searches `bundled`. `custom(fromFileURL:)` returns `nil` on unreadable file.

- [ ] **Step 4: Run tests to verify pass.**

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add PreviewTheme model and CSS theme store"
```

---

## Task 5: HTMLTemplate — assets, afterRender, CSS parameter

**Files:**
- Modify: `Sources/Markout/Render/HTMLTemplate.swift`
- Test: `Tests/MarkoutTests/HTMLTemplateP2Tests.swift`

**Interfaces:**
- Produces: `static func page(theme: Theme, previewCSS: String) -> String`; keep P1 `page(theme:)` as an overload delegating with `PreviewThemeStore.theme(id: "default")?.css ?? css`.

- [ ] **Step 1: Write failing tests `Tests/MarkoutTests/HTMLTemplateP2Tests.swift`**

```swift
import Testing
@testable import Markout

struct HTMLTemplateP2Tests {
    @Test func linksBundledAssets() {
        let page = HTMLTemplate.page(theme: .light, previewCSS: "/*x*/")
        #expect(page.contains("highlight.min.js"))
        #expect(page.contains("katex.min.js"))
        #expect(page.contains("auto-render.min.js"))
        #expect(page.contains("mermaid.min.js"))
        #expect(page.contains("katex.min.css"))
    }

    @Test func embedsPassedPreviewCSS() {
        let page = HTMLTemplate.page(theme: .light, previewCSS: "BODY{color:hotpink}")
        #expect(page.contains("BODY{color:hotpink}"))
    }

    @Test func definesAfterRenderPipeline() {
        let page = HTMLTemplate.page(theme: .dark, previewCSS: "")
        #expect(page.contains("function afterRender"))
        #expect(page.contains("renderMathInElement"))
        #expect(page.contains("mermaid"))
        #expect(page.contains("hljs"))
    }

    @Test func setContentCallsAfterRender() {
        let page = HTMLTemplate.page(theme: .light, previewCSS: "")
        #expect(page.contains("afterRender()"))
    }

    @Test func p1OverloadStillWorks() {
        let page = HTMLTemplate.page(theme: .light)
        #expect(page.contains("<div id=\"content\">"))
        #expect(page.contains("function setContent"))
    }
}
```

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement.** Extend `page`:
  - `<head>`: `<link rel="stylesheet" href="PreviewAssets/katex/katex.min.css">`, `<link rel="stylesheet" href="PreviewAssets/highlight/highlight-light.css">` + dark variant guarded by `[data-theme="dark"]`, then `<style>\(previewCSS)</style>`. Load scripts with defer or at end of body: `highlight.min.js`, `katex.min.js`, `auto-render.min.js`, `mermaid.min.js` (relative to `baseURL` = bundle resources).
  - JS: `setContent(html)` now sets `#content.innerHTML` then calls `afterRender()`.
  - `afterRender()`: guard each library (`typeof hljs`, `typeof renderMathInElement`, `typeof mermaid`). Rewrite `#content code.language-mermaid` parents into `<div class="mermaid">`+text, then `mermaid.run(...)`. `hljs.highlightAll()`. `renderMathInElement(document.getElementById('content'), {delimiters:[{left:'$$',right:'$$',display:true},{left:'$',right:'$',display:false},{left:'\\[',right:'\\]',display:true},{left:'\\(',right:'\\)',display:false}], throwOnError:false})`.
  - `scrollToSourceLine(line)`: query `[data-sourcepos]`, parse start line, pick the last element with start ≤ line, `scrollIntoView({block:'start'})`. (Wire-up in Task 6/8; define here.)
  - Keep `setTheme(dark)`.
  - Add `page(theme:)` overload delegating with the default theme CSS.

- [ ] **Step 4: Run tests to verify pass** (5 + P1 `HTMLTemplateTests`). Do not modify P1 `HTMLTemplateTests`.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: extend HTML template with code/math/diagram rendering and CSS param"
```

---

## Task 6: ScrollSync (pure mapping)

**Files:**
- Create: `Sources/Markout/Preview/ScrollSync.swift`
- Test: `Tests/MarkoutTests/ScrollSyncTests.swift`

**Interfaces:**
- Produces: `struct ScrollAnchor { let sourceLine: Int; let fraction: Double }`
- Produces: `enum ScrollSync { static func previewFraction(forEditorLine line: Int, totalLines: Int, anchors: [ScrollAnchor]) -> Double }` — clamped to `0...1`.

- [ ] **Step 1: Write failing tests `Tests/MarkoutTests/ScrollSyncTests.swift`**

```swift
import Testing
@testable import Markout

struct ScrollSyncTests {
    let anchors = [ScrollAnchor(sourceLine: 1, fraction: 0.0),
                   ScrollAnchor(sourceLine: 11, fraction: 0.5),
                   ScrollAnchor(sourceLine: 21, fraction: 1.0)]

    @Test func interpolatesBetweenAnchors() {
        let f = ScrollSync.previewFraction(forEditorLine: 6, totalLines: 21, anchors: anchors)
        #expect(abs(f - 0.25) < 0.01)
    }

    @Test func clampsBelowFirstAnchor() {
        #expect(ScrollSync.previewFraction(forEditorLine: 0, totalLines: 21, anchors: anchors) == 0.0)
    }

    @Test func clampsAboveLastAnchor() {
        #expect(ScrollSync.previewFraction(forEditorLine: 99, totalLines: 21, anchors: anchors) == 1.0)
    }

    @Test func proportionalFallbackWithoutAnchors() {
        let f = ScrollSync.previewFraction(forEditorLine: 5, totalLines: 10, anchors: [])
        #expect(abs(f - 0.5) < 0.01)
    }
}
```

- [ ] **Step 2: Run to verify failure.**

- [ ] **Step 3: Implement.** With anchors: find the bracketing pair around `line`, linearly interpolate their fractions; clamp to the first/last fraction outside the range. Without anchors: `Double(line) / Double(max(totalLines, 1))`. Always clamp `0...1`.

- [ ] **Step 4: Run tests to verify pass** (4 tests).

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add pure ScrollSync editor-to-preview line mapping"
```

---

## Task 7: PreviewView + EditorView scroll wiring

**Files:**
- Modify: `Sources/Markout/Preview/PreviewView.swift`
- Modify: `Sources/Markout/Editor/EditorView.swift`

**Interfaces:**
- `PreviewView(htmlBody:isDark:previewCSS:scrollLine:onPreviewScroll:)` — loads template with `baseURL: Bundle.main.resourceURL`; on `scrollLine` change calls `scrollToSourceLine`.
- `EditorView(text:onVisibleLineChange:)` — publishes the top visible source line as the user scrolls/edits.

- [ ] **Step 1: EditorView.** Observe the scroll view's `NSView.boundsDidChangeNotification` on `contentView` (set `postsBoundsChangedNotifications = true`). Compute the character index at the visible top via layout, convert to a 1-based line number, throttle (~50 ms), and call `onVisibleLineChange`. Add an `isProgrammaticScroll` guard so preview-initiated scrolls don't echo back.

- [ ] **Step 2: PreviewView.** Change `loadHTMLString(_, baseURL: nil)` → `baseURL: Bundle.main.resourceURL` so bundled assets resolve. Add `previewCSS` (passed into `HTMLTemplate.page(theme:previewCSS:)`), `scrollLine: Int?`, and `onPreviewScroll` callback. On `updateNSView` when `scrollLine` changes, `evaluateJavaScript("scrollToSourceLine(\(line))")`. Keep the P1 no-reload `setContent` path; only reload the template when `previewCSS`/theme changes (full `loadHTMLString`), otherwise inject.

- [ ] **Step 3: Build to verify it compiles.**

```bash
cd /Users/maxmilian/side/markout && xcodegen generate
xcodebuild build -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' 2>&1 | tail -15
```

Expected: BUILD SUCCEEDED. (AppKit/WebView bridge — behavior verified in Task 8's manual checklist.)

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: wire editor/preview scroll reporting and asset base URL"
```

---

## Task 8: ContentView pipeline + theme picker + acceptance

**Files:**
- Modify: `Sources/Markout/App/ContentView.swift`

**Interfaces:**
- Consumes: `MathExtractor`, `MarkdownRenderer(options:)`, `PreviewThemeStore`, `ScrollSync`, extended `EditorView`/`PreviewView`.

- [ ] **Step 1: Rewrite the render pipeline.** In the debounce, run:

```swift
let (protected, spans) = MathExtractor.extract(markdown)
let raw = MarkdownRenderer.renderHTMLBody(protected, options: .init(sourcePositions: true))
renderedHTML = MathExtractor.reinsert(raw, spans: spans)
```

- [ ] **Step 2: Theme selection.** Add `@AppStorage("previewThemeID") private var previewThemeID = "github"`; resolve `PreviewThemeStore.theme(id:) ?? default`; pass its CSS to `PreviewView`. Add a `View`-menu picker (or a small toolbar `Picker`) over `PreviewThemeStore.bundled`.

- [ ] **Step 3: Scroll sync state.** Hold `@State private var editorLine: Int` and `@State private var previewScrollLine: Int?`. `EditorView(onVisibleLineChange:)` updates `editorLine`; map to `previewScrollLine` (source line is passed straight to `scrollToSourceLine`, which does the DOM lookup — `ScrollSync` is used for the proportional fallback path when no `data-sourcepos` match exists). Guard the reverse direction to avoid a feedback loop.

- [ ] **Step 4: Build, generate, launch.**

```bash
cd /Users/maxmilian/side/markout && xcodegen generate
xcodebuild build -project Markout.xcodeproj -scheme Markout \
  -destination 'platform=macOS' -derivedDataPath .build/dd 2>&1 | tail -15
open .build/dd/Build/Products/Debug/Markout.app
```

- [ ] **Step 5: Run the full test suite** — all P1 + P2 tests pass.

```bash
xcodebuild test -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' 2>&1 | tail -25
```

- [ ] **Step 6: Manual acceptance checklist (in the launched app)**

1. ```` ```swift ```` block is syntax-colored; unknown language falls back to plain monospace.
2. `$E=mc^2$` renders inline; `$$…$$` renders as a centered block; `_`/`\frac` inside math survive (not italicized).
3. ```` ```mermaid ```` flowchart renders as SVG; a malformed diagram shows an inline error, page stays usable.
4. Preview theme picker restyles live; choice persists across relaunch (`@AppStorage`).
5. Scrolling the editor moves the preview to the matching section; scrolling the preview doesn't cause a jitter loop.
6. Toggle system dark mode → code/math/diagram/base styles all switch coherently.
7. Turn off networking (or Little Snitch "deny all") → every feature above still works (assets local).

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: wire P2 math/code/diagram pipeline, theme picker, and scroll sync"
```

---

## Self-Review Notes

- **Spec coverage:** MathExtractor (§4.1) → Task 1; RenderOptions/sourcepos (§4.2) → Task 2; vendored assets → Task 3; PreviewTheme/Store (§4.4) → Task 4; HTMLTemplate afterRender + CSS param (§4.3) → Task 5; ScrollSync (§4.5) → Task 6; EditorView/PreviewView scroll (§4.6) → Task 7; ContentView pipeline + themes (§4.7) → Task 8. Error handling (§5): math never-throws (Task 1), KaTeX/Mermaid JS guards (Task 5), best-effort scroll (Tasks 6–8). Testing (§6): pure unit tests Tasks 1,2,4,5,6; manual checklist Task 8. All covered.
- **Backward compatibility:** P1 `renderHTMLBody(_:)` and `HTMLTemplate.page(theme:)` preserved via default arg / overload; P1 test files untouched and must stay green.
- **Known risks:** (a) exact upstream filenames/global names for KaTeX auto-render (`renderMathInElement`) and Mermaid v10 (`mermaid.run`) are verified by Task 5's string tests + Task 8 manual render; adjust JS to match the pinned versions, not the test intent. (b) `WKWebView` loading bundle fonts requires `baseURL: Bundle.main.resourceURL` and correct relative paths — verified in Task 8. (c) math inside code fences relies on Task 1's code-region skipping — covered by unit tests.
