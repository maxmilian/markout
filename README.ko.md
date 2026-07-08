[English](README.md) · [繁體中文](README.zh-TW.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · 한국어

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/hero-dark.svg">
  <img alt="Markout — modern native macOS Markdown editor" src="assets/hero-light.svg">
</picture>

# Markout

Markout은 Apple Silicon을 위한 현대적인 네이티브 macOS Markdown 에디터입니다. 더 이상 유지보수되지 않는 [MacDown](https://github.com/MacDownApp/macdown)의 정신적 후속작을 목표로 합니다.

SwiftUI + TextKit + WKWebView로 만들어졌습니다. 문법, 수식, 다이어그램 엔진은 vendored 되어 있으며 모든 렌더링은 **오프라인** 으로 동작합니다. CDN에 의존하지 않습니다. MIT 라이선스입니다.

![Markout editing a document with live preview](assets/screenshot.png)

## Why Markout

Markout은 macOS에서 빠른 네이티브 Markdown 에디터를 원하는 사용자를 위한 앱입니다. 파일을 열고, plain text로 작성하고, 즉시 미리보기를 확인하고, 문서를 외부 서비스로 보내지 않고 내보낼 수 있습니다.

중점:

- 웹 앱 wrapper가 아닌 네이티브 macOS 동작
- Markdown, 코드 하이라이트, 수식, 다이어그램의 오프라인 렌더링
- 익숙한 editor / preview split workflow
- 작고 이해하기 쉬우며 개선하기 쉬운 Swift 코드베이스

## Features

**Editing**
- 150 ms debounce가 적용된 split editor + live preview
- 전환 가능한 editor color theme가 있는 Markdown syntax highlighting
- 자동 list continuation, image paste/drop 지원. 이미지는 문서 옆에 저장됩니다
- find & replace, 선택 가능한 line-number gutter, soft wrap toggle
- formatting toolbar와 **Format** menu: bold ⌘B, italic ⌘I, link ⌘K, headings, quote, list. 모두 undo 가능

**Preview**
- [cmark-gfm](https://github.com/apple/swift-cmark)을 통한 GitHub-Flavored Markdown
- [highlight.js](https://highlightjs.org)를 통한 syntax-highlighted code
- [KaTeX](https://katex.org)를 통한 TeX math: inline `$…$`, display `$$…$$`
- [Mermaid](https://mermaid.js.org)를 통한 diagrams
- editor와 preview의 scroll sync
- 전환 가능한 preview theme와 custom CSS
- 시스템 설정을 따르는 light/dark mode

**Output and editing aids**
- standalone HTML 또는 live preview와 일치하는 PDF로 export
- table of contents: 문서에 삽입하거나 sidebar에서 탐색
- YAML front matter parsing
- live word / character / reading-time count

**Preferences** (⌘,): editor font size, editor theme, soft wrap, line numbers, preview theme + custom CSS, word-count visibility.

## Requirements

- macOS 14 이상
- Apple Silicon Mac 권장
- Xcode
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Building

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' build
```

테스트 실행:

```sh
xcodebuild test -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS'
```

아키텍처 메모는 [`CLAUDE.md`](CLAUDE.md), 디자인 스펙과 구현 계획은 [`docs/superpowers/`](docs/superpowers/)를 참고하세요.

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

Vendored preview assets는 `Resources/PreviewAssets/`에 있고, tests는 `Tests/MarkoutTests/`에 있습니다.

## Status

4단계 roadmap은 완료되었습니다:

- ✅ **P1 — Core MVP:** split editor + live preview, GFM rendering, syntax highlighting, open/save, dark mode.
- ✅ **P2 — Rich content:** code highlighting, KaTeX math, Mermaid diagrams, scroll sync, preview themes.
- ✅ **P3 — Output & editing:** export HTML/PDF, TOC, front matter, image paste, find & replace.
- ✅ **P4 — Polish:** Preferences, editor themes, word count, formatting toolbar.

## Localization

README는 다음 언어로 제공됩니다:

- [English](README.md)
- [繁體中文](README.zh-TW.md)
- [简体中文](README.zh-CN.md)
- [日本語](README.ja.md)
- [한국어](README.ko.md)

번역은 영어 README와 같은 기술적 의미를 유지해야 합니다. 기능이 변경되면 영어 README를 먼저 업데이트하고, 가능하면 같은 pull request에서 번역도 함께 업데이트하세요.

## Contributing

버그 수정, editor 개선, rendering 수정, export polish, documentation, tests, translations 모두 환영합니다.

pull request를 열기 전에:

1. 변경 범위를 작게 유지하고 기존 SwiftUI / TextKit / WKWebView architecture와 일관되게 작성하세요.
2. `project.yml`을 변경했다면 `xcodegen generate`를 실행하세요.
3. `xcodebuild test -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS'`를 실행하세요.
4. 사용자에게 보이는 동작이 바뀌면 README 또는 localized README를 업데이트하세요.

전체 가이드는 [CONTRIBUTING.md](CONTRIBUTING.md)를 참고하세요.

## License

[MIT License](LICENSE)로 배포됩니다. © 2026 maxmilian
