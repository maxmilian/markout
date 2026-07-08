[English](README.md) · 繁體中文 · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/hero-dark.svg">
  <img alt="Markout — 現代、原生的 macOS Markdown 編輯器" src="assets/hero-light.svg">
</picture>

# Markout

[![Latest release](https://img.shields.io/github/v/release/maxmilian/markout?sort=semver)](https://github.com/maxmilian/markout/releases/latest)
[![CI](https://github.com/maxmilian/markout/actions/workflows/ci.yml/badge.svg)](https://github.com/maxmilian/markout/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Platform: macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)

Markout 是一款現代、原生的 Apple Silicon macOS Markdown 編輯器，也是已停止維護的 [MacDown](https://github.com/MacDownApp/macdown) 的精神續作。

它使用 SwiftUI + TextKit + WKWebView 建構。所有渲染都在本機離線完成，語法、數學公式與圖表引擎都隨 app vendored，不依賴 CDN。專案採 MIT 授權。

![Markout editing a document with live preview](assets/screenshot.png)

## 下載

### Homebrew

```sh
brew install --cask maxmilian/tap/markout
```

### 或下載 `.dmg`

**[⬇ 下載最新版本](https://github.com/maxmilian/markout/releases/latest)** — 或[從原始碼建置](#建置)。

1. 開啟下載的 `Markout-*.dmg`，將 **Markout** 拖進**應用程式**資料夾。
2. 首次開啟：在 **Markout.app** 上按右鍵 →「**打開**」→「**打開**」。

Markout 採 ad-hoc 簽章但未經 Apple 公證，因此首次開啟時 macOS 會顯示 Gatekeeper 警告。右鍵「打開」即可讓 macOS 信任它。若雙擊仍無法開啟，在終端機執行一次以清除隔離屬性：

```sh
xattr -cr /Applications/Markout.app
```

需要 macOS 14 以上（建議 Apple Silicon）。

## 為什麼做 Markout

Markout 適合仍然想要快速、原生 Markdown 編輯器的 macOS 使用者：打開檔案、用純文字書寫、即時查看預覽，並在不把文件送到雲端服務的情況下匯出。

重點目標：

- 原生 macOS 行為，而不是包一層網頁 app
- Markdown、程式碼高亮、數學公式與圖表全部離線渲染
- 熟悉的編輯器 / 預覽分割視窗工作流
- 小而清楚、容易改進的 Swift 程式碼庫

## 功能

**編輯**
- 分割編輯器 + 即時預覽，渲染 debounce 150 ms
- Markdown 語法高亮，並可切換編輯器色彩主題
- 自動延續清單、圖片貼上 / 拖放，圖片會儲存在文件旁
- 尋找與取代、可選行號 gutter、soft wrap 開關
- 格式工具列與 **Format** 選單：粗體 ⌘B、斜體 ⌘I、連結 ⌘K、標題、引用、清單，全部支援 undo

**預覽**
- 透過 [cmark-gfm](https://github.com/apple/swift-cmark) 支援 GitHub-Flavored Markdown
- 透過 [highlight.js](https://highlightjs.org) 支援程式碼高亮
- 透過 [KaTeX](https://katex.org) 支援 TeX 數學公式：inline `$…$` 與 display `$$…$$`
- 透過 [Mermaid](https://mermaid.js.org) 支援圖表
- 編輯器與預覽滾動同步
- 可切換預覽主題，也可使用自訂 CSS
- 跟隨系統的淺色 / 深色模式

**輸出與輔助**
- 匯出獨立 HTML，或匯出與即時預覽一致的 PDF
- 目錄：可插入文件，或在側邊欄瀏覽
- YAML front matter 解析
- 即時字數、字元數與閱讀時間

**偏好設定** (⌘,)：編輯器字級、編輯器主題、soft wrap、行號、預覽主題、自訂 CSS、字數顯示。

## 系統需求

- macOS 14 或更新版本
- 建議使用 Apple Silicon Mac
- Xcode
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## 建置

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' build
```

執行測試：

```sh
xcodebuild test -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS'
```

架構說明見 [`CLAUDE.md`](CLAUDE.md)，設計規格與實作計畫見 [`docs/superpowers/`](docs/superpowers/)。

## 專案結構

```text
Sources/Markout/
├── App/          # SwiftUI app shell 與文件操作
├── Document/     # Markdown 文件模型、front matter、貼上資產
├── Editor/       # TextKit 編輯器、語法高亮、格式化工具
├── Export/       # HTML 與 PDF 匯出
├── Preview/      # WKWebView 預覽與滾動同步
├── Render/       # Markdown 渲染、HTML template、預覽主題
└── Settings/     # 偏好設定、編輯器主題、外觀解析
```

Vendored 預覽資產位於 `Resources/PreviewAssets/`，測試位於 `Tests/MarkoutTests/`。

## 狀態

四階段 roadmap 已完成：

- ✅ **P1 — Core MVP：** 分割編輯器 + 即時預覽、GFM 渲染、語法高亮、開啟 / 儲存、深色模式。
- ✅ **P2 — Rich content：** 程式碼高亮、KaTeX 數學公式、Mermaid 圖表、滾動同步、預覽主題。
- ✅ **P3 — Output & editing：** HTML/PDF 匯出、TOC、front matter、圖片貼上、尋找與取代。
- ✅ **P4 — Polish：** 偏好設定、編輯器主題、字數統計、格式工具列。

## 多語系

README 提供以下語言：

- [English](README.md)
- [繁體中文](README.zh-TW.md)
- [简体中文](README.zh-CN.md)
- [日本語](README.ja.md)
- [한국어](README.ko.md)

翻譯應保留與英文 README 相同的技術含義。功能變更時，請先更新英文 README；若可行，請在同一個 pull request 中同步更新翻譯。

## 貢獻

歡迎貢獻：bug fix、編輯器改善、渲染修正、匯出 polish、文件、測試與翻譯。

送出 pull request 前：

1. 讓變更保持聚焦，並符合既有 SwiftUI / TextKit / WKWebView 架構。
2. 若修改 `project.yml`，請執行 `xcodegen generate`。
3. 執行 `xcodebuild test -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS'`。
4. 若使用者可見行為有變更，請更新 README 或多語 README。

完整指南見 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 謝辭

Markout 深受 [MacDown](https://github.com/MacDownApp/macdown) 的啟發——那是我多年來慣用的 Markdown 編輯器。MacDown 已停止維護，因此 Markout 以完全原生的方式、為現代 Apple Silicon macOS 重新打造，延續同樣快速、純文字、離線的精神。感謝 MacDown 的作者們。

## 授權

本專案以 [MIT License](LICENSE) 發布。© 2026 maxmilian
