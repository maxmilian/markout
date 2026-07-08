[English](README.md) · [繁體中文](README.zh-TW.md) · 简体中文 · [日本語](README.ja.md) · [한국어](README.ko.md)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/hero-dark.svg">
  <img alt="Markout — 现代、原生的 macOS Markdown 编辑器" src="assets/hero-light.svg">
</picture>

# Markout

Markout 是一款现代、原生的 Apple Silicon macOS Markdown 编辑器，也是已停止维护的 [MacDown](https://github.com/MacDownApp/macdown) 的精神续作。

它使用 SwiftUI + TextKit + WKWebView 构建。所有渲染都在本机离线完成，语法、数学公式和图表引擎都随 app vendored，不依赖 CDN。项目采用 MIT 许可证。

![Markout editing a document with live preview](assets/screenshot.png)

## 为什么做 Markout

Markout 面向仍然想要快速、原生 Markdown 编辑器的 macOS 用户：打开文件、用纯文本书写、即时查看预览，并且不把文档发送到托管服务。

重点目标：

- 原生 macOS 行为，而不是网页 app 外壳
- Markdown、代码高亮、数学公式和图表全部离线渲染
- 熟悉的编辑器 / 预览分栏工作流
- 小而清晰、易于改进的 Swift 代码库

## 功能

**编辑**
- 分栏编辑器 + 即时预览，渲染 debounce 150 ms
- Markdown 语法高亮，并可切换编辑器颜色主题
- 自动延续列表、图片粘贴 / 拖放，图片会保存在文档旁边
- 查找与替换、可选行号 gutter、soft wrap 开关
- 格式工具栏与 **Format** 菜单：粗体 ⌘B、斜体 ⌘I、链接 ⌘K、标题、引用、列表，全部支持 undo

**预览**
- 通过 [cmark-gfm](https://github.com/apple/swift-cmark) 支持 GitHub-Flavored Markdown
- 通过 [highlight.js](https://highlightjs.org) 支持代码高亮
- 通过 [KaTeX](https://katex.org) 支持 TeX 数学公式：inline `$…$` 和 display `$$…$$`
- 通过 [Mermaid](https://mermaid.js.org) 支持图表
- 编辑器与预览滚动同步
- 可切换预览主题，也可使用自定义 CSS
- 跟随系统的浅色 / 深色模式

**输出与辅助**
- 导出独立 HTML，或导出与即时预览一致的 PDF
- 目录：可插入文档，或在侧边栏浏览
- YAML front matter 解析
- 即时字数、字符数和阅读时间

**偏好设置** (⌘,)：编辑器字号、编辑器主题、soft wrap、行号、预览主题、自定义 CSS、字数显示。

## 系统要求

- macOS 14 或更新版本
- 建议使用 Apple Silicon Mac
- Xcode
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## 构建

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS' build
```

运行测试：

```sh
xcodebuild test -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS'
```

架构说明见 [`CLAUDE.md`](CLAUDE.md)，设计规格与实现计划见 [`docs/superpowers/`](docs/superpowers/)。

## 项目结构

```text
Sources/Markout/
├── App/          # SwiftUI app shell 与文档操作
├── Document/     # Markdown 文档模型、front matter、粘贴资源
├── Editor/       # TextKit 编辑器、语法高亮、格式化工具
├── Export/       # HTML 与 PDF 导出
├── Preview/      # WKWebView 预览与滚动同步
├── Render/       # Markdown 渲染、HTML template、预览主题
└── Settings/     # 偏好设置、编辑器主题、外观解析
```

Vendored 预览资源位于 `Resources/PreviewAssets/`，测试位于 `Tests/MarkoutTests/`。

## 状态

四阶段 roadmap 已完成：

- ✅ **P1 — Core MVP：** 分栏编辑器 + 即时预览、GFM 渲染、语法高亮、打开 / 保存、深色模式。
- ✅ **P2 — Rich content：** 代码高亮、KaTeX 数学公式、Mermaid 图表、滚动同步、预览主题。
- ✅ **P3 — Output & editing：** HTML/PDF 导出、TOC、front matter、图片粘贴、查找与替换。
- ✅ **P4 — Polish：** 偏好设置、编辑器主题、字数统计、格式工具栏。

## 多语言

README 提供以下语言：

- [English](README.md)
- [繁體中文](README.zh-TW.md)
- [简体中文](README.zh-CN.md)
- [日本語](README.ja.md)
- [한국어](README.ko.md)

翻译应保留与英文 README 相同的技术含义。功能变更时，请先更新英文 README；如可行，请在同一个 pull request 中同步更新翻译。

## 贡献

欢迎贡献：bug fix、编辑器改进、渲染修正、导出 polish、文档、测试和翻译。

提交 pull request 前：

1. 让变更保持聚焦，并符合既有 SwiftUI / TextKit / WKWebView 架构。
2. 如果修改 `project.yml`，请运行 `xcodegen generate`。
3. 运行 `xcodebuild test -project Markout.xcodeproj -scheme Markout -destination 'platform=macOS'`。
4. 如果用户可见行为有变化，请更新 README 或多语言 README。

完整指南见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

本项目基于 [MIT License](LICENSE) 发布。© 2026 maxmilian
