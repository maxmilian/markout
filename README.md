<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/hero-dark.svg">
  <img alt="Markout — a modern, native macOS Markdown editor" src="assets/hero-light.svg">
</picture>

# Markout

A modern, native macOS Markdown editor for Apple Silicon — the spiritual successor to the unmaintained [MacDown](https://github.com/MacDownApp/macdown).

Built with SwiftUI + TextKit + WKWebView. Everything runs **offline** — the syntax, math, and diagram engines are vendored, no CDN. MIT licensed.

![Markout editing a document with live preview](assets/screenshot.png)

## Features

**Editing**
- Split editor + live preview with a 150 ms debounced render
- Markdown syntax highlighting with switchable editor color themes
- Automatic list continuation, image paste/drop (saved beside the document)
- Find & replace, optional line-number gutter, soft wrap toggle
- Formatting toolbar and **Format** menu (bold ⌘B, italic ⌘I, link ⌘K, headings, quote, list) — all undoable

**Preview**
- GitHub-Flavored Markdown via [cmark-gfm](https://github.com/apple/swift-cmark)
- Syntax-highlighted code ([highlight.js](https://highlightjs.org))
- TeX math ([KaTeX](https://katex.org)) — inline `$…$` and display `$$…$$`
- Diagrams ([Mermaid](https://mermaid.js.org))
- Editor ↔ preview scroll sync
- Switchable preview themes + your own custom CSS
- Light/dark mode that follows the system

**Output & editing aids**
- Export to standalone HTML (CSS inlined) or PDF (matches the live preview)
- Table of contents (insert into the document or browse in a sidebar)
- YAML front matter parsing
- Live word / character / reading-time count

**Preferences** (⌘,) — editor font size, editor theme, soft wrap, line numbers, preview theme + custom CSS, word-count visibility.

## Building

Requires Xcode (macOS 14+) and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' build
```

Run the tests with `xcodebuild test -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS'`.

See [`CLAUDE.md`](CLAUDE.md) for architecture notes and [`docs/superpowers/`](docs/superpowers/) for the design specs and implementation plans.

## Status

The four-phase roadmap is complete:

- ✅ **P1 — Core MVP:** split editor + live preview, GFM rendering, syntax highlighting, open/save, dark mode.
- ✅ **P2 — Rich content:** code highlighting, KaTeX math, Mermaid diagrams, scroll sync, preview themes.
- ✅ **P3 — Output & editing:** export HTML/PDF, TOC, front matter, image paste, find & replace.
- ✅ **P4 — Polish:** Preferences, editor themes, word count, formatting toolbar.

## License

MIT © 2026 maxmilian
