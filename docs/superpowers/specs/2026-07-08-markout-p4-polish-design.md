# Markout — P4 Preferences & Polish Design

**Date:** 2026-07-08
**Status:** Approved (design phase)
**Scope:** Phase 4 (final planned phase) of the effort to build a modern, native macOS Markdown editor (successor to MacDown). Builds on shipped P1 Core MVP, P2 Rich Content, and P3 Output & Editing.

---

## 1. Goal

Make Markout feel finished and personal: a proper **Preferences** window backing user settings, **editor color themes** (so the left pane is themed, not just the preview), a live **word count / document statistics** readout, and a **formatting toolbar** with the common Markdown actions. These are the polish items that turn a capable editor into one people choose to live in.

**Builds on P1–P3 (already shipped):**
- `EditorView` / `MarkdownTextView` (`NSTextView`, TextKit 2) + `SyntaxHighlighter` (token → attributes).
- `ContentView` (`HSplitView`, debounced render), `PreviewTheme` / `PreviewThemeStore` (P2), export/TOC/find/list-continuation (P3).
- `@AppStorage("previewThemeID")` already introduced in P2 for preview theme persistence.

**Out of scope (beyond P4 / future):** plugin system, collaborative editing, iCloud sync, custom keybinding editor, presentation mode. Noted as post-roadmap.

## 2. Technology Choices

| Concern | Choice | Rationale |
|---------|--------|-----------|
| Settings backing store | `@AppStorage` / `UserDefaults` | Native, zero-boilerplate persistence; observable in SwiftUI; the P2 theme setting already uses it |
| Preferences UI | SwiftUI `Settings { }` scene (⌘,) | The standard macOS preferences surface; tabbed via `TabView` |
| Editor themes | `EditorTheme` model (token→`NSColor`, bg, caret) consumed by `SyntaxHighlighter` | The highlighter already maps tokens to attributes; injecting a theme is a clean extension, not a rewrite |
| Word count | Pure `DocumentStats` function over text | Trivially testable; counts words/chars/lines/reading-time |
| Toolbar | SwiftUI `.toolbar` + pure `MarkdownFormatter` text transforms | Formatting logic (wrap selection, toggle prefix) is pure and testable; the toolbar buttons are a thin call into it |

## 3. Architecture

```
Settings (UserDefaults via @AppStorage)
  editorFontSize, editorThemeID, previewThemeID (P2), showLineNumbers,
  showWordCount, softWrap, ...
        │
        ├─ SettingsView (SwiftUI Settings scene, ⌘,)   [NEW]  tabs: Editor / Preview / General
        │
        ├─ EditorTheme + EditorThemeStore              [NEW]
        │     token→NSColor, background, caret, selection
        │           │
        │           └─ SyntaxHighlighter.apply(to:baseFont:theme:)  [EDIT: theme param]
        │                 MarkdownTextView applies bg/caret/selection colors
        │
        ├─ DocumentStats.compute(text)                 [NEW, pure]
        │     → words / characters / lines / readingMinutes
        │           └─ status bar view at editor footer  [NEW]
        │
        └─ MarkdownFormatter                           [NEW, pure]
              toggleBold / toggleItalic / toggleInlineCode /
              setHeading(level) / toggleBlockquote / makeLink / toggleList
                    │
                    └─ FormattingToolbar (.toolbar buttons + ⌘B/⌘I/… shortcuts)  [EDIT]
                          apply transform to NSTextView selection with undo
```

### How settings propagate

- `@AppStorage` keys are read by `ContentView`/`EditorView` and passed down; changing a setting in `SettingsView` updates `UserDefaults`, which SwiftUI observes, re-rendering the editor/preview with the new font, editor theme, toolbar/stat visibility, etc. No notification plumbing needed.

## 4. Component Specifications

