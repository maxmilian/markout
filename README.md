<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/hero-dark.svg">
  <img alt="Markout — a modern, native macOS Markdown editor" src="assets/hero-light.svg">
</picture>

# Markout

A modern, native macOS Markdown editor for Apple Silicon — the spiritual successor to the unmaintained [MacDown](https://github.com/MacDownApp/macdown).

Built with SwiftUI + TextKit 2 + WKWebView. MIT licensed.

> See `docs/superpowers/specs/` for design and `docs/superpowers/plans/` for the implementation plans.

## Status

All four roadmap phases are implemented and passing (105 tests / 19 suites). Everything runs offline — the highlight.js / KaTeX / Mermaid engines are vendored, no CDN.

- ✅ **P1 — Core MVP:** split editor + live preview, GFM rendering (cmark-gfm), Markdown syntax highlighting, open/save, dark mode.
- ✅ **P2 — Rich content:** code highlighting, TeX math (KaTeX), Mermaid diagrams, editor↔preview scroll sync, switchable preview themes.
- ✅ **P3 — Output & editing:** export HTML/PDF, table of contents, front matter, image paste/drop, find & replace, list continuation.
- ✅ **P4 — Polish:** Preferences window, editor color themes, live word count, formatting toolbar + Format menu.

## Building

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen generate
xcodebuild -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' build
```

## License

MIT © 2026 maxmilian
