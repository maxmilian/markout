# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build, test, run

The Xcode project is **generated** from `project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen) and is git-ignored — always regenerate after changing `project.yml`, adding/removing source files, or on a fresh checkout.

```sh
brew install xcodegen                 # one-time
xcodegen generate                     # (re)create Markout.xcodeproj

# full test suite (Swift Testing)
xcodebuild test -project Markout.xcodeproj -scheme Markout \
  -destination 'platform=macOS' -derivedDataPath .build/dd

# a single suite or test
xcodebuild test -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' \
  -only-testing:MarkoutTests/MarkdownFormatterTests
xcodebuild test ... -only-testing:MarkoutTests/MarkdownFormatterTests/boldWrapsSelection

# build and launch the app
xcodebuild build -project Markout.xcodeproj -scheme Markout \
  -destination 'platform=macOS' -derivedDataPath .build/dd
open .build/dd/Build/Products/Debug/Markout.app
```

There is no linter configured. Target is macOS 14.0, Swift 5.9, ad-hoc signed (no sandbox entitlement).

## Vendored preview assets (offline constraint)

The preview renders in a `WKWebView` with **no network access** — highlight.js, KaTeX (+fonts), and Mermaid are vendored under `Resources/PreviewAssets/` and loaded relative to `Bundle.main.resourceURL`. Never reference a CDN.

- `project.yml` bundles `Resources/PreviewAssets` as a **folder reference** (`type: folder`) so the `katex/`, `highlight/`, `mermaid/`, `themes/` subdirectory structure is preserved in the app bundle. Adding it as a normal resource flattens the tree and breaks both the relative `<script src="PreviewAssets/…">` paths and `Bundle.main.url(forResource:"themes", subdirectory:"PreviewAssets")` — and causes "Multiple commands produce" build errors on the duplicate `.gitkeep`/`default.css` names.
- To bump versions, edit the pins in `Resources/PreviewAssets/fetch-assets.sh` and run it on a networked machine; record versions/licenses in `VERSIONS.md`.

## Architecture

SwiftUI `DocumentGroup` app. Each window is a `ContentView` holding an editor pane and a preview pane in an `HSplitView`. The design deliberately separates **pure, unit-tested logic** from **thin AppKit/WebKit edges** (verified manually), so most files under `Render/`, `Document/`, and the `Settings/*` models are pure functions with matching tests in `Tests/MarkoutTests/`.

**Render pipeline** (`ContentView.render`, debounced 150 ms on `@MainActor`):
1. `FrontMatterParser.split` strips YAML front matter, keeping the body.
2. `MathExtractor.extract` replaces `$…$` / `$$…$$` with placeholders so cmark can't mangle the TeX (skips code spans/fences).
3. `MarkdownRenderer.renderHTMLBody(_, options:)` runs cmark-gfm; `RenderOptions(sourcePositions: true)` emits `data-sourcepos` used for scroll sync.
4. `MathExtractor.reinsert` puts the TeX back as `.math-inline` / `.math-display` elements.
5. The HTML body is pushed to the WebView via `setContent(html)`, which sets `#content.innerHTML` then calls `afterRender()` — a JS hook (defined in `HTMLTemplate`) that runs `hljs`, `katex.render` over the math spans, and `mermaid.run` over `code.language-mermaid`. This is a no-reload injection to avoid flicker; the template is only fully reloaded when the theme/CSS changes.

**Editor** (`EditorView` → `MarkoutTextView`, TextKit 1 with an explicit layout manager): `SyntaxHighlighter` is a regex tokenizer + themed `apply`. `MarkoutTextView` adds Markdown behaviors (list continuation on Return, image paste/drop → `AssetStore` + `ImagePasteHandler`). `LineNumberRulerView` draws the gutter; under soft wrap it must normalize the first visible char back to its logical line start before numbering.

**Menu/toolbar → focused window**: `ContentView` publishes a `DocumentActions` (export HTML/PDF, insert TOC, `format(FormatCommand)`) via `.focusedSceneValue`; `MarkoutApp` menu commands and toolbar buttons call it. AppKit views the commands need (`MarkoutTextView`, preview `WKWebView`) are reached through the `EditorBridge` `ObservableObject` populated by `onEditorReady` / `onWebViewReady`. Toolbar/menu formatting applies a pure `MarkdownFormatter` transform over the whole document as a single undoable `shouldChangeText`/`replaceCharacters`/`didChangeText` edit.

**Settings**: persisted via `@AppStorage`, keyed by the constants in `Settings/SettingsKeys.swift` (`SettingsKey` / `SettingsDefault`), and flow into the editor/preview by SwiftUI observation — no notification plumbing. `SettingsView` is the `Settings { }` scene (⌘,). Editor and preview themes are data (`EditorThemeStore`, `PreviewThemeStore`); a custom preview CSS file is selected via the sentinel `previewThemeID == "custom"` + `customPreviewCSSPath`.

## Conventions

- **Backward compatibility is preserved additively.** When extending P1/P2/P3 APIs, keep the old signature working via a default-argument overload or a delegating shim (e.g. `HTMLTemplate.page(theme:)` over `page(theme:previewCSS:)`, `SyntaxHighlighter.apply(to:baseFont:textColor:)` shimming the themed `apply`, `RenderOptions.default`). Existing tests must stay green.
- Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`) in `Tests/MarkoutTests/`. Pure logic is unit-tested; AppKit/WebKit wiring is verified by launching the app.
- Commit messages are Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`).
- The four-phase roadmap (P1–P4) is complete; specs and implementation plans live in `docs/superpowers/{specs,plans}/`.
