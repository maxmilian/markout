English · [繁體中文](README.zh-TW.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/hero-dark.svg">
  <img alt="Markout — a modern, native macOS Markdown editor" src="assets/hero-light.svg">
</picture>

# Markout

[![Latest release](https://img.shields.io/github/v/release/maxmilian/markout?sort=semver)](https://github.com/maxmilian/markout/releases/latest)
[![CI](https://github.com/maxmilian/markout/actions/workflows/ci.yml/badge.svg)](https://github.com/maxmilian/markout/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Platform: macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)

A modern, native macOS Markdown editor for Apple Silicon — the spiritual successor to the unmaintained [MacDown](https://github.com/MacDownApp/macdown).

Built with SwiftUI + TextKit + WKWebView. Everything runs **offline** — the syntax, math, and diagram engines are vendored, no CDN. MIT licensed.

![Markout editing a document with live preview](assets/screenshot.png)

## Download

### Homebrew

```sh
brew install --cask maxmilian/tap/markout
```

Once installed, open any file from the terminal:

```sh
markout path/to/file.md
```

### Or download the `.dmg`

**[⬇ Download the latest release](https://github.com/maxmilian/markout/releases/latest)** — or [build from source](#building).

1. Open the downloaded `Markout-*.dmg` and drag **Markout** into your **Applications** folder.
2. First launch only: right-click **Markout.app** → **Open** → **Open**.

Markout is ad-hoc signed but not notarized by Apple, so macOS shows a Gatekeeper warning the first time. Right-click → **Open** tells macOS to trust it. If double-clicking still refuses to open it, clear the quarantine flag once in Terminal:

```sh
xattr -cr /Applications/Markout.app
```

Requires macOS 14 or later (Apple Silicon recommended).

## Why Markout

Markout is built for people who still want a fast, native Markdown editor on macOS: open a file, write in plain text, see the rendered result immediately, and export without sending the document to a hosted service.

It focuses on:

- Native macOS behavior instead of a web-app shell
- Offline rendering for Markdown, code highlighting, math, and diagrams
- A familiar split editor / preview workflow
- A small, understandable Swift codebase that is easy to improve

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

## Requirements

- macOS 14 or later
- Apple Silicon Mac recommended
- Xcode
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Building

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' build
```

Run the tests:

```sh
xcodebuild test -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS'
```

See [`CLAUDE.md`](CLAUDE.md) for architecture notes and [`docs/superpowers/`](docs/superpowers/) for the design specs and implementation plans.

## Project structure

```text
Sources/Markout/
├── App/          # SwiftUI app shell and document actions
├── Document/     # Markdown document model, front matter, pasted assets
├── Editor/       # TextKit editor, syntax highlighting, formatting helpers
├── Export/       # HTML and PDF export
├── Preview/      # WKWebView preview and scroll sync
├── Render/       # Markdown rendering, HTML template, preview themes
└── Settings/     # Preferences, editor themes, appearance resolution
```

Vendored preview assets live in `Resources/PreviewAssets/`, and tests live in `Tests/MarkoutTests/`.

## Status

The four-phase roadmap is complete:

- ✅ **P1 — Core MVP:** split editor + live preview, GFM rendering, syntax highlighting, open/save, dark mode.
- ✅ **P2 — Rich content:** code highlighting, KaTeX math, Mermaid diagrams, scroll sync, preview themes.
- ✅ **P3 — Output & editing:** export HTML/PDF, TOC, front matter, image paste, find & replace.
- ✅ **P4 — Polish:** Preferences, editor themes, word count, formatting toolbar.

## Localization

This README is available in:

- [English](README.md)
- [繁體中文](README.zh-TW.md)
- [简体中文](README.zh-CN.md)
- [日本語](README.ja.md)
- [한국어](README.ko.md)

Translations should preserve the same technical meaning as the English README. If a feature changes, update the English README first, then update the translations in the same pull request when practical.

## Contributing

Contributions are welcome: bug fixes, editor improvements, rendering fixes, export polish, documentation, tests, and translations.

Before opening a pull request:

1. Keep changes focused and consistent with the existing SwiftUI / TextKit / WKWebView architecture.
2. Run `xcodegen generate` if `project.yml` changed.
3. Run `xcodebuild test -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS'`.
4. Update README or localized README files if the user-facing behavior changed.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full contribution guide.

## Acknowledgements

Markout owes a debt to [MacDown](https://github.com/MacDownApp/macdown), the Markdown editor I relied on for years. MacDown is no longer maintained, so Markout is a fresh, fully native rebuild for modern Apple Silicon macOS — carrying that same fast, plain-text, offline spirit forward. Thank you to the MacDown authors.

## License

Released under the [MIT License](LICENSE). © 2026 maxmilian