### 4.1 Settings (keys)
- Backed by `UserDefaults` through `@AppStorage`. Canonical keys (documented in one place, e.g. an `enum SettingsKey`):
  - `editorFontSize: Double` (default 13)
  - `editorThemeID: String` (default `"markout-light"`)
  - `previewThemeID: String` (default `"github"`, from P2)
  - `showWordCount: Bool` (default `true`)
  - `softWrap: Bool` (default `true`)
  - `showLineNumbers: Bool` (default `false`)
- A small `AppSettings` helper may expose typed accessors, but `@AppStorage` in views is the primary interface.

### 4.2 EditorTheme + EditorThemeStore (new)
- `struct EditorTheme: Identifiable, Hashable { let id: String; let name: String; let background: NSColor; let foreground: NSColor; let caret: NSColor; let selection: NSColor; let colors: [MarkdownToken: NSColor] }`
- `enum EditorThemeStore { static var all: [EditorTheme]; static func theme(id: String) -> EditorTheme? }` — a few built-in themes (e.g. `markout-light`, `markout-dark`, `solarized-light`, `dracula`). Definitions are pure data; store lookups are unit-testable.
- Token color coverage must include every `MarkdownToken` case so the highlighter always has a color.

### 4.3 SyntaxHighlighter (P1, extended)
- Add a theme-aware entry point: `static func apply(to textStorage: NSTextStorage, baseFont: NSFont, theme: EditorTheme)`.
  - Uses `theme.foreground` as the base text color and `theme.colors[token]` per token instead of the P1 hardcoded `NSColor.systemBlue` etc.
  - Keep the P1 `apply(to:baseFont:textColor:)` as a thin shim (delegating with a default theme) so existing callers/tests don't break.
- `tokens(in:)` is unchanged (already covered by P1 tests).

### 4.4 DocumentStats (new, pure)
- `struct DocumentStats: Equatable { let words: Int; let characters: Int; let lines: Int; let readingMinutes: Int }`
- `enum DocumentStats { static func compute(_ text: String) -> DocumentStats }`
  - Words: Unicode-aware split on whitespace, ignoring empties. Characters: full scalar count (or grapheme count — documented choice). Lines: newline count + 1 for non-empty. Reading time: `ceil(words / 200)`.
  - Pure, cheap; can run on every debounce tick. Displayed in a footer status bar when `showWordCount`.

### 4.5 MarkdownFormatter (new, pure)
- Operates on `(text, selection: NSRange)` and returns `(newText, newSelection: NSRange)`:
  - `toggleBold` / `toggleItalic` / `toggleInlineCode` — wrap/unwrap the selection with `**`/`*`/`` ` ``; toggling detects an existing wrap and removes it.
  - `setHeading(level:)` — set/replace the ATX prefix on the selection's line(s).
  - `toggleBlockquote`, `toggleList` — add/remove `> ` / `- ` line prefixes across the selection.
  - `makeLink(url:)` — wrap selection as `[selection](url)`; empty selection inserts `[](url)` with caret placed sensibly.
- All pure and deterministic → the toggle/idempotency behavior is unit-tested. The toolbar/menu simply apply the result to the `NSTextView` with undo registration.

### 4.6 FormattingToolbar (new, thin)
- SwiftUI `.toolbar` with buttons for bold, italic, inline code, heading (menu H1–H3), quote, list, link. Each calls the corresponding `MarkdownFormatter` transform against the text view's current selection and writes the result back (undoable).
- Keyboard shortcuts: `⌘B`, `⌘I`, plus `⌘K` for link — wired via `.keyboardShortcut` / command menu, delegating to the same transforms.

### 4.7 Status bar (new, thin)
- A slim footer under the editor showing `DocumentStats` (e.g. "1,204 words · 6,530 chars · ~7 min") when `showWordCount` is on. Reflects the current document, updates on the existing debounce.

### 4.8 SettingsView (new)
- SwiftUI `Settings { SettingsView() }` scene, tabbed (`TabView`):
  - **Editor:** font size stepper/slider, editor theme picker (`EditorThemeStore.all`), soft wrap toggle, line numbers toggle.
  - **Preview:** preview theme picker (`PreviewThemeStore.bundled`, P2), plus a "choose custom CSS file…" button (`PreviewThemeStore.custom`).
  - **General:** show word count toggle; app info.
- Each control is bound to an `@AppStorage` key; changes take effect live.

## 5. Error Handling
- **Settings:** `@AppStorage` always yields a value (its default); an unknown persisted `editorThemeID`/`previewThemeID` falls back to the default theme via the store's `?? default`. No error surface.
- **Formatter:** transforms are total functions; a selection at a boundary or empty selection is handled explicitly (documented behavior), never throws.
- **Stats:** pure arithmetic; empty text → all zeros.
- **Custom preview CSS:** unreadable file → `PreviewThemeStore.custom` returns `nil`, UI keeps the previous theme and shows a brief inline notice (reuses P2's store).

## 6. Testing Strategy
- **Unit (primary, pure Swift):**
  - `DocumentStats.compute`: words/chars/lines/reading-time on ASCII, Unicode, empty, and whitespace-only inputs.
  - `MarkdownFormatter`: bold/italic/code wrap **and** unwrap (idempotent toggle); heading set/replace; quote/list prefix toggle; link with and without selection; selection-range correctness after each transform.
  - `EditorThemeStore`: `theme(id:)` hit/miss; every built-in theme provides a color for every `MarkdownToken` case.
  - `SyntaxHighlighter.apply(to:baseFont:theme:)`: given a theme, key tokens receive that theme's colors (assert attributes on an `NSTextStorage`).
- **Thin edges (manual):** the Settings window, toolbar buttons, status bar, and live theme switching — acceptance checklist.
- **Approach:** TDD — failing pure tests first (stats, formatter, theme store, themed highlight), then implement to green; wire Settings/toolbar/status-bar UI last.

### Manual acceptance checklist
1. `⌘,` opens Preferences with Editor / Preview / General tabs.
2. Changing editor font size updates the editor live; persists across relaunch.
3. Switching editor theme recolors the editor text, background, caret, and selection; persists.
4. Switching preview theme (from Preferences) restyles the preview (shared with P2's picker).
5. The footer shows an accurate word/char count that updates as you type; hiding it via Preferences removes it.
6. Toolbar bold/italic/code wrap the selection and unwrap on second click; `⌘B`/`⌘I`/`⌘K` do the same; all are undoable.
7. Heading/quote/list toolbar actions modify the current line(s) correctly.
8. An invalid saved theme id after an update falls back to the default without crashing.

## 7. Project Layout (additions)
```
Sources/Markout/
├─ Settings/
│   ├─ SettingsKeys.swift           NEW  @AppStorage key names + defaults
│   ├─ SettingsView.swift           NEW  Settings scene (Editor/Preview/General tabs)
│   ├─ EditorTheme.swift            NEW  EditorTheme + EditorThemeStore
│   └─ DocumentStats.swift          NEW  pure word/char/line/reading-time
├─ Editor/
│   ├─ SyntaxHighlighter.swift      EDIT theme-aware apply(...)
│   ├─ MarkdownFormatter.swift      NEW  pure selection transforms
│   ├─ MarkdownTextView.swift       EDIT apply bg/caret/selection colors, font size, wrap
│   └─ EditorView.swift             EDIT pass theme/font/wrap; expose selection for toolbar
└─ App/
    ├─ MarkoutApp.swift             EDIT add Settings scene + formatting command menu
    └─ ContentView.swift            EDIT status bar footer, toolbar, settings-driven props
Tests/MarkoutTests/
├─ DocumentStatsTests.swift         NEW
├─ MarkdownFormatterTests.swift     NEW
├─ EditorThemeStoreTests.swift      NEW
└─ ThemedHighlighterTests.swift     NEW
```

## 8. Roadmap (context)
- **P1** Core MVP — shipped.
- **P2** Rich content — shipped.
- **P3** Output & editing — shipped.
- **P4** Preferences & polish (this spec) — completes the planned roadmap.
- **Post-roadmap (future, not scheduled):** plugin system, presentation mode, iCloud/sync, custom keybindings.
